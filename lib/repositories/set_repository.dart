import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/tcgdex_api_service.dart';
import 'api_cache_logger.dart';
import 'staleness.dart';

/// Um set (a "coleção" da UI), lido da tabela `sets`.
class CardSetBrief {
  const CardSetBrief({
    required this.id,
    required this.name,
    this.series,
    this.abbreviation,
    this.printedTotal = 0,
    this.total = 0,
    this.releaseDate,
    this.symbolUrl,
    this.logoUrl,
    this.updatedAt,
    this.translations = const {},
  });

  final String id;
  final String name;
  final String? series;
  final String? abbreviation;
  final int printedTotal;
  final int total;
  final DateTime? releaseDate;
  final String? symbolUrl;
  final String? logoUrl;
  final DateTime? updatedAt;

  /// Nome do set por idioma (`{"en": "...", "pt": "..."}`). O app é sempre
  /// PT-BR, mas o OCR do scanner pode ler o nome impresso na carta em
  /// qualquer idioma suportado — por isso o matching precisa do nome
  /// original, não só do nome exibido.
  final Map<String, String> translations;

  /// Nome no idioma pedido, com fallback pt → en → [name].
  String nameIn(String lang) => translations[lang] ?? translations['pt'] ?? translations['en'] ?? name;

  factory CardSetBrief.fromSupabaseRow(Map<String, dynamic> row) => CardSetBrief(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        series: row['series'] as String?,
        abbreviation: row['abbreviation'] as String?,
        printedTotal: row['printed_total'] as int? ?? 0,
        total: row['total'] as int? ?? 0,
        releaseDate: DateTime.tryParse(row['release_date'] as String? ?? ''),
        symbolUrl: row['symbol_url'] as String?,
        logoUrl: row['logo_url'] as String?,
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
        translations: (row['translations'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            const {},
      );

  factory CardSetBrief.fromTcgdexBrief(TcgSetBrief b) => CardSetBrief(
        id: b.id,
        name: b.name,
        printedTotal: b.cardCount,
        logoUrl: b.logoUrl,
      );

  Map<String, dynamic> toUpsertRow() {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': id,
      'name': name,
      if (series != null) 'series': series,
      if (printedTotal > 0) 'printed_total': printedTotal,
      if (total > 0) 'total': total,
      if (releaseDate != null) 'release_date': releaseDate!.toIso8601String().split('T').first,
      if (symbolUrl != null) 'symbol_url': symbolUrl,
      if (logoUrl != null) 'logo_url': logoUrl,
      'fetched_at': now,
      'updated_at': now,
    };
  }
}

/// Abstração fina sobre a tabela `sets` — permite injetar um fake em teste
/// sem precisar de um `SupabaseClient` real.
abstract class SetStore {
  Future<List<Map<String, dynamic>>> fetchAll();
  Future<Map<String, dynamic>?> fetchById(String id);
  Future<void> upsertAll(List<Map<String, dynamic>> rows);
}

class SupabaseSetStore implements SetStore {
  SupabaseSetStore(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from('sets').select();
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> fetchById(String id) async {
    return await _client.from('sets').select().eq('id', id).maybeSingle();
  }

  @override
  Future<void> upsertAll(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('sets').upsert(rows);
  }
}

/// Lista/busca sets — DB-first, TTL 30 dias, cai pra TCGdex no vazio/vencido
/// e grava de volta na base antes de devolver.
class CardSetRepository {
  CardSetRepository({SetStore? store, TcgdexApiService? api, ApiCacheLogger? cacheLogger})
      : _store = store ?? SupabaseSetStore(Supabase.instance.client),
        _api = api ?? TcgdexApiService(),
        _cacheLogger = cacheLogger ?? SupabaseApiCacheLogger(Supabase.instance.client);

  static const _ttl = Duration(days: 30);

  final SetStore _store;
  final TcgdexApiService _api;
  final ApiCacheLogger _cacheLogger;

  Future<List<CardSetBrief>> fetchAllSets({String language = 'pt'}) async {
    var rows = await _store.fetchAll();
    final stale = rows.isEmpty || isStale(freshestUpdatedAt(rows), _ttl);
    if (stale) {
      try {
        final fresh = await _api.fetchAllSets(language: language);
        final freshRows =
            fresh.map((b) => CardSetBrief.fromTcgdexBrief(b).toUpsertRow()).toList();
        await _store.upsertAll(freshRows);
        await _cacheLogger.touchFetchLog(
            source: 'tcgdex', entityType: 'sets', entityId: 'all', ttl: _ttl);
        rows = await _store.fetchAll();
      } catch (_) {
        // API fora do ar: serve o que já tem na base, mesmo vencido.
        if (rows.isEmpty) rethrow;
      }
    }
    return rows.map(CardSetBrief.fromSupabaseRow).toList();
  }

  /// Sets que batem com a abreviação impressa na carta (ex: `MEG`, `SSP`).
  /// Retorna da cache local (fetchAllSets preenche), sem hit extra no banco.
  Future<List<CardSetBrief>> fetchSetsByAbbreviation(String abbreviation) async {
    final all = await fetchAllSets();
    final upper = abbreviation.toUpperCase();
    return all.where((s) => s.abbreviation?.toUpperCase() == upper).toList();
  }

  /// Sets com o mesmo printedTotal (fallback quando a abreviação não bate).
  Future<List<CardSetBrief>> fetchSetsByPrintedTotal(int printedTotal) async {
    final all = await fetchAllSets();
    return all.where((s) => s.printedTotal == printedTotal).toList();
  }

  Future<CardSetBrief?> fetchSetById(String id, {String language = 'pt'}) async {
    var row = await _store.fetchById(id);
    if (row == null || isStale(DateTime.tryParse(row['updated_at'] as String? ?? ''), _ttl)) {
      try {
        final sets = await _api.fetchAllSets(language: language);
        final match = sets.where((s) => s.id == id).cast<TcgSetBrief?>().firstOrNull;
        if (match != null) {
          await _store.upsertAll([CardSetBrief.fromTcgdexBrief(match).toUpsertRow()]);
          row = await _store.fetchById(id);
        }
      } catch (_) {
        // sem rede: usa o que tem (pode ser null se nunca foi visto)
      }
    }
    return row == null ? null : CardSetBrief.fromSupabaseRow(row);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
