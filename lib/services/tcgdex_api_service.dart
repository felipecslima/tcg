import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/card_detail.dart';
import '../models/tcg_card.dart';

/// Um set, na versão resumida usada pra tela de seleção antes do scan.
class TcgSetBrief {
  final String id;
  final String name;
  final String? logoUrl;
  final int cardCount;

  const TcgSetBrief({
    required this.id,
    required this.name,
    required this.cardCount,
    this.logoUrl,
  });

  factory TcgSetBrief.fromJson(Map<String, dynamic> json) {
    final cardCount = json['cardCount'] as Map<String, dynamic>?;
    return TcgSetBrief(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo'] as String?,
      cardCount: (cardCount?['official'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Cliente da TCGdex — única classe do app que sabe o formato da API.
///
/// **Cache** (pra não bater na API à toa):
///   - sets e cartas de um set: em memória, vida da sessão (raramente mudam).
///   - detalhe de carta: em memória + em disco com TTL de 12h (os preços
///     atualizam ~1×/dia). Rede fora do ar → devolve o disco mesmo velho.
class TcgdexApiService {
  TcgdexApiService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://api.tcgdex.net/v2';
  static const _cardTtl = Duration(hours: 12);

  final http.Client _client;

  // caches de sessão (estáticos → sobrevivem à troca de tela)
  static final Map<String, List<TcgSetBrief>> _setsMem = {};
  static final Map<String, List<TcgCard>> _setCardsMem = {};
  static final Map<String, CardDetail> _cardMem = {};
  static final Map<String, Future<CardDetail>> _cardInflight = {};

  /// Lista todos os sets disponíveis (pra tela de seleção antes do scan).
  Future<List<TcgSetBrief>> fetchAllSets({String language = 'en'}) async {
    final cached = _setsMem[language];
    if (cached != null) return cached;
    final uri = Uri.parse('$_baseUrl/$language/sets');
    final response = await _client.get(uri);
    _checkOk(response);
    final data = jsonDecode(response.body) as List;
    final sets =
        data.map((e) => TcgSetBrief.fromJson(e as Map<String, dynamic>)).toList();
    _setsMem[language] = sets;
    return sets;
  }

  /// Busca um set com todas as suas cartas (versão resumida) — carrega a base
  /// de matching antes de começar a escanear.
  Future<List<TcgCard>> fetchCardsForSet(String setId,
      {String language = 'en'}) async {
    final key = '$language/$setId';
    final cached = _setCardsMem[key];
    if (cached != null) return cached;

    final uri = Uri.parse('$_baseUrl/$language/sets/$setId');
    final response = await _client.get(uri);
    _checkOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final setName = body['name'] as String? ?? setId;
    final cardCount = body['cardCount'] as Map<String, dynamic>?;
    final printedTotal = (cardCount?['official'] as num?)?.toInt() ??
        (cardCount?['total'] as num?)?.toInt() ??
        0;
    final cards = (body['cards'] as List? ?? const [])
        .map((e) => TcgCard.fromTcgdexSetCardJson(
              e as Map<String, dynamic>,
              setId: setId,
              setName: setName,
              printedTotal: printedTotal,
            ))
        .toList();
    _setCardsMem[key] = cards;
    return cards;
  }

  /// Busca a carta individual — raridade, ataques, variantes e **valores de
  /// mercado**. Só o endpoint de carta traz isso (o de set é "brief").
  ///
  /// Ordem: memória → disco (se < 12h) → rede → disco velho (se a rede falhar).
  Future<CardDetail> fetchCard(String cardId, {String language = 'en'}) {
    final key = '$language/$cardId';
    final mem = _cardMem[key];
    if (mem != null) return Future.value(mem);
    final inflight = _cardInflight[key];
    if (inflight != null) return inflight; // dedup de requisições simultâneas
    final f = _loadCard(key, cardId, language);
    _cardInflight[key] = f;
    f.whenComplete(() => _cardInflight.remove(key));
    return f;
  }

  Future<CardDetail> _loadCard(String key, String cardId, String lang) async {
    final disk = await _readCardDisk(key);
    if (disk != null && disk.age < _cardTtl) {
      return _cardMem[key] = CardDetail.fromJson(disk.json);
    }
    try {
      final response =
          await _client.get(Uri.parse('$_baseUrl/$lang/cards/$cardId'));
      _checkOk(response);
      await _writeCardDisk(key, response.body);
      return _cardMem[key] = CardDetail.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      if (disk != null) {
        // rede fora do ar: melhor o disco velho que nada
        return _cardMem[key] = CardDetail.fromJson(disk.json);
      }
      rethrow;
    }
  }

  void dispose() => _client.close();

  /// Limpa os caches em memória (só pra testes).
  static void clearMemoryCache() {
    _setsMem.clear();
    _setCardsMem.clear();
    _cardMem.clear();
    _cardInflight.clear();
  }

  void _checkOk(http.Response response) {
    if (response.statusCode != 200) {
      throw TcgdexApiException(response.statusCode, response.body);
    }
  }

  // ---- cache em disco do detalhe de carta ----

  static Directory? _dir;

  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    Directory base;
    try {
      base = await getApplicationCacheDirectory();
    } catch (_) {
      base = await getTemporaryDirectory();
    }
    final d = Directory('${base.path}/tcgdex_cards');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  File _cardFile(Directory dir, String key) =>
      File('${dir.path}/${key.replaceAll('/', '_')}.json');

  Future<({Map<String, dynamic> json, Duration age})?> _readCardDisk(
      String key) async {
    try {
      final f = _cardFile(await _cacheDir(), key);
      if (!await f.exists()) return null;
      final wrap = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final at = DateTime.fromMillisecondsSinceEpoch(wrap['at'] as int);
      final json = jsonDecode(wrap['raw'] as String) as Map<String, dynamic>;
      return (json: json, age: DateTime.now().difference(at));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCardDisk(String key, String raw) async {
    try {
      final f = _cardFile(await _cacheDir(), key);
      await f.writeAsString(jsonEncode(
          {'at': DateTime.now().millisecondsSinceEpoch, 'raw': raw}));
    } catch (_) {
      // cache é best-effort; falha ao escrever não quebra nada
    }
  }
}

class TcgdexApiException implements Exception {
  final int statusCode;
  final String body;
  TcgdexApiException(this.statusCode, this.body);

  @override
  String toString() => 'TcgdexApiException($statusCode): $body';
}
