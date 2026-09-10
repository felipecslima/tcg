import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:pokecardex_scanner_mvp/services/tcgdex_api_service.dart';

const _cardJson = '''
{"id":"me01-091","name":"Shroodle","localId":"091",
 "set":{"name":"Megaevolução","cardCount":{"official":132}},
 "pricing":{"cardmarket":{"unit":"EUR","trend":0.03}}}
''';

void main() {
  setUp(TcgdexApiService.clearMemoryCache);

  test('fetchCard: 2ª chamada vem do cache, não bate na rede', () async {
    var hits = 0;
    final api = TcgdexApiService(client: MockClient((req) async {
      hits++;
      return http.Response(_cardJson, 200);
    }));

    final a = await api.fetchCard('me01-091', language: 'pt');
    final b = await api.fetchCard('me01-091', language: 'pt');

    expect(a.name, 'Shroodle');
    expect(b.name, 'Shroodle');
    expect(hits, 1, reason: 'a 2ª chamada deveria vir da memória');
  });

  test('fetchCard: idioma diferente é chave diferente', () async {
    var hits = 0;
    final api = TcgdexApiService(client: MockClient((req) async {
      hits++;
      return http.Response(_cardJson, 200);
    }));

    await api.fetchCard('me01-091', language: 'pt');
    await api.fetchCard('me01-091', language: 'en');
    expect(hits, 2);
  });

  test('fetchCard: requisições simultâneas da mesma carta são deduplicadas',
      () async {
    var hits = 0;
    final api = TcgdexApiService(client: MockClient((req) async {
      hits++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response(_cardJson, 200);
    }));

    await Future.wait([
      api.fetchCard('me01-091', language: 'pt'),
      api.fetchCard('me01-091', language: 'pt'),
      api.fetchCard('me01-091', language: 'pt'),
    ]);
    expect(hits, 1);
  });
}
