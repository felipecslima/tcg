import 'package:flutter/material.dart';

import '../models/card_detail.dart';
import '../models/tcg_card.dart';
import '../services/fx_service.dart';
import '../services/tcgdex_api_service.dart';
import '../theme/app_colors.dart';

/// Página da carta escolhida: dados completos + valores de mercado
/// (Cardmarket / TCGplayer) da TCGdex.
class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({
    super.key,
    required this.card,
    required this.language,
  });

  final TcgCard card;
  final String language;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  final _api = TcgdexApiService();
  late Future<CardDetail> _future;
  FxRates? _fx; // câmbio pra mostrar em reais; null = mostra em € / US$

  @override
  void initState() {
    super.initState();
    _future = _api.fetchCard(widget.card.id, language: widget.language);
    FxService.load().then((r) {
      if (mounted && r != null) setState(() => _fx = r);
    });
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.fetchCard(widget.card.id, language: widget.language);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.card.name)),
      body: FutureBuilder<CardDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return _ErrorView(onRetry: _reload, message: '${snap.error ?? "sem dados"}');
          }
          return _DetailBody(detail: snap.data!, fallback: widget.card, fx: _fx);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.fallback, this.fx});
  final CardDetail detail;
  final TcgCard fallback;
  final FxRates? fx;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final img = detail.imageUrl('high') ?? fallback.thumbnailUrl;
    final total = detail.printedTotal != 0 ? detail.printedTotal : fallback.printedTotal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (img != null)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(img, height: 380, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 380)),
            ),
          ),
        const SizedBox(height: 16),
        Text(detail.name, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(
          '#${detail.localId}${total != 0 ? '/$total' : ''}'
          '${detail.setName.isNotEmpty ? ' · ${detail.setName}' : ''}',
          style: t.bodyMedium?.copyWith(color: AppColors.text3),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (detail.rarity != null) _Chip(detail.rarity!),
            if (detail.stage != null) _Chip(detail.stage!),
            if (detail.category != null) _Chip(detail.category!),
            for (final ty in detail.types) _Chip(ty),
            if (detail.hp != null) _Chip('${detail.hp} PS'),
            if (detail.regulationMark != null) _Chip('Marca ${detail.regulationMark}'),
          ],
        ),
        const SizedBox(height: 20),

        const _SectionTitle('Valores de mercado'),
        _PricingCard(detail.pricing, fx: fx, updatedAt: detail.updated),

        if (detail.attacks.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionTitle('Ataques'),
          for (final a in detail.attacks) _AttackTile(a),
        ],

        if (detail.weaknesses.isNotEmpty || detail.retreat != null) ...[
          const SizedBox(height: 20),
          const _SectionTitle('Combate'),
          if (detail.weaknesses.isNotEmpty)
            Text('Fraqueza: ${detail.weaknesses.map((w) => '${w.type} ${w.value ?? ''}'.trim()).join(', ')}',
                style: t.bodyMedium),
          if (detail.retreat != null)
            Text('Custo de recuo: ${detail.retreat}', style: t.bodyMedium),
        ],

        if (detail.illustrator != null) ...[
          const SizedBox(height: 20),
          Text('Ilustração: ${detail.illustrator}',
              style: t.bodySmall?.copyWith(color: AppColors.text4)),
        ],
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard(this.pricing, {this.fx, this.updatedAt});
  final MarketPricing? pricing;
  final FxRates? fx;
  final DateTime? updatedAt;

  /// Valor no display: em reais se tem câmbio, senão na moeda original.
  String _v(String unit, double? value) {
    if (value == null) return '—';
    if (fx != null) return formatBrl(fx!.toBrl(unit, value));
    return '${unit == 'USD' ? 'US\$ ' : '€ '}${value.toStringAsFixed(2)}';
  }

  /// A moeda original, pra mostrar pequeno ao lado do valor em reais.
  String _orig(String unit, double? value) {
    if (value == null || fx == null) return '';
    return '${unit == 'USD' ? 'US\$ ' : '€ '}${value.toStringAsFixed(2)}';
  }

  static String _tpLabel(String key) {
    switch (key) {
      case 'normal':
        return 'Normal';
      case 'holofoil':
        return 'Holo';
      case 'reverse-holofoil':
        return 'Reverse Holo';
      case 'firstEditionHolofoil':
        return '1ª Edição Holo';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pricing;
    if (p == null || p.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sem valores de mercado disponíveis.'),
        ),
      );
    }
    final t = Theme.of(context).textTheme;
    final cm = p.cardmarket;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cm != null) ...[
              Text('Cardmarket',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_v('EUR', cm.trend ?? cm.avg),
                    style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                if (_orig('EUR', cm.trend ?? cm.avg).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 3),
                    child: Text(_orig('EUR', cm.trend ?? cm.avg),
                        style: t.bodySmall?.copyWith(color: AppColors.text4)),
                  ),
              ]),
              Text('tendência', style: t.bodySmall?.copyWith(color: AppColors.text4)),
              const SizedBox(height: 8),
              Wrap(spacing: 16, runSpacing: 4, children: [
                _kv('média', _v('EUR', cm.avg)),
                _kv('mínimo', _v('EUR', cm.low)),
                _kv('7 dias', _v('EUR', cm.avg7)),
                _kv('30 dias', _v('EUR', cm.avg30)),
              ]),
              if (cm.hasHolo) ...[
                const SizedBox(height: 10),
                Text('Reverse / Holo',
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  _kv('tendência', _v('EUR', cm.trendHolo)),
                  _kv('média', _v('EUR', cm.avgHolo)),
                  _kv('mínimo', _v('EUR', cm.lowHolo)),
                ]),
              ],
            ],
            if (cm != null && p.tcgplayer.isNotEmpty) const Divider(height: 24),
            if (p.tcgplayer.isNotEmpty) ...[
              Text('TCGplayer',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final e in p.tcgplayer.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(_tpLabel(e.key), style: t.bodyMedium),
                      ),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_v('USD', e.value.market ?? e.value.mid),
                                style: t.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                            Text(
                              'mín ${_v('USD', e.value.low)} · méd ${_v('USD', e.value.mid)}',
                              style: t.bodySmall?.copyWith(color: AppColors.text4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              _footer(),
              style: t.bodySmall?.copyWith(color: AppColors.text6),
            ),
          ],
        ),
      ),
    );
  }

  String _footer() {
    final buf = StringBuffer('Fonte: TCGdex');
    if (updatedAt != null) buf.write(' · preços de ${_date(updatedAt!)}');
    if (fx != null) {
      buf.write('\nCâmbio: € 1 = ${formatBrl(fx!.eurToBrl)} · '
          'US\$ 1 = ${formatBrl(fx!.usdToBrl)}');
      if (fx!.date != null) buf.write(' (${_date(fx!.date!)})');
    }
    return buf.toString();
  }

  static Widget _kv(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(k, style: const TextStyle(fontSize: 11, color: AppColors.text4)),
        ],
      );

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _AttackTile extends StatelessWidget {
  const _AttackTile(this.attack);
  final CardAttack attack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (attack.cost.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text('(${attack.cost.join(' ')})',
                      style: t.bodySmall?.copyWith(color: AppColors.text4)),
                ),
              Expanded(
                child: Text(attack.name,
                    style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (attack.damage != null && attack.damage!.isNotEmpty)
                Text(attack.damage!,
                    style: t.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          if (attack.effect != null && attack.effect!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(attack.effect!, style: t.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, required this.message});
  final VoidCallback onRetry;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.text4),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text('Não consegui carregar os dados da carta.\n$message',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.text3)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
}
