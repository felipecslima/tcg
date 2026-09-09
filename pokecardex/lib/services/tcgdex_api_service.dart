import 'dart:convert';
import 'package:http/http.dart' as http;

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
/// Todo o resto (telas, matcher) fala só com `TcgCard`/`TcgSetBrief`, então
/// se um dia precisarmos trocar de fonte de dados de novo, é só reescrever
/// esta classe.
///
/// Suporta idioma via `language` (ex: "en", "pt") — isso é o que permite
/// escanear tanto cartas em inglês quanto em português, cada uma buscando
/// nomes na língua certa.
class TcgdexApiService {
  TcgdexApiService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://api.tcgdex.net/v2';

  final http.Client _client;

  /// Lista todos os sets disponíveis (pra tela de seleção antes do scan).
  Future<List<TcgSetBrief>> fetchAllSets({String language = 'en'}) async {
    final uri = Uri.parse('$_baseUrl/$language/sets');
    final response = await _client.get(uri);
    _checkOk(response);
    final data = jsonDecode(response.body) as List;
    return data.map((e) => TcgSetBrief.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Busca um set com todas as suas cartas (versão resumida) — é isso que
  /// carrega a base de matching antes de começar a escanear.
  Future<List<TcgCard>> fetchCardsForSet(String setId, {String language = 'en'}) async {
    final uri = Uri.parse('$_baseUrl/$language/sets/$setId');
    final response = await _client.get(uri);
    _checkOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final setName = body['name'] as String? ?? setId;
    final cards = body['cards'] as List? ?? const [];
    return cards
        .map((e) => TcgCard.fromTcgdexSetCardJson(
              e as Map<String, dynamic>,
              setId: setId,
              setName: setName,
            ))
        .toList();
  }

  void dispose() => _client.close();

  void _checkOk(http.Response response) {
    if (response.statusCode != 200) {
      throw TcgdexApiException(response.statusCode, response.body);
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
