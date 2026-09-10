import '../repositories/collection_repository.dart';
import '../repositories/pokedex_repository.dart';
import '../repositories/price_repository.dart';

class CollectionStats {
  const CollectionStats({
    required this.totalCards,
    required this.uniqueCards,
    required this.totalValue,
    required this.regionsStarted,
  });

  final int totalCards;
  final int uniqueCards;
  final double totalValue;
  final int regionsStarted;

  int get xp => uniqueCards * 10;

  int get level {
    const thresholds = [0, 50, 150, 300, 500, 800, 1200, 1800, 2500, 3500];
    for (var i = thresholds.length - 1; i >= 0; i--) {
      if (xp >= thresholds[i]) return i + 1;
    }
    return 1;
  }

  double get levelProgress {
    const thresholds = [0, 50, 150, 300, 500, 800, 1200, 1800, 2500, 3500];
    final lvl = level;
    if (lvl >= thresholds.length) return 1.0;
    final current = thresholds[lvl - 1];
    final next = thresholds[lvl];
    return (xp - current) / (next - current);
  }

  static Future<CollectionStats> compute({
    required CollectionRepository collectionRepo,
    required PokedexRepository pokedexRepo,
    required PriceRepository priceRepo,
  }) async {
    final collections = await collectionRepo.fetchUserCollections();
    final defaultCollection = collections.firstWhere(
      (c) => c.kind == 'default',
      orElse: () => collections.first,
    );
    final entries = await collectionRepo.fetchCollectionCards(defaultCollection.id);

    final totalCards = entries.fold<int>(0, (sum, e) => sum + e.quantity);
    final uniqueCards = entries.map((e) => e.card.id).toSet().length;

    final dexIds = entries.expand((e) => e.card.nationalDexIds).toSet().toList();
    final regions = await pokedexRepo.regionIdsForNationalDexIds(dexIds);

    double totalValue = 0;
    final seen = <String>{};
    for (final e in entries) {
      if (seen.add(e.card.id)) {
        try {
          final price = await priceRepo.fetchLatestPrice(e.card.id);
          if (price?.brl != null) totalValue += price!.brl! * e.quantity;
        } catch (_) {}
      }
    }

    return CollectionStats(
      totalCards: totalCards,
      uniqueCards: uniqueCards,
      totalValue: totalValue,
      regionsStarted: regions.length,
    );
  }
}
