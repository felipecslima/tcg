import 'package:flutter/material.dart';

import '../../repositories/collection_repository.dart';
import '../../repositories/set_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/loaders/loaders.dart';
import '../../widgets/primary_button.dart';

/// Tela 1 do fluxo (README §1 "Escolher coleção") — sub-view da aba
/// Escanear, não uma rota (tab bar continua visível).
///
/// Simplificações assumidas (documentadas no relatório):
/// - Sem o card "Continuar de onde parou" — calcular "último set usado"
///   exigiria uma query extra sem valor claro pro P0; fica pro backlog.
/// - Sem chips de região: o schema não mapeia `sets` (coleção de TCG) pra
///   `regions` (faixa de national dex da Pokédex) — são conceitos
///   diferentes no catálogo hoje. Filtrar por região exigiria essa
///   ligação, que não existe. Só a busca por nome funciona.
class SetpickView extends StatefulWidget {
  const SetpickView({super.key, required this.onSelectSet, required this.onSkip});

  final ValueChanged<CardSetBrief> onSelectSet;
  final VoidCallback onSkip;

  @override
  State<SetpickView> createState() => _SetpickViewState();
}

class _SetpickViewState extends State<SetpickView> {
  final _setRepo = CardSetRepository();
  final _collectionRepo = CollectionRepository();
  final _searchController = TextEditingController();

  List<CardSetBrief>? _sets;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      // A carga inicial do catálogo (~23.5k cartas, ver HANDOFF) foi feita
      // em inglês — usar 'pt' aqui só teria efeito se a base estivesse
      // vazia/vencida e disparasse um refetch, o que reescreveria os nomes
      // fora do idioma do resto do catálogo já carregado.
      final sets = await _setRepo.fetchAllSets();
      if (!mounted) return;
      setState(() => _sets = sets);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Não consegui carregar as coleções: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final sets = _sets;
    final filtered = sets == null
        ? const <CardSetBrief>[]
        : query.isEmpty
            ? sets
            : sets.where((s) => s.name.toLowerCase().contains(query)).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ANTES DE ESCANEAR', style: AppType.sectionLabel),
            const SizedBox(height: 10),
            Text('De qual coleção são as cartas?', style: AppType.screenTitle),
            const SizedBox(height: 6),
            Text(
              'Isso reduz o universo de busca e deixa os candidatos confiáveis.',
              style: AppType.body.copyWith(color: AppColors.text3),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar coleção',
                prefixIcon: const Icon(Icons.search, color: AppColors.text4),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildList(filtered)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: DottedButton(
                label: 'Não sei a coleção — escanear mesmo assim',
                onPressed: widget.onSkip,
              ),
            ),
            const SizedBox(height: 90), // folga da tab bar flutuante
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<CardSetBrief> filtered) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: AppType.body),
            const SizedBox(height: 12),
            SecondaryButton(label: 'Tentar de novo', onPressed: _load),
          ],
        ),
      );
    }
    if (_sets == null) {
      return const Center(child: MedalhaoLoader());
    }
    if (filtered.isEmpty) {
      return Center(child: Text('Nenhuma coleção encontrada.', style: AppType.body));
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _SetRow(
        set: filtered[i],
        collectionRepo: _collectionRepo,
        onTap: () => widget.onSelectSet(filtered[i]),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set, required this.collectionRepo, required this.onTap});

  final CardSetBrief set;
  final CollectionRepository collectionRepo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.listRow),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.listRow),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              set.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.miniArt),
                      child: Image.network(set.logoUrl!,
                          width: 44, height: 44, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const ArtPlaceholder(width: 44, height: 44)),
                    )
                  : const ArtPlaceholder(width: 44, height: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(set.name, style: AppType.listTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${set.printedTotal} cartas', style: AppType.caption),
                    const SizedBox(height: 6),
                    FutureBuilder<int>(
                      future: collectionRepo.countOwnedInSet(set.id),
                      builder: (context, snap) {
                        final owned = snap.data ?? 0;
                        final total = set.printedTotal == 0 ? 1 : set.printedTotal;
                        return ProgressBar(value: owned / total);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.text5),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão de borda tracejada (README: rodapé do Setpick).
class DottedButton extends StatelessWidget {
  const DottedButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.listRow),
        onTap: onPressed,
        child: CustomPaint(
          painter: const _DashedBorderPainter(radius: AppRadii.listRow),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(label, style: AppType.button.copyWith(color: AppColors.primary)),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.radius});
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    const dashWidth = 5.0, dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => false;
}
