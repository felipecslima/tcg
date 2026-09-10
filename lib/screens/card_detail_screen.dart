import 'package:flutter/material.dart' hide Card;

import '../models/card.dart';
import '../models/card_detail.dart' show CardAttack;
import '../repositories/card_repository.dart';
import '../repositories/collection_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_widgets.dart';

/// Tela de detalhe de uma carta — destino de Coleção, Busca, Candidatos.
/// Recebe um [Card] (pode ser brief) e um [CollectionCardEntry] opcional
/// (quando vem da coleção, mostra qty/condition/finish).
class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({
    super.key,
    required this.card,
    this.entry,
    this.origin = 'Voltar',
  });

  final Card card;
  final CollectionCardEntry? entry;
  final String origin;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  late Card _card;
  bool _loading = false;
  bool _detailLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    if (_card.isBrief) {
      _fetchDetail();
    } else {
      _detailLoaded = true;
    }
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await CardRepository().fetchCardDetail(_card.id);
      if (!mounted) return;
      setState(() {
        _card = detail.copyWith(priceBrl: widget.card.priceBrl);
        _loading = false;
        _detailLoaded = true;
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _error != null && !_detailLoaded
          ? _ErrorView(message: _error!, onRetry: _fetchDetail)
          : _DetailBody(
              card: _card,
              entry: widget.entry,
              origin: widget.origin,
              loading: _loading,
              detailLoaded: _detailLoaded,
            ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.card,
    this.entry,
    required this.origin,
    this.loading = false,
    this.detailLoaded = false,
  });

  final Card card;
  final CollectionCardEntry? entry;
  final String origin;
  final bool loading;
  final bool detailLoaded;

  @override
  Widget build(BuildContext context) {
    final imgUrl = card.imageUrl('high') ?? card.thumbnailUrl;
    final top = MediaQuery.of(context).padding.top;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
      children: [
        _HeroZone(
          imageUrl: imgUrl,
          origin: origin,
          topPadding: top,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              Text(card.name, style: AppType.cardTitle),
              const SizedBox(height: 6),
              _MetadataLine(card: card),
              if (loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              if (detailLoaded) ...[
                if (card.attacks.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _AttacksCard(attacks: card.attacks, hp: card.hp),
                ],
                const SizedBox(height: 20),
                _StatsGrid(card: card, entry: entry),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroZone extends StatelessWidget {
  const _HeroZone({
    required this.imageUrl,
    required this.origin,
    required this.topPadding,
  });

  final String? imageUrl;
  final String origin;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.gradVeil),
      child: Column(
        children: [
          SizedBox(height: topPadding + 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _BackPill(label: origin, onTap: () => Navigator.of(context).pop()),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: imageUrl != null
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppShadows.hero,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        imageUrl!,
                        width: 190,
                        height: 265,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ArtPlaceholder(width: 190, height: 265, radius: 14),
                      ),
                    ),
                  )
                : const ArtPlaceholder(width: 190, height: 265, radius: 14),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _BackPill extends StatelessWidget {
  const _BackPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            Text(label, style: AppType.button),
          ],
        ),
      ),
    );
  }
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.card});
  final Card card;

  @override
  Widget build(BuildContext context) {
    final parts = <InlineSpan>[];

    if (card.setName.isNotEmpty) {
      parts.add(TextSpan(text: card.setName));
    }
    if (card.localId.isNotEmpty) {
      if (parts.isNotEmpty) parts.add(const TextSpan(text: ' · '));
      final num = card.printedTotal > 0
          ? '${card.localId}/${card.printedTotal}'
          : card.localId;
      parts.add(TextSpan(text: num));
    }
    if (card.rarity != null) {
      if (parts.isNotEmpty) parts.add(const TextSpan(text: ' · '));
      parts.add(TextSpan(
        text: card.rarity!,
        style: AppType.caption.copyWith(color: AppColors.gold),
      ));
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return RichText(
      text: TextSpan(style: AppType.caption, children: parts),
    );
  }
}

class _AttacksCard extends StatelessWidget {
  const _AttacksCard({required this.attacks, this.hp});
  final List<CardAttack> attacks;
  final int? hp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Text('ATAQUES', style: AppType.sectionLabel),
              const Spacer(),
              if (hp != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldSurface,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '$hp PS',
                    style: AppType.mono.copyWith(color: AppColors.gold, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < attacks.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 10),
            ],
            _AttackRow(attack: attacks[i]),
          ],
        ],
      ),
    );
  }
}

class _AttackRow extends StatelessWidget {
  const _AttackRow({required this.attack});
  final CardAttack attack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (attack.cost.isNotEmpty) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final energy in attack.cost)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _EnergyCost(type: energy),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(attack.name, style: AppType.listTitle),
            ),
            if (attack.damage != null && attack.damage!.isNotEmpty)
              Text(attack.damage!, style: AppType.mono.copyWith(fontSize: 16)),
          ],
        ),
        if (attack.effect != null && attack.effect!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(attack.effect!, style: AppType.bodySm.copyWith(color: AppColors.text3)),
        ],
      ],
    );
  }
}

class _EnergyCost extends StatelessWidget {
  const _EnergyCost({required this.type});
  final String type;

  static const _colorMap = <String, Color>{
    'Fogo': Color(0xFFF44336),
    'Fire': Color(0xFFF44336),
    'Água': Color(0xFF2196F3),
    'Water': Color(0xFF2196F3),
    'Planta': Color(0xFF4CAF50),
    'Grass': Color(0xFF4CAF50),
    'Elétrico': Color(0xFFFFEB3B),
    'Lightning': Color(0xFFFFEB3B),
    'Psíquico': Color(0xFF9C27B0),
    'Psychic': Color(0xFF9C27B0),
    'Lutador': Color(0xFFAD6227),
    'Fighting': Color(0xFFAD6227),
    'Noturno': Color(0xFF37474F),
    'Darkness': Color(0xFF37474F),
    'Metal': Color(0xFF78909C),
    'Fada': Color(0xFFE91E9C),
    'Fairy': Color(0xFFE91E9C),
    'Dragão': Color(0xFFFF9800),
    'Dragon': Color(0xFFFF9800),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colorMap[type] ?? AppColors.text4;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.card, this.entry});
  final Card card;
  final CollectionCardEntry? entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DETALHES', style: AppType.sectionLabel),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'Você tem',
                  value: entry != null ? '${entry!.quantity}x' : '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCell(
                  label: 'Estado',
                  value: entry?.condition ?? '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'Acabamento',
                  value: _finishLabel(entry?.finish),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCell(
                  label: 'Valor estimado',
                  value: card.priceBrl != null
                      ? 'R\$ ${card.priceBrl!.toStringAsFixed(2)}'
                      : '—',
                  valueColor: card.priceBrl != null ? AppColors.gold : null,
                ),
              ),
            ],
          ),
          if (card.weaknesses.isNotEmpty || card.retreat != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            if (card.weaknesses.isNotEmpty)
              Text(
                'Fraqueza: ${card.weaknesses.map((w) => '${w.type} ${w.value ?? ''}'.trim()).join(', ')}',
                style: AppType.bodySm.copyWith(color: AppColors.text3),
              ),
            if (card.retreat != null)
              Text(
                'Custo de recuo: ${card.retreat}',
                style: AppType.bodySm.copyWith(color: AppColors.text3),
              ),
          ],
          if (card.illustrator != null) ...[
            const SizedBox(height: 10),
            Text(
              'Ilustração: ${card.illustrator}',
              style: AppType.caption,
            ),
          ],
        ],
      ),
    );
  }

  static String _finishLabel(String? finish) {
    switch (finish) {
      case 'holo':
        return 'Holo';
      case 'reverse':
        return 'Reverse';
      case 'normal':
        return 'Normal';
      default:
        return finish ?? '—';
    }
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppType.mono.copyWith(
              color: valueColor ?? AppColors.text1,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, required this.message});
  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.text4),
            const SizedBox(height: 12),
            Text(
              'Não consegui carregar os dados da carta.\n$message',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.text3),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
