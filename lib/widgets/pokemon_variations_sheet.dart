import 'package:flutter/material.dart' hide Card;

import '../models/card.dart';
import '../repositories/card_repository.dart';
import '../repositories/collection_repository.dart';
import '../screens/card_detail_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_widgets.dart';
import 'loaders/loaders.dart';

/// Bottom sheet que lista todas as variações (cartas de diferentes sets) de um
/// Pokémon. Destaque visual nas que a usuária já possui.
Future<void> showPokemonVariationsSheet({
  required BuildContext context,
  required int nationalDexId,
  required String pokemonName,
  CardRepository? cardRepo,
  CollectionRepository? collectionRepo,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (_) => _VariationsSheet(
      nationalDexId: nationalDexId,
      pokemonName: pokemonName,
      cardRepo: cardRepo ?? CardRepository(),
      collectionRepo: collectionRepo ?? CollectionRepository(),
    ),
  );
}

class _VariationsSheet extends StatefulWidget {
  const _VariationsSheet({
    required this.nationalDexId,
    required this.pokemonName,
    required this.cardRepo,
    required this.collectionRepo,
  });

  final int nationalDexId;
  final String pokemonName;
  final CardRepository cardRepo;
  final CollectionRepository collectionRepo;

  @override
  State<_VariationsSheet> createState() => _VariationsSheetState();
}

class _VariationsSheetState extends State<_VariationsSheet> {
  List<Card>? _cards;
  Set<String>? _ownedIds;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await widget.cardRepo.fetchCardsForPokemon(widget.nationalDexId);
    final ownedIds = await widget.collectionRepo.fetchAllOwnedCardIds();
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _ownedIds = ownedIds;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.pokemonName,
                    style: AppType.listTitle,
                  ),
                ),
                Text(
                  '#${widget.nationalDexId}',
                  style: AppType.mono.copyWith(color: AppColors.text4),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: MiudoLoader()),
            )
          else if (_cards == null || _cards!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'Nenhuma carta encontrada',
                style: AppType.body.copyWith(color: AppColors.text3),
              ),
            )
          else
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _cards!.length,
                itemBuilder: (context, i) {
                  final card = _cards![i];
                  final owned = _ownedIds?.contains(card.id) ?? false;
                  return _VariationTile(
                    card: card,
                    owned: owned,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CardDetailScreen(
                          card: card,
                          origin: widget.pokemonName,
                        ),
                      ));
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _VariationTile extends StatelessWidget {
  const _VariationTile({
    required this.card,
    required this.owned,
    required this.onTap,
  });

  final Card card;
  final bool owned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(
            color: owned ? AppColors.primary : AppColors.border1,
            width: owned ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.xl - 1),
                ),
                child: card.thumbnailUrl != null
                    ? Image.network(
                        card.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ArtPlaceholder(),
                      )
                    : const ArtPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.setName.isNotEmpty ? card.setName : card.setId,
                    style: AppType.caption.copyWith(color: AppColors.text3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (card.rarity != null)
                    Text(
                      card.rarity!,
                      style: AppType.caption.copyWith(
                        color: AppColors.gold,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
