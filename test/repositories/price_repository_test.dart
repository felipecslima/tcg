import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokecardex_scanner_mvp/repositories/price_repository.dart';
import 'package:pokecardex_scanner_mvp/services/tcgdex_api_service.dart';

class _FakePriceStore implements PriceStore {
  final List<Map<String, dynamic>> rows = [];
  int insertCalls = 0;

  @override
  Future<Map<String, dynamic>?> fetchLatest(String cardId) async {
    final matches = rows.where((r) => r['card_id'] == cardId).toList()
      ..sort((a, b) => (b['fetched_at'] as String).compareTo(a['fetched_at'] as String));
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<void> insert(Map<String, dynamic> row) async {
    insertCalls++;
    rows.add(row);
  }
}

const _cardWithPriceJson = '''
{"id":"me01-091","name":"Shroodle","localId":"091",
 "set":{"name":"Megaevolução","cardCount":{"official":132}},
 "pricing":{"cardmarket":{"unit":"EUR","trend":1.5}}}
''';

void main() {
  setUp(TcgdexApiService.clearMemoryCache);

  test('sem preço na base: busca na API e grava linha nova (append-only)', () async {
    var hits = 0;
    final store = _FakePriceStore();
    final repo = PriceRepository(
      store: store,
      api: TcgdexApiService(client: MockClient((req) async {
        hits++;
        return http.Response(_cardWithPriceJson, 200);
      })),
    );

    final price = await repo.fetchLatestPrice('me01-091');

    expect(hits, 1);
    expect(store.insertCalls, 1);
    expect(price, isNotNull);
    expect(price!.currency, 'EUR');
    expect(price.market, 1.5);
  });

  test('preço fresco (<24h): não bate na API de novo', () async {
    var hits = 0;
    final store = _FakePriceStore()
      ..rows.add({
        'card_id': 'me01-091',
        'currency': 'EUR',
        'market': 1.5,
        'fetched_at': DateTime.now().toUtc().toIso8601String(),
      });
    final repo = PriceRepository(
      store: store,
      api: TcgdexApiService(client: MockClient((req) async {
        hits++;
        return http.Response(_cardWithPriceJson, 200);
      })),
    );

    await repo.fetchLatestPrice('me01-091');

    expect(hits, 0);
  });

  test('preço vencido e API fora do ar: serve o preço velho em vez de propagar erro', () async {
    final old = DateTime.now().toUtc().subtract(const Duration(days: 2));
    final store = _FakePriceStore()
      ..rows.add({
        'card_id': 'me01-091',
        'currency': 'EUR',
        'market': 1.5,
        'fetched_at': old.toIso8601String(),
      });
    final repo = PriceRepository(
      store: store,
      api: TcgdexApiService(client: MockClient((req) async {
        return http.Response('erro', 500);
      })),
    );

    final price = await repo.fetchLatestPrice('me01-091');

    expect(price, isNotNull);
    expect(price!.market, 1.5);
  });
}
