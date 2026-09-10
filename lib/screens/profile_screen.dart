import 'package:flutter/material.dart';

import '../repositories/collection_repository.dart';
import '../repositories/pokedex_repository.dart';
import '../repositories/price_repository.dart';
import '../services/auth_service.dart';
import '../services/collection_stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_widgets.dart';
import '../widgets/primary_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  CollectionStats? _stats;
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
      final stats = await CollectionStats.compute(
        collectionRepo: CollectionRepository(),
        pokedexRepo: PokedexRepository(),
        priceRepo: PriceRepository(),
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
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
          _HeroZone(stats: _stats, loading: _loading),
          const SizedBox(height: 20),
          if (_error != null)
            Center(
              child: Column(
                children: [
                  Text('Não foi possível carregar: $_error',
                      style: AppType.caption),
                  const SizedBox(height: 8),
                  SecondaryButton(label: 'Tentar de novo', onPressed: _load),
                ],
              ),
            )
          else if (_stats != null) ...[
            _StatsGrid(stats: _stats!),
            const SizedBox(height: 20),
            _Achievements(stats: _stats!),
          ],
          const SizedBox(height: 32),
          SecondaryButton(
            label: 'Sair da conta',
            onPressed: () => AuthService.instance.signOut(),
          ),
        ],
      ),
    );
  }
}

class _HeroZone extends StatelessWidget {
  const _HeroZone({this.stats, this.loading = false});
  final CollectionStats? stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final displayName = user?.userMetadata?['display_name'] as String? ?? user?.email ?? '—';
    final level = stats?.level ?? 1;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.gradVeil,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.tintStrong,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: AppType.hero.copyWith(color: AppColors.primary, fontSize: 28),
            ),
          ),
          const SizedBox(height: 12),
          Text(displayName, style: AppType.listTitleLg),
          const SizedBox(height: 4),
          Text('Nível $level', style: AppType.mono.copyWith(color: AppColors.text3)),
          const SizedBox(height: 14),
          if (loading)
            const SizedBox(
              height: 7,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.tint,
                color: AppColors.primary,
              ),
            )
          else
            ProgressBar(value: stats?.levelProgress ?? 0),
          const SizedBox(height: 6),
          Text(
            '${stats?.xp ?? 0} XP',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final CollectionStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ESTATÍSTICAS', style: AppType.sectionLabel),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Cartas registradas', value: '${stats.totalCards}')),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Valor total',
                value: stats.totalValue > 0
                    ? 'R\$ ${stats.totalValue.toStringAsFixed(0)}'
                    : '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Regiões iniciadas', value: '${stats.regionsStarted}')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Cartas únicas', value: '${stats.uniqueCards}')),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppType.mono.copyWith(fontSize: 20, color: AppColors.text1)),
          const SizedBox(height: 4),
          Text(label, style: AppType.caption),
        ],
      ),
    );
  }
}

class _Achievements extends StatelessWidget {
  const _Achievements({required this.stats});
  final CollectionStats stats;

  static const _achievements = [
    _Achievement('Primeiro passo', 'Registre sua primeira carta', 1),
    _Achievement('Mestre regional', 'Inicie 3 regiões', 3),
    _Achievement('Colecionador', 'Registre 50 cartas', 50),
    _Achievement('Lendário', 'Registre 200 cartas', 200),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONQUISTAS', style: AppType.sectionLabel),
        const SizedBox(height: 12),
        for (final a in _achievements)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AchievementRow(
              achievement: a,
              earned: _isEarned(a),
            ),
          ),
      ],
    );
  }

  bool _isEarned(_Achievement a) {
    if (a.label == 'Primeiro passo') return stats.totalCards >= a.threshold;
    if (a.label == 'Mestre regional') return stats.regionsStarted >= a.threshold;
    return stats.totalCards >= a.threshold;
  }
}

class _Achievement {
  const _Achievement(this.label, this.description, this.threshold);
  final String label;
  final String description;
  final int threshold;
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement, required this.earned});
  final _Achievement achievement;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: earned ? AppColors.goldSurface : AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: earned ? AppColors.gold.withValues(alpha: 0.3) : AppColors.border1),
      ),
      child: Row(
        children: [
          Icon(
            earned ? Icons.emoji_events : Icons.lock_outline,
            size: 24,
            color: earned ? AppColors.gold : AppColors.textDisabled,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.label,
                  style: AppType.listTitle.copyWith(
                    color: earned ? AppColors.text1 : AppColors.textDisabled,
                  ),
                ),
                Text(
                  achievement.description,
                  style: AppType.caption.copyWith(
                    color: earned ? AppColors.text3 : AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
