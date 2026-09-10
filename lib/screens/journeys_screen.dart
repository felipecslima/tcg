import 'dart:math' as math;

import 'package:flutter/material.dart' hide Card;

import '../repositories/card_repository.dart';
import '../repositories/collection_repository.dart';
import '../repositories/pokedex_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_widgets.dart';
import 'region_cards_screen.dart';

class JourneysScreen extends StatefulWidget {
  const JourneysScreen({super.key});

  @override
  State<JourneysScreen> createState() => _JourneysScreenState();
}

class _JourneysScreenState extends State<JourneysScreen> {
  final _pokedexRepo = PokedexRepository();
  final _cardRepo = CardRepository();
  final _collectionRepo = CollectionRepository();

  List<_RegionProgress>? _regions;
  bool _loading = true;
  String? _error;
  bool _trailView = true;

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
      final regions = await _pokedexRepo.fetchRegions();
      final ownedIds = await _collectionRepo.fetchAllOwnedCardIds();

      final result = <_RegionProgress>[];
      for (final r in regions) {
        final cards = await _cardRepo.fetchCardsByDexRange(r.dexStart, r.dexEnd);
        final uniqueDex = <int>{};
        final ownedDex = <int>{};
        for (final c in cards) {
          for (final dex in c.nationalDexIds) {
            if (dex >= r.dexStart && dex <= r.dexEnd) {
              uniqueDex.add(dex);
              if (ownedIds.contains(c.id)) ownedDex.add(dex);
            }
          }
        }
        result.add(_RegionProgress(
          region: r,
          totalPokemon: r.dexEnd - r.dexStart + 1,
          ownedPokemon: ownedDex.length,
        ));
      }

      if (!mounted) return;
      setState(() {
        _regions = result;
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppTheme.screenPadding.copyWith(bottom: 120),
        children: [
          Row(
            children: [
              Expanded(child: Text('Jornadas', style: AppType.screenTitle)),
              _ViewToggle(
                trailView: _trailView,
                onToggle: () => setState(() => _trailView = !_trailView),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: CircularProgressIndicator(),
            ))
          else if (_error != null)
            Center(child: Text('Erro: $_error', style: AppType.body.copyWith(color: AppColors.text3)))
          else if (_regions != null) ...[
            if (_trailView)
              _TrailView(regions: _regions!, onTap: _openRegion)
            else
              _ListView(regions: _regions!, onTap: _openRegion),
          ],
        ],
      ),
    );
  }

  void _openRegion(_RegionProgress rp) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RegionCardsScreen(region: rp.region),
    ));
  }
}

class _RegionProgress {
  const _RegionProgress({
    required this.region,
    required this.totalPokemon,
    required this.ownedPokemon,
  });

  final RegionBrief region;
  final int totalPokemon;
  final int ownedPokemon;

  double get progress => totalPokemon == 0 ? 0 : ownedPokemon / totalPokemon;
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.trailView, required this.onToggle});
  final bool trailView;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAccent,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Icon(
          trailView ? Icons.view_list_rounded : Icons.route_rounded,
          size: 20,
          color: AppColors.text2,
        ),
      ),
    );
  }
}

class _TrailView extends StatelessWidget {
  const _TrailView({required this.regions, required this.onTap});
  final List<_RegionProgress> regions;
  final ValueChanged<_RegionProgress> onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrailLinePainter(itemCount: regions.length),
      child: Column(
        children: [
          for (var i = 0; i < regions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TrailNode(
                rp: regions[i],
                index: i,
                onTap: () => onTap(regions[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrailLinePainter extends CustomPainter {
  const _TrailLinePainter({required this.itemCount});
  final int itemCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount < 2) return;

    const nodeHeight = 88.0;
    const leftOffset = 30.0;

    final dashPaint = Paint()
      ..color = AppColors.border2
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < itemCount - 1; i++) {
      final y1 = i * nodeHeight + nodeHeight / 2;
      final y2 = (i + 1) * nodeHeight + nodeHeight / 2;
      const dashLen = 5.0;
      const gap = 4.0;
      var y = y1;
      while (y < y2) {
        final end = math.min(y + dashLen, y2);
        canvas.drawLine(Offset(leftOffset, y), Offset(leftOffset, end), dashPaint);
        y = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrailLinePainter old) => old.itemCount != itemCount;
}

class _TrailNode extends StatelessWidget {
  const _TrailNode({required this.rp, required this.index, required this.onTap});
  final _RegionProgress rp;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final started = rp.ownedPokemon > 0;
    final pct = (rp.progress * 100).round();
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: started ? AppColors.gradNode : null,
                    color: started ? null : AppColors.surfaceSunken,
                    border: started ? null : Border.all(color: AppColors.border2),
                  ),
                  child: Center(
                    child: Text(
                      '$pct%',
                      style: AppType.mono.copyWith(
                        fontSize: 11,
                        color: started ? Colors.white : AppColors.text4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.border1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(rp.region.name, style: AppType.listTitle),
                    const SizedBox(height: 6),
                    ProgressBar(value: rp.progress, height: 5),
                    const SizedBox(height: 4),
                    Text(
                      '${rp.ownedPokemon}/${rp.totalPokemon} Pokémon',
                      style: AppType.caption,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.regions, required this.onTap});
  final List<_RegionProgress> regions;
  final ValueChanged<_RegionProgress> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final rp in regions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => onTap(rp),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(rp.region.name, style: AppType.listTitle)),
                        Text(
                          '${(rp.progress * 100).round()}%',
                          style: AppType.mono.copyWith(
                            color: rp.progress > 0 ? AppColors.primary : AppColors.text4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(value: rp.progress),
                    const SizedBox(height: 4),
                    Text(
                      '${rp.ownedPokemon}/${rp.totalPokemon} Pokémon',
                      style: AppType.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
