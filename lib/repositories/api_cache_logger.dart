import 'package:supabase_flutter/supabase_flutter.dart';

/// Grava o payload cru de uma chamada de API externa em `api_cache_raw` e
/// marca `fetch_log`, conforme o requisito de dados do HANDOFF ("toda
/// resposta de API externa DEVE ser gravada na base ANTES de ir pra UI").
///
/// Best-effort: essas duas tabelas são só observabilidade/infra de staleness
/// — uma falha aqui nunca deve impedir a tela de receber o dado.
abstract class ApiCacheLogger {
  Future<void> logRawResponse({
    required String source,
    required String endpoint,
    Map<String, dynamic> params = const {},
    required dynamic body,
    int status = 200,
  });

  Future<void> touchFetchLog({
    required String source,
    required String entityType,
    required String entityId,
    required Duration ttl,
  });
}

class SupabaseApiCacheLogger implements ApiCacheLogger {
  SupabaseApiCacheLogger(this._client);
  final SupabaseClient _client;

  @override
  Future<void> logRawResponse({
    required String source,
    required String endpoint,
    Map<String, dynamic> params = const {},
    required dynamic body,
    int status = 200,
  }) async {
    try {
      await _client.from('api_cache_raw').insert({
        'source': source,
        'endpoint': endpoint,
        'params': params,
        'status': status,
        'body': body,
      });
    } catch (_) {
      // best-effort
    }
  }

  @override
  Future<void> touchFetchLog({
    required String source,
    required String entityType,
    required String entityId,
    required Duration ttl,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      await _client.from('fetch_log').insert({
        'source': source,
        'entity_type': entityType,
        'entity_id': entityId,
        'ttl_seconds': ttl.inSeconds,
        'fetched_at': now.toIso8601String(),
        'next_refresh_at': now.add(ttl).toIso8601String(),
      });
    } catch (_) {
      // best-effort
    }
  }
}

/// No-op — usado em teste, onde `api_cache_raw`/`fetch_log` não importam
/// pro comportamento sendo verificado.
class NoopApiCacheLogger implements ApiCacheLogger {
  const NoopApiCacheLogger();

  @override
  Future<void> logRawResponse({
    required String source,
    required String endpoint,
    Map<String, dynamic> params = const {},
    required dynamic body,
    int status = 200,
  }) async {}

  @override
  Future<void> touchFetchLog({
    required String source,
    required String entityType,
    required String entityId,
    required Duration ttl,
  }) async {}
}
