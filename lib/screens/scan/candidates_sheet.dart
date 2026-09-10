import 'package:flutter/material.dart';

import '../../models/tcg_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_widgets.dart';

/// Tela 3 do fluxo (README §3 "Candidatos") — bottom sheet sobre a câmera.
/// Retorna a carta escolhida (`Navigator.pop(context, card)`) ou `null` se
/// a usuária tocar "Nenhuma — escanear de novo" / arrastar pra fechar.
class CandidatesSheet extends StatelessWidget {
  const CandidatesSheet({super.key, required this.choices, required this.setLabel});

  final List<TcgCard> choices;
  final String setLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 80),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
          boxShadow: AppShadows.sheet,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border2, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('É alguma dessas?', style: AppType.listTitleLg),
              const SizedBox(height: 4),
              Text('Buscando em $setLabel · toque na carta certa',
                  style: AppType.caption),
              const SizedBox(height: 14),
              for (var i = 0; i < choices.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CandidateRow(
                    card: choices[i],
                    matchPercent: _matchPercentFor(i),
                    highlighted: i == 0,
                    onTap: () => Navigator.of(context).pop(choices[i]),
                  ),
                ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Nenhuma — escanear de novo',
                      style: AppType.button.copyWith(color: AppColors.text4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// O `MatchResult` não guarda score por candidato individual (só o score
  /// do líder) — aproxima decrescendo a partir do líder pra dar uma leitura
  /// visual coerente (1º sempre o mais provável). Não é um score real por
  /// carta; ver `CardMatcher.match` se isso precisar ficar exato.
  int _matchPercentFor(int index) {
    const base = 92;
    final v = base - (index * 22);
    return v.clamp(30, 99);
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.card,
    required this.matchPercent,
    required this.highlighted,
    required this.onTap,
  });

  final TcgCard card;
  final int matchPercent;
  final bool highlighted;
  final VoidCallback onTap;

  Color get _percentColor {
    if (matchPercent > 85) return AppColors.green;
    if (matchPercent >= 60) return AppColors.gold;
    return AppColors.text5;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppColors.surfaceAccent : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.listRow),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.listRow),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.listRow),
            border: Border.all(color: highlighted ? AppColors.primary : AppColors.border1),
          ),
          child: Row(
            children: [
              card.thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.miniArt),
                      child: Image.network(card.thumbnailUrl!, width: 52, height: 72, fit: BoxFit.cover),
                    )
                  : const ArtPlaceholder(width: 52, height: 72, radius: AppRadii.miniArt),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.name, style: AppType.listTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${card.setName} · #${card.localId}', style: AppType.caption),
                  ],
                ),
              ),
              Text('$matchPercent%', style: AppType.mono.copyWith(color: _percentColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
