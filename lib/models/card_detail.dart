/// Dados completos de uma carta, do endpoint individual da TCGdex
/// (`/v2/{lang}/cards/{id}`) — inclui raridade, ataques e **valores de
/// mercado** (Cardmarket em EUR, TCGplayer em USD). O endpoint de set só
/// devolve a versão "brief" (nome, número, imagem), por isso a busca extra.
library;

class CardDetail {
  CardDetail({
    required this.id,
    required this.name,
    required this.localId,
    required this.printedTotal,
    required this.setName,
    this.imageBaseUrl,
    this.rarity,
    this.illustrator,
    this.category,
    this.stage,
    this.hp,
    this.regulationMark,
    this.types = const [],
    this.dexIds = const [],
    this.attacks = const [],
    this.weaknesses = const [],
    this.retreat,
    this.variants = const {},
    this.pricing,
    this.updated,
  });

  final String id;
  final String name;
  final String localId;
  final int printedTotal;
  final String setName;
  final String? imageBaseUrl;
  final String? rarity;
  final String? illustrator;
  final String? category; // "Pokémon", "Treinador", "Energia"
  final String? stage; // "Básico", "Estágio 1", ...
  final int? hp;
  final String? regulationMark;
  final List<String> types;
  final List<int> dexIds;
  final List<CardAttack> attacks;
  final List<CardWeakness> weaknesses;
  final int? retreat;
  final Map<String, bool> variants; // normal / holo / reverse / firstEdition / wPromo
  final MarketPricing? pricing;
  final DateTime? updated;

  String? imageUrl(String quality) =>
      imageBaseUrl == null ? null : '$imageBaseUrl/$quality.webp';

  factory CardDetail.fromJson(Map<String, dynamic> j) {
    final set = j['set'] as Map<String, dynamic>?;
    final total = set?['cardCount'] as Map<String, dynamic>? ??
        set?['total'] as Map<String, dynamic>?;
    return CardDetail(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      localId: j['localId']?.toString() ?? '',
      printedTotal: (total?['official'] as num?)?.toInt() ??
          (total?['total'] as num?)?.toInt() ??
          0,
      setName: set?['name'] as String? ?? '',
      imageBaseUrl: j['image'] as String?,
      rarity: j['rarity'] as String?,
      illustrator: j['illustrator'] as String?,
      category: j['category'] as String?,
      stage: j['stage'] as String?,
      hp: (j['hp'] as num?)?.toInt(),
      regulationMark: j['regulationMark'] as String?,
      types: (j['types'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      dexIds:
          (j['dexId'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      attacks: (j['attacks'] as List?)
              ?.map((e) => CardAttack.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      weaknesses: (j['weaknesses'] as List?)
              ?.map((e) => CardWeakness.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      retreat: (j['retreat'] as num?)?.toInt(),
      variants: (j['variants'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v == true)) ??
          const {},
      pricing: j['pricing'] == null
          ? null
          : MarketPricing.fromJson(j['pricing'] as Map<String, dynamic>),
      updated: DateTime.tryParse(j['updated'] as String? ?? ''),
    );
  }
}

class CardAttack {
  CardAttack({required this.name, this.cost = const [], this.damage, this.effect});
  final String name;
  final List<String> cost;
  final String? damage;
  final String? effect;

  factory CardAttack.fromJson(Map<String, dynamic> j) => CardAttack(
        name: j['name'] as String? ?? '',
        cost: (j['cost'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        damage: j['damage']?.toString(),
        effect: j['effect'] as String?,
      );
}

class CardWeakness {
  CardWeakness({required this.type, this.value});
  final String type;
  final String? value;

  factory CardWeakness.fromJson(Map<String, dynamic> j) => CardWeakness(
        type: j['type'] as String? ?? '',
        value: j['value']?.toString(),
      );
}

// ---------------------------------------------------------------------------
// Valores de mercado
// ---------------------------------------------------------------------------

class MarketPricing {
  MarketPricing({this.cardmarket, this.tcgplayer = const {}});

  final CardmarketPrice? cardmarket;

  /// TCGplayer: uma entrada por variante ("normal", "holofoil",
  /// "reverse-holofoil", ...).
  final Map<String, TcgplayerPrice> tcgplayer;

  bool get isEmpty => cardmarket == null && tcgplayer.isEmpty;

  factory MarketPricing.fromJson(Map<String, dynamic> j) {
    final cm = j['cardmarket'] as Map<String, dynamic>?;
    final tp = j['tcgplayer'] as Map<String, dynamic>?;
    final tpVariants = <String, TcgplayerPrice>{};
    if (tp != null) {
      for (final entry in tp.entries) {
        if (entry.value is Map<String, dynamic>) {
          final p = TcgplayerPrice.fromJson(entry.value as Map<String, dynamic>);
          if (p.hasAny) tpVariants[entry.key] = p;
        }
      }
    }
    return MarketPricing(
      cardmarket: cm == null ? null : CardmarketPrice.fromJson(cm),
      tcgplayer: tpVariants,
    );
  }
}

class CardmarketPrice {
  CardmarketPrice({
    required this.unit,
    this.trend,
    this.avg,
    this.low,
    this.avg7,
    this.avg30,
    this.trendHolo,
    this.avgHolo,
    this.lowHolo,
    this.updated,
  });

  final String unit; // "EUR"
  final double? trend, avg, low, avg7, avg30;
  final double? trendHolo, avgHolo, lowHolo;
  final DateTime? updated;

  bool get hasHolo => trendHolo != null || avgHolo != null || lowHolo != null;

  factory CardmarketPrice.fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    return CardmarketPrice(
      unit: j['unit'] as String? ?? 'EUR',
      trend: d('trend'),
      avg: d('avg'),
      low: d('low'),
      avg7: d('avg7'),
      avg30: d('avg30'),
      trendHolo: d('trend-holo'),
      avgHolo: d('avg-holo'),
      lowHolo: d('low-holo'),
      updated: DateTime.tryParse(j['updated'] as String? ?? ''),
    );
  }
}

class TcgplayerPrice {
  TcgplayerPrice({this.market, this.low, this.mid, this.directLow});
  final double? market, low, mid, directLow;

  bool get hasAny => market != null || low != null || mid != null;

  factory TcgplayerPrice.fromJson(Map<String, dynamic> j) {
    // highPrice vem como 999 (sentinela) — ignorado.
    double? d(String k) {
      final v = (j[k] as num?)?.toDouble();
      return (v == null || v >= 999) ? null : v;
    }

    return TcgplayerPrice(
      market: d('marketPrice'),
      low: d('lowPrice'),
      mid: d('midPrice'),
      directLow: d('directLowPrice'),
    );
  }
}
