import 'package:flutter/material.dart' hide Card;
import 'package:provider/provider.dart';

import '../models/card.dart';
import '../models/card_detail.dart' show CardAttack, CardmarketPrice, MarketPricing;
import '../repositories/card_repository.dart';
import '../repositories/collection_repository.dart';
import '../services/fx_service.dart';
import '../state/app_shell_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/loaders/loaders.dart';
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
    this.language,
  });

  final Card card;
  final CollectionCardEntry? entry;
  final String origin;
  final String? language;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  late Card _card;
  bool _loading = false;
  bool _detailLoaded = false;
  String? _error;
  FxRates? _fx;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _detailLoaded = !_card.isBrief;
    _fetchDetail();
    _loadFx();
  }

  Future<void> _loadFx() async {
    final fx = await FxService.load();
    if (mounted && fx != null) setState(() => _fx = fx);
  }

  Future<void> _fetchDetail() async {
    if (_card.isBrief) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final lang = widget.language ?? widget.entry?.language ?? 'pt';
      final detail = await CardRepository().fetchCardDetail(_card.id, language: lang);
      if (!mounted) return;
      setState(() {
        _card = detail.copyWith(priceBrl: widget.card.priceBrl);
        _loading = false;
        _detailLoaded = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        if (!_detailLoaded) _detailLoaded = _card.rarity != null;
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
              fx: _fx,
              language: widget.language ?? widget.entry?.language ?? 'pt',
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
    this.fx,
    this.language = 'pt',
  });

  final Card card;
  final CollectionCardEntry? entry;
  final String origin;
  final bool loading;
  final bool detailLoaded;
  final FxRates? fx;
  final String language;

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
                const Center(child: MedalhaoLoader()),
              ],
              if (detailLoaded) ...[
                const SizedBox(height: 14),
                _ChipsRow(card: card, language: language),
                if (card.nationalDexIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _NationalDexBadge(dexIds: card.nationalDexIds),
                ],
                if (card.attacks.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _AttacksCard(attacks: card.attacks, hp: card.hp),
                ],
                const SizedBox(height: 20),
                _CardInfoCard(card: card),
                if (entry != null) ...[
                  const SizedBox(height: 20),
                  _CollectionCard(card: card, entry: entry!),
                ],
                if (card.pricing != null && !card.pricing!.isEmpty) ...[
                  const SizedBox(height: 20),
                  _PricingCard(pricing: card.pricing!, fx: fx, fallbackBrl: card.priceBrl),
                ] else if (card.priceBrl != null) ...[
                  const SizedBox(height: 20),
                  _PricingCard(
                    pricing: MarketPricing(),
                    fx: fx,
                    fallbackBrl: card.priceBrl,
                  ),
                ],
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

class _CardInfoCard extends StatelessWidget {
  const _CardInfoCard({required this.card});
  final Card card;

  @override
  Widget build(BuildContext context) {
    final activeVariants = card.variants.entries
        .where((e) => e.value)
        .map((e) => _variantLabel(e.key))
        .toList();

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
          Text('SOBRE A CARTA', style: AppType.sectionLabel),
          const SizedBox(height: 14),
          if (card.setName.isNotEmpty)
            _InfoRow(label: 'Set', value: card.setName),
          if (card.localId.isNotEmpty)
            _InfoRow(
              label: 'Número',
              value: card.printedTotal > 0
                  ? '${card.localId} / ${card.printedTotal}'
                  : card.localId,
            ),
          if (card.rarity != null)
            _InfoRow(label: 'Raridade', value: card.rarity!, valueColor: AppColors.gold),
          if (card.category != null)
            _InfoRow(label: 'Categoria', value: card.category!),
          if (card.stage != null)
            _InfoRow(label: 'Estágio', value: card.stage!),
          if (card.hp != null)
            _InfoRow(label: 'HP', value: '${card.hp}'),
          if (card.types.isNotEmpty)
            _InfoRow(label: 'Tipo', value: card.types.join(', ')),
          if (card.weaknesses.isNotEmpty)
            _InfoRow(
              label: 'Fraqueza',
              value: card.weaknesses
                  .map((w) => '${w.type} ${w.value ?? ''}'.trim())
                  .join(', '),
            ),
          if (card.retreat != null)
            _InfoRow(label: 'Recuo', value: '${'●' * card.retreat!} (${card.retreat})'),
          if (card.regulationMark != null)
            _InfoRow(label: 'Regulação', value: card.regulationMark!),
          if (activeVariants.isNotEmpty)
            _InfoRow(label: 'Variantes', value: activeVariants.join(', ')),
          if (card.illustrator != null) ...[
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.brush_outlined, size: 14, color: AppColors.text3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    card.illustrator!,
                    style: AppType.bodySm.copyWith(color: AppColors.text2),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _variantLabel(String key) {
    switch (key) {
      case 'normal': return 'Normal';
      case 'holo': return 'Holo';
      case 'reverse': return 'Reverse Holo';
      case 'firstEdition': return '1ª Edição';
      case 'wPromo': return 'Promo';
      default: return key;
    }
  }
}

class _CollectionCard extends StatefulWidget {
  const _CollectionCard({required this.card, required this.entry});
  final Card card;
  final CollectionCardEntry entry;

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _removing = false;

  Future<void> _confirmRemove() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.text4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.delete_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 14),
            Text('Remover da coleção?', style: AppType.listTitleLg),
            const SizedBox(height: 8),
            Text(
              '${widget.card.name} (${widget.entry.quantity}x) será removida permanentemente.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.text3),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Remover'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancelar', style: AppType.button.copyWith(color: AppColors.text2)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _removing = true);
    try {
      await CollectionRepository().removeCardFromCollection(widget.entry.id);
      if (!mounted) return;
      context.read<AppShellController>().goToCollectionWithToast(
        '${widget.card.name} removida',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final entry = widget.entry;

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
          Text('SUA COLEÇÃO', style: AppType.sectionLabel),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatCell(label: 'Quantidade', value: '${entry.quantity}x')),
              const SizedBox(width: 12),
              Expanded(child: _StatCell(label: 'Estado', value: entry.condition)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCell(label: 'Acabamento', value: _finishLabel(entry.finish))),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCell(
                  label: 'Idioma',
                  value: CollectionCardEntry.languageLabel(entry.language),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'Valor estimado',
                  value: card.priceBrl != null
                      ? 'R\$ ${card.priceBrl!.toStringAsFixed(2)}'
                      : '—',
                  valueColor: card.priceBrl != null ? AppColors.gold : null,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              onPressed: _removing ? null : _confirmRemove,
              icon: _removing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                    )
                  : const Icon(Icons.delete_outline, size: 18),
              label: Text(_removing ? 'Removendo…' : 'Remover da coleção'),
            ),
          ),
        ],
      ),
    );
  }

  static String _finishLabel(String? finish) {
    switch (finish) {
      case 'holo': return 'Holo';
      case 'reverse': return 'Reverse';
      case 'normal': return 'Normal';
      default: return finish ?? '—';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppType.bodySm.copyWith(color: AppColors.text3)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppType.bodySm.copyWith(
                color: valueColor ?? AppColors.text1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.card, this.language = 'pt'});
  final Card card;
  final String language;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      for (final t in card.types) t,
      if (card.stage != null) card.stage!,
      if (card.category != null) card.category!,
      if (card.hp != null) '${card.hp} HP',
      if (card.regulationMark != null) 'Reg. ${card.regulationMark}',
    ];
    final langLabel = CollectionCardEntry.languageLabel(language);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.tint,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, size: 13, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(langLabel, style: AppType.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        for (final label in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.tint,
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Text(label, style: AppType.caption.copyWith(color: AppColors.text2)),
          ),
      ],
    );
  }
}

class _NationalDexBadge extends StatelessWidget {
  const _NationalDexBadge({required this.dexIds});
  final List<int> dexIds;

  @override
  Widget build(BuildContext context) {
    final label = dexIds.length == 1
        ? 'Pokédex Nacional nº ${dexIds.first}'
        : 'Pokédex Nacional nº ${dexIds.join(', ')}';
    return Row(
      children: [
        const Icon(Icons.catching_pokemon, size: 16, color: AppColors.text3),
        const SizedBox(width: 6),
        Text(label, style: AppType.caption.copyWith(color: AppColors.text3)),
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.pricing, this.fx, this.fallbackBrl});
  final MarketPricing pricing;
  final FxRates? fx;
  final double? fallbackBrl;

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
          Text('PREÇOS DE MERCADO', style: AppType.sectionLabel),
          const SizedBox(height: 14),
          if (pricing.cardmarket != null) _cardmarketSection(pricing.cardmarket!),
          if (pricing.cardmarket != null && pricing.tcgplayer.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],
          if (pricing.tcgplayer.isNotEmpty) _tcgplayerSection(),
          if (pricing.cardmarket == null && pricing.tcgplayer.isEmpty && fallbackBrl != null)
            _PriceLine(label: 'Estimativa', value: formatBrl(fallbackBrl!)),
        ],
      ),
    );
  }

  Widget _cardmarketSection(CardmarketPrice cm) {
    final lines = <_PriceLine>[];
    if (cm.trend != null) lines.add(_PriceLine(label: 'Tendência', value: _fmtPrice(cm.unit, cm.trend!)));
    if (cm.avg != null) lines.add(_PriceLine(label: 'Média', value: _fmtPrice(cm.unit, cm.avg!)));
    if (cm.low != null) lines.add(_PriceLine(label: 'Mínimo', value: _fmtPrice(cm.unit, cm.low!)));
    if (cm.avg7 != null) lines.add(_PriceLine(label: 'Média 7d', value: _fmtPrice(cm.unit, cm.avg7!)));
    if (cm.avg30 != null) lines.add(_PriceLine(label: 'Média 30d', value: _fmtPrice(cm.unit, cm.avg30!)));
    if (cm.trendHolo != null) lines.add(_PriceLine(label: 'Holo tendência', value: _fmtPrice(cm.unit, cm.trendHolo!)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cardmarket', style: AppType.bodySm.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...lines,
      ],
    );
  }

  Widget _tcgplayerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TCGplayer', style: AppType.bodySm.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final entry in pricing.tcgplayer.entries) ...[
          Text(_variantLabel(entry.key), style: AppType.caption.copyWith(color: AppColors.text3)),
          const SizedBox(height: 4),
          if (entry.value.market != null) _PriceLine(label: 'Market', value: _fmtPrice('USD', entry.value.market!)),
          if (entry.value.low != null) _PriceLine(label: 'Low', value: _fmtPrice('USD', entry.value.low!)),
          if (entry.value.mid != null) _PriceLine(label: 'Mid', value: _fmtPrice('USD', entry.value.mid!)),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  String _fmtPrice(String unit, double value) {
    final orig = '${unit == 'EUR' ? '€' : 'US\$'} ${value.toStringAsFixed(2)}';
    if (fx == null) return orig;
    final brl = fx!.toBrl(unit, value);
    return '$orig  (${formatBrl(brl)})';
  }

  static String _variantLabel(String key) {
    switch (key) {
      case 'normal':
        return 'Normal';
      case 'holofoil':
        return 'Holofoil';
      case 'reverseHolofoil':
      case 'reverse-holofoil':
        return 'Reverse Holofoil';
      case 'firstEdition':
      case 'first-edition':
        return '1st Edition';
      default:
        return key;
    }
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppType.bodySm.copyWith(color: AppColors.text3)),
          Text(value, style: AppType.mono.copyWith(fontSize: 13, color: AppColors.text1)),
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
