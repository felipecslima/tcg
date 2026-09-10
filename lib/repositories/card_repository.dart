import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card.dart';
import '../services/tcgdex_api_service.dart';
import 'api_cache_logger.dart';
import 'staleness.dart';

/// Abstração fina sobre a tabela `cards` — permite fake em teste.
abstract class CardStore {
  Future<List<Map<String, dynamic>>> fetchAll();
  Future<List<Map<String, dynamic>>> fetchBySet(String setId);
  Future<Map<String, dynamic>?> fetchById(String id);
  Future<void> upsertAll(List<Map<String, dynamic>> rows);
  Future<List<Map<String, dynamic>>> searchByName(String query, {int limit = 20});
  Future<List<Map<String, dynamic>>> fetchByDexRange(int start, int end);
}

class SupabaseCardStore implements CardStore {
  SupabaseCardStore(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    const pageSize = 1000;
    final all = <Map<String, dynamic>>[];
    while (true) {
      final rows = await _client
          .from('cards')
          .select('id,set_id,local_id,name,image_url,national_dex_id,updated_at')
          .range(all.length, all.length + pageSize - 1);
      final list = (rows as List).cast<Map<String, dynamic>>();
      all.addAll(list);
      if (list.length < pageSize) break;
    }
    return all;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBySet(String setId) async {
    final rows = await _client.from('cards').select().eq('set_id', setId);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> fetchById(String id) async {
    return await _client.from('cards').select().eq('id', id).maybeSingle();
  }

  @override
  Future<void> upsertAll(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('cards').upsert(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> searchByName(String query, {int limit = 20}) async {
    final rows = await _client
        .from('cards')
        .select('*, sets(name)')
        .ilike('name', '%$query%')
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchByDexRange(int start, int end) async {
    final rows = await _client
        .from('cards')
        .select('*, sets(name)')
        .gte('national_dex_id', start)
        .lte('national_dex_id', end)
        .order('national_dex_id');
    return (rows as List).cast<Map<String, dynamic>>();
  }
}

/// Cartas de um set / carta individual — DB-first, TTL 30 dias (catálogo).
/// Cartas "brief" sem `attacks`/`hp` são completadas sob demanda quando o
/// chamador pede detalhe (`fetchCardDetail`), sem esperar o TTL do set.
class CardRepository {
  CardRepository({CardStore? store, TcgdexApiService? api, ApiCacheLogger? cacheLogger})
      : _store = store ?? SupabaseCardStore(Supabase.instance.client),
        _api = api ?? TcgdexApiService(),
        _cacheLogger = cacheLogger ?? SupabaseApiCacheLogger(Supabase.instance.client);

  static const _ttl = Duration(days: 30);

  final CardStore _store;
  final TcgdexApiService _api;
  final ApiCacheLogger _cacheLogger;

  /// Todas as cartas brief do banco (sem refresh de API).
  /// Usado pelo modo universo aberto do scanner (~23k linhas, só campos leves).
  Future<List<Card>> fetchAllCardsBrief() async {
    final rows = await _store.fetchAll();
    return rows.map(Card.fromSupabaseRow).toList();
  }

  /// Cartas "brief" do set (nome, número, imagem) — base do matching do
  /// scanner e da tela de Candidatos.
  Future<List<Card>> fetchCardsForSet(String setId, {String language = 'en'}) async {
    var rows = await _store.fetchBySet(setId);
    final stale = rows.isEmpty || isStale(freshestUpdatedAt(rows), _ttl);
    if (stale) {
      try {
        final fresh = await _api.fetchCardsForSet(setId, language: language);
        final freshRows =
            fresh.map((c) => Card.fromBrief(c).toUpsertRow(setId: setId)).toList();
        await _store.upsertAll(freshRows);
        await _cacheLogger.touchFetchLog(
            source: 'tcgdex', entityType: 'set_cards', entityId: setId, ttl: _ttl);
        rows = await _store.fetchBySet(setId);
      } catch (_) {
        if (rows.isEmpty) rethrow;
      }
    }
    return rows.map(Card.fromSupabaseRow).toList();
  }

  /// Carta com detalhe completo (raridade, ataques, HP). Se a linha na base
  /// já tem isso e está fresca, não bate na API.
  Future<Card> fetchCardDetail(String id, {String language = 'en'}) async {
    var row = await _store.fetchById(id);
    final hasDetail = row != null && row['rarity'] != null;
    final stale = row == null ||
        !hasDetail ||
        isStale(DateTime.tryParse(row['updated_at'] as String? ?? ''), _ttl);
    if (stale) {
      try {
        final detail = await _api.fetchCard(id, language: language);
        final setId = row?['set_id'] as String?;
        final card = Card.fromDetail(detail, setId: setId ?? '');
        await _store.upsertAll([card.toUpsertRow(setId: setId)]);
        await _cacheLogger.touchFetchLog(
            source: 'tcgdex', entityType: 'card', entityId: id, ttl: _ttl);
        row = await _store.fetchById(id);
      } catch (_) {
        if (row == null) rethrow; // sem base e sem API: não tem o que servir
      }
    }
    return Card.fromSupabaseRow(row!);
  }

  /// Busca textual por nome (ilike) — usada pela tela de Busca.
  Future<List<Card>> searchCards(String query, {int limit = 20}) async {
    final rows = await _store.searchByName(query, limit: limit);
    return rows.map(Card.fromSupabaseRow).toList();
  }

  /// Cartas cujo national_dex_id está no range da região — usada por Jornadas.
  Future<List<Card>> fetchCardsByDexRange(int start, int end) async {
    final rows = await _store.fetchByDexRange(start, end);
    return rows.map(Card.fromSupabaseRow).toList();
  }
}
