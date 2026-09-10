import 'package:flutter/material.dart' hide Card;

import '../models/card.dart';
import '../repositories/card_repository.dart';
import '../repositories/collection_repository.dart';
import '../repositories/pokedex_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_widgets.dart';
import '../widgets/pokemon_variations_sheet.dart';
import 'card_detail_screen.dart';

/// Grade de cartas por região — mostra slots owned (arte) vs missing (silhueta).
class RegionCardsScreen extends StatefulWidget {
  const RegionCardsScreen({super.key, required this.region});
  final RegionBrief region;

  @override
  State<RegionCardsScreen> createState() => _RegionCardsScreenState();
}

class _RegionCardsScreenState extends State<RegionCardsScreen> {
  final _cardRepo = CardRepository();
  final _collectionRepo = CollectionRepository();

  List<_DexSlot>? _slots;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await _cardRepo.fetchCardsByDexRange(
        widget.region.dexStart,
        widget.region.dexEnd,
      );
      final ownedIds = await _collectionRepo.fetchAllOwnedCardIds();

      // Agrupar por national_dex_id: pegar a primeira carta de cada dex como
      // representante (a que o jogador tem, se tiver; senão qualquer uma).
      final byDex = <int, List<Card>>{};
      for (final c in cards) {
        for (final dex in c.nationalDexIds) {
          if (dex >= widget.region.dexStart && dex <= widget.region.dexEnd) {
            byDex.putIfAbsent(dex, () => []).add(c);
          }
        }
      }

      final slots = <_DexSlot>[];
      for (var dex = widget.region.dexStart; dex <= widget.region.dexEnd; dex++) {
        final candidates = byDex[dex] ?? [];
        final ownedCard = candidates.where((c) => ownedIds.contains(c.id)).toList();
        if (ownedCard.isNotEmpty) {
          slots.add(_DexSlot(dexId: dex, card: ownedCard.first, owned: true, allCards: candidates));
        } else if (candidates.isNotEmpty) {
          slots.add(_DexSlot(dexId: dex, card: candidates.first, owned: false, allCards: candidates));
        } else {
          slots.add(_DexSlot(dexId: dex, card: null, owned: false));
        }
      }

      if (!mounted) return;
      setState(() {
        _slots = slots;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: top + 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppColors.border1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios, size: 13, color: AppColors.text2),
                    const SizedBox(width: 4),
                    Text('Jornadas', style: AppType.button),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(widget.region.name, style: AppType.screenTitle),
          ),
          const SizedBox(height: 4),
          if (_slots != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                '${_slots!.where((s) => s.owned).length}/${_slots!.length} Pokémon',
                style: AppType.caption,
              ),
            ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text('Erro: $_error', style: AppType.body.copyWith(color: AppColors.text3)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 63 / 88,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _slots!.length,
      itemBuilder: (context, i) {
        final slot = _slots![i];
        return _SlotTile(
          slot: slot,
          onTap: slot.card != null
              ? () {
                  if (slot.owned) {
                    showPokemonVariationsSheet(
                      context: context,
                      nationalDexId: slot.dexId,
                      pokemonName: slot.card!.name,
                      cardRepo: _cardRepo,
                      collectionRepo: _collectionRepo,
                    );
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CardDetailScreen(
                        card: slot.card!,
                        origin: widget.region.name,
                      ),
                    ));
                  }
                }
              : null,
        );
      },
    );
  }
}

class _DexSlot {
  const _DexSlot({required this.dexId, this.card, required this.owned, this.allCards = const []});
  final int dexId;
  final Card? card;
  final bool owned;
  final List<Card> allCards;
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, this.onTap});
  final _DexSlot slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (slot.owned && slot.card?.thumbnailUrl != null) {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.gridArt),
          child: Image.network(
            slot.card!.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: _placeholder(),
    );
  }

  Widget _placeholder() {
    return ArtPlaceholder(
      radius: AppRadii.gridArt,
      missing: !slot.owned,
    );
  }
}
