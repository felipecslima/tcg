import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokecardex_scanner_mvp/repositories/api_cache_logger.dart';
import 'package:pokecardex_scanner_mvp/repositories/set_repository.dart';
import 'package:pokecardex_scanner_mvp/services/tcgdex_api_service.dart';

class _FakeSetStore implements SetStore {
  _FakeSetStore(this.rows);
  List<Map<String, dynamic>> rows;
  int upsertCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async => rows;

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
}

T? _firstOrNull<T>(Iterable<T> it) => it.isEmpty ? null : it.first;

const _setsJson = '''
[{"id":"me01","name":"Megaevolução","logo":"https://x/me01","cardCount":{"official":132}}]
''';

void main() {
  setUp(TcgdexApiService.clearMemoryCache);

  Map<String, dynamic> freshRow({String id = 'me01', String? updatedAt}) => {
        'id': id,
        'name': 'Megaevolução',
        'printed_total': 132,
        'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      };

  test('fresh: não bate na API quando a base tem dado recente', () async {
    var hits = 0;
    final store = _FakeSetStore([freshRow()]);
    final repo = CardSetRepository(
      store: store,
      api: TcgdexApiService(client: MockClient((req) async {
        hits++;
        return http.Response(_setsJson, 200);
      })),
      cacheLogger: const NoopApiCacheLogger(),
    );

    final sets = await repo.fetchAllSets();

    expect(sets, hasLength(1));
    expect(hits, 0, reason: 'dado fresco não deveria disparar chamada de API');
    expect(store.upsertCalls, 0);
  });

  test('vazio: busca na API e grava na base antes de devolver', () async {
    var hits = 0;
    final store = _FakeSetStore([]);
    final repo = CardSetRepository(
      store: store,
      api: TcgdexApiService(client: MockClient((req) async {
        hits++;
        return http.Response(_setsJson, 200);
      })),
      cacheLogger: const NoopApiCacheLogger(),
    );

    final sets = await repo.fetchAllSets();

    expect(hits, 1);
    expect(store.upsertCalls, 1);
    expect(sets, hasLength(1));
    expect(sets.first.id, 'me01');
  });

  test('vencido: refetch, mas se a API falhar serve o dado velho da base', () async {
    final oldDate = DateTime.now().toUtc().subtract(const Duration(days: 60));
    final store = _FakeSetStore([freshRow(updatedAt: oldDate.toIso8601String())]);
    final repo = CardSetRepository(
      store: store,
      api: TcgdexApiService(client: MockClient((req) async {
        return http.Response('erro', 500);
      })),
      cacheLogger: const NoopApiCacheLogger(),
    );

    final sets = await repo.fetchAllSets();

    expect(sets, hasLength(1), reason: 'API fora do ar: deveria servir o dado vencido');
    expect(sets.first.id, 'me01');
  });
}
