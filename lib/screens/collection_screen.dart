import 'package:flutter/material.dart' hide Card;
import 'package:provider/provider.dart';

import '../repositories/collection_repository.dart';
import '../repositories/pokedex_repository.dart';
import '../repositories/price_repository.dart';
import '../services/fx_service.dart';
import '../state/app_shell_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_widgets.dart';
import '../widgets/primary_button.dart';
import 'card_detail_screen.dart';

/// Tela "Minhas cartas" (README §7) — aba padrão do app, fim do fluxo de
/// scan. Mostra o binder `kind == 'default'` ("Minhas cartas").
///
/// Simplificação assumida (documentar): os números do hero (contagem,
/// valor estimado, regiões) são calculados só sobre este binder, não a
/// soma de todos os binders da usuária — é o que a tela realmente lista
/// logo abaixo, então os dois números batem visualmente.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

enum _Filter { all, holo, rare, duplicates }

class _CollectionScreenState extends State<CollectionScreen> {
  final _collectionRepo = CollectionRepository();
  final _pokedexRepo = PokedexRepository();

  List<UserCollection>? _collections;
  List<CollectionCardEntry>? _entries;
  int _regionsCount = 0;
  String? _error;
  _Filter _filter = _Filter.all;

  late final AppShellController _shell;
  int _lastGeneration = 0;

  @override
  void initState() {
    super.initState();
    _shell = context.read<AppShellController>();
    _lastGeneration = _shell.collectionGeneration;
    _shell.addListener(_onShellChanged);
    _load();
  }

  @override
  void dispose() {
    _shell.removeListener(_onShellChanged);
    super.dispose();
  }

  void _onShellChanged() {
    if (_shell.collectionGeneration != _lastGeneration) {
      _lastGeneration = _shell.collectionGeneration;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final collections = await _collectionRepo.fetchUserCollections();
      final defaultCollection = collections.firstWhere(
        (c) => c.kind == 'default',
        orElse: () => collections.first,
      );
      final entries = await _collectionRepo.fetchCollectionCards(defaultCollection.id);
      final dexIds = entries.expand((e) => e.card.nationalDexIds).toSet().toList();
      final regions = await _pokedexRepo.regionIdsForNationalDexIds(dexIds);
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _entries = entries;
        _regionsCount = regions.length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Não consegui carregar sua coleção: $e');
    }
  }

  List<CollectionCardEntry> get _filtered {
    final entries = _entries ?? const [];
    switch (_filter) {
      case _Filter.all:
        return entries;
      case _Filter.holo:
        return entries.where((e) => e.finish == 'holo').toList();
      case _Filter.rare:
        return entries.where((e) {
          final r = e.card.rarity?.toLowerCase() ?? '';
          return r.contains('rare') || r.contains('rara');
        }).toList();
      case _Filter.duplicates:
        return entries.where((e) => e.quantity > 1).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    if (_entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final entries = _entries!;
    final totalCards = entries.fold<int>(0, (sum, e) => sum + e.quantity);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppTheme.screenPadding.copyWith(top: 66, bottom: 120),
        children: [
          _Hero(
            totalCards: totalCards,
            collectionsCount: _collections?.length ?? 0,
            regionsCount: _regionsCount,
            entries: entries,
          ),
          const SizedBox(height: 20),
          _FilterChips(current: _filter, onChanged: (f) => setState(() => _filter = f)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const _EmptyState()
          else if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Nenhuma carta nesse filtro.', style: AppType.body)),
            )
          else
            for (final e in _filtered) _CollectionRow(entry: e),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.totalCards,
    required this.collectionsCount,
    required this.regionsCount,
    required this.entries,
  });

  final int totalCards;
  final int collectionsCount;
  final int regionsCount;
  final List<CollectionCardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.gradHero,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SUA COLEÇÃO',
              style: AppType.sectionLabel.copyWith(color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 8),
          Text('$totalCards', style: AppType.hero.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text('$collectionsCount coleções · $regionsCount regiões',
              style: AppType.body.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.28), height: 1),
          const SizedBox(height: 10),
          _EstimatedValue(entries: entries),
        ],
      ),
    );
  }
}

/// Valor estimado — única aparição do valor total no app (decisão travada
/// no README). Busca o preço mais recente de cada carta distinta; falha
/// silenciosa por carta (mostra "—" se não tiver preço nenhum ainda).
class _EstimatedValue extends StatefulWidget {
  const _EstimatedValue({required this.entries});
  final List<CollectionCardEntry> entries;

  @override
  State<_EstimatedValue> createState() => _EstimatedValueState();
}

class _EstimatedValueState extends State<_EstimatedValue> {
  final _priceRepo = PriceRepository();
  double? _total;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _EstimatedValue old) {
    super.didUpdateWidget(old);
    if (old.entries != widget.entries) _load();
  }

  Future<void> _load() async {
    if (widget.entries.isEmpty) {
      setState(() {
        _total = 0;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    // Preço por carta distinta (não por linha) — o binder tende a ter
    // dezenas de cartas, não milhares, então N chamadas (cacheadas em
    // memória/disco pelo TcgdexApiService por baixo do PriceRepository)
    // é aceitável pra 6 usuárias.
    final byCardId = <String, int>{};
    for (final e in widget.entries) {
      byCardId[e.card.id] = (byCardId[e.card.id] ?? 0) + e.quantity;
    }
    double sum = 0;
    for (final entry in byCardId.entries) {
      try {
        final price = await _priceRepo.fetchLatestPrice(entry.key);
        if (price?.brl != null) sum += price!.brl! * entry.value;
      } catch (_) {
        // uma carta sem preço não deve derrubar o total das outras
      }
    }
    if (!mounted) return;
    setState(() {
      _total = sum;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = _loading
        ? 'valor estimado …'
        : 'valor estimado ${_total != null && _total! > 0 ? formatBrl(_total!) : '—'}';
    return Text(
      label,
      style: AppType.mono.copyWith(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.current, required this.onChanged});
  final _Filter current;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Filter.all: 'Todas',
      _Filter.holo: 'Holo',
      _Filter.rare: 'Ultra raras',
      _Filter.duplicates: 'Repetidas',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in _Filter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(
                label: labels[f]!,
                selected: current == f,
                onTap: () => onChanged(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({required this.entry});
  final CollectionCardEntry entry;

  @override
  Widget build(BuildContext context) {
    final card = entry.card;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.listRow),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.listRow),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CardDetailScreen(
                card: card,
                entry: entry,
                origin: 'Coleção',
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                card.thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.miniArt),
                        child: Image.network(card.thumbnailUrl!, width: 46, height: 64, fit: BoxFit.cover),
                      )
                    : const ArtPlaceholder(width: 46, height: 64, radius: AppRadii.miniArt),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name, style: AppType.listTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        entry.language != 'pt'
                            ? '${card.setName} · ${entry.condition} · ${entry.language.toUpperCase()}'
                            : '${card.setName} · ${entry.condition}',
                        style: AppType.caption,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${entry.quantity}x', style: AppType.mono),
                    if (card.rarity != null) ...[
                      const SizedBox(height: 2),
                      Text(card.rarity!, style: AppType.caption.copyWith(color: AppColors.gold)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.catching_pokemon, size: 56, color: AppColors.lilac200),
          const SizedBox(height: 16),
          Text('Sua coleção está vazia', style: AppType.listTitleLg),
          const SizedBox(height: 8),
          Text('Escaneie sua primeira carta!',
              textAlign: TextAlign.center, style: AppType.body.copyWith(color: AppColors.text3)),
          const SizedBox(height: 16),
          Builder(builder: (ctx) {
            return PrimaryButton(
              label: 'Escanear carta',
              onPressed: () => ctx.read<AppShellController>().switchToTab(2),
            );
          }),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: AppType.body),
            const SizedBox(height: 12),
            SecondaryButton(label: 'Tentar de novo', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
