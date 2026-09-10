import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/fx_service.dart';
import '../services/tcgdex_api_service.dart';
import 'staleness.dart';

/// Preço mais recente de uma carta, já convertido pra BRL quando possível.
class CardPrice {
  const CardPrice({
    required this.cardId,
    this.brl,
    this.currency,
    this.market,
    required this.fetchedAt,
  });

  final String cardId;
  final double? brl;
  final String? currency; // moeda original (EUR/USD) antes da conversão
  final double? market; // valor original, na moeda de origem
  final DateTime fetchedAt;

  factory CardPrice.fromSupabaseRow(Map<String, dynamic> row, {double? brl}) => CardPrice(
        cardId: row['card_id'] as String,
        brl: brl,
        currency: row['currency'] as String?,
        market: (row['market'] as num?)?.toDouble(),
        fetchedAt: DateTime.parse(row['fetched_at'] as String),
      );
}

/// Abstração fina sobre `card_prices` (append-only) — permite fake em teste.
abstract class PriceStore {
  Future<Map<String, dynamic>?> fetchLatest(String cardId);
  Future<void> insert(Map<String, dynamic> row);
}

class SupabasePriceStore implements PriceStore {
  SupabasePriceStore(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> fetchLatest(String cardId) async {
    final rows = await _client
        .from('card_prices')
        .select()
        .eq('card_id', cardId)
        .order('fetched_at', ascending: false)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : list.first;
  }

  @override
  Future<void> insert(Map<String, dynamic> row) async {
    await _client.from('card_prices').insert(row);
  }
}

/// Preço de carta — DB-first, TTL 24h. `card_prices` é append-only: cada
/// refresh grava uma linha nova (histórico pra variação %), nunca faz update.
/// Guarda o valor na moeda original (`currency`/`market`) e converte pra
/// BRL na leitura via `FxService` — evita depender de cotação do momento
/// em que o preço foi gravado.
class PriceRepository {
  PriceRepository({PriceStore? store, TcgdexApiService? api})
      : _store = store ?? SupabasePriceStore(Supabase.instance.client),
        _api = api ?? TcgdexApiService();

  static const _ttl = Duration(hours: 24);

  final PriceStore _store;
  final TcgdexApiService _api;

  Future<CardPrice?> fetchLatestPrice(String cardId, {String language = 'en'}) async {
    var row = await _store.fetchLatest(cardId);
    final fetchedAt = row == null ? null : DateTime.tryParse(row['fetched_at'] as String? ?? '');
    if (row == null || isStale(fetchedAt, _ttl)) {
      try {
        final detail = await _api.fetchCard(cardId, language: language);
        final pricing = detail.pricing;
        if (pricing != null && !pricing.isEmpty) {
          final cm = pricing.cardmarket;
          String? currency;
          double? market;
          if (cm != null) {
            currency = cm.unit;
            market = cm.avg ?? cm.trend;
          }
          if (market == null) {
            final tp = pricing.tcgplayer.values.where((p) => p.market != null).firstOrNull;
            if (tp != null) {
              currency = 'USD';
              market = tp.market;
            }
          }
          if (market != null) {
            final newRow = {
              'card_id': cardId,
              'source': 'tcgdex',
              'currency': currency,
              'market': market,
              'fetched_at': DateTime.now().toUtc().toIso8601String(),
            };
            try {
              await _store.insert(newRow);
            } catch (_) {
              // RLS pode impedir insert pelo client — sem problema
            }
            row = newRow;
          }
        }
      } catch (_) {
        // API fora do ar (ou sem preço): serve o que já tem, mesmo vencido.
      }
    }
    if (row == null) return null;
    double? brl;
    final currency = row['currency'] as String?;
    final market = (row['market'] as num?)?.toDouble();
    if (currency != null && market != null) {
      final rates = await FxService.load();
      brl = rates?.toBrl(currency, market);
    }
    return CardPrice.fromSupabaseRow(row, brl: brl);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
