import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokecardex_scanner_mvp/repositories/api_cache_logger.dart';
import 'package:pokecardex_scanner_mvp/repositories/card_repository.dart';
import 'package:pokecardex_scanner_mvp/services/tcgdex_api_service.dart';

class _FakeCardStore implements CardStore {
  _FakeCardStore(this.rows);
  List<Map<String, dynamic>> rows;
  int upsertCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async => rows;

  @override
  Future<List<Map<String, dynamic>>> fetchBySet(String setId) async =>
      rows.where((r) => (r['set_id'] as String?) == setId).toList();

  @override
  Future<Map<String, dynamic>?> fetchById(String id) async =>
      _firstOrNull(rows.where((r) => (r['id'] as String?) == id));

  @override
  Future<void> upsertAll(List<Map<String, dynamic>> newRows) async {
    upsertCalls++;
    for (final r in newRows) {
      rows.removeWhere((e) => e['id'] == r['id']);
      rows.add(r);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchByName(String query, {int limit = 20}) async =>
      rows.where((r) => (r['name'] as String? ?? '').toLowerCase().contains(query.toLowerCase())).take(limit).toList();

  @override
  Future<List<Map<String, dynamic>>> fetchByDexRange(int start, int end) async =>
      rows.where((r) {
        final dex = r['national_dex_id'] as int?;
        return dex != null && dex >= start && dex <= end;
      }).toList();

  @override
  Future<List<Map<String, dynamic>>> fetchByNationalDexId(int dexId) async =>
      rows.where((r) => (r['national_dex_id'] as int?) == dexId).toList();
}

T? _firstOrNull<T>(Iterable<T> it) => it.isEmpty ? null : it.first;

const _setCardsJson = '''
{"id":"me01","name":"Megaevolução","cardCount":{"official":132},
 "cards":[{"id":"me01-091","name":"Shroodle","localId":"091","image":"https://x/091","dexId":[567]}]}
''';

const _cardDetailJson = '''
{"id":"me01-091","name":"Shroodle","localId":"091","rarity":"Common","hp":70,
 "set":{"name":"Megaevolução","cardCount":{"official":132}}}
''';

void main() {
  setUp(TcgdexApiService.clearMemoryCache);

  Map<String, dynamic> freshBriefRow({String? updatedAt}) => {
        'id': 'me01-091',
        'set_id': 'me01',
        'local_id': '091',
        'name': 'Shroodle',
        'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      };

  test('fresh: cartas do set já na base não disparam chamada de API', () async {
    var hits = 0;
    final store = _FakeCardStore([freshBriefRow()]);
    final repo = CardRepository(
      store: store,
      api: TcgdexApiService(client: MockClient((req) async {
        hits++;
        return http.Response(_setCardsJson, 200);
      })),
      cacheLogger: const NoopApiCacheLogger(),
    );

    final cards = await repo.fetchCardsForSet('me01');

    expect(hits, 0);
    expect(cards, hasLength(1));
  });

  test('vazio: busca cartas do set na API e grava antes de devolver', () async {
    var hits = 0;
    final store = _FakeCardStore([]);
    final repo = CardRepository(
      store: store,
      api: TcgdexApiService(client: MockClient((req) async {
        hits++;
        return http.Response(_setCardsJson, 200);
      })),
      cacheLogger: const NoopApiCacheLogger(),
    );

    final cards = await repo.fetchCardsForSet('me01');

    expect(hits, 1);
    expect(store.upsertCalls, 1);
    expect(cards, hasLength(1));
    expect(cards.first.name, 'Shroodle');
  });

  test('detalhe: carta brief sem raridade busca detalhe completo e grava', () async {
    var hits = 0;
    final store = _FakeCardStore([freshBriefRow()]); // fresca, mas sem rarity
    final repo = CardRepository(
      store: store,
      api: TcgdexApiService(client: MockClient((req) async {
        hits++;
        return http.Response(_cardDetailJson, 200);
      })),
      cacheLogger: const NoopApiCacheLogger(),
    );

    final card = await repo.fetchCardDetail('me01-091');

    expect(hits, 1, reason: 'brief sem rarity deveria buscar o detalhe mesmo fresco');
    expect(card.rarity, 'Common');
    expect(card.hp, 70);
    expect(card.setId, 'me01', reason: 'não deveria perder o set_id que já estava na base');
  });

  test('API fora do ar: detalhe cai pro que já tem na base', () async {
    final store = _FakeCardStore([
      {...freshBriefRow(), 'rarity': 'Common', 'hp': 70},
    ]);
    final repo = CardRepository(
      store: store,
      api: TcgdexApiService(client: MockClient((req) async {
        return http.Response('erro', 500);
      })),
      cacheLogger: const NoopApiCacheLogger(),
    );

    final card = await repo.fetchCardDetail('me01-091');

    expect(card.rarity, 'Common');
  });
}
