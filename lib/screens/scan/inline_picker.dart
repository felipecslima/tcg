import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/tcg_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_widgets.dart';

class InlinePicker extends StatelessWidget {
  const InlinePicker({super.key, required this.choices, required this.onPick, required this.onDismiss});

  final List<TcgCard> choices;
  final ValueChanged<TcgCard> onPick;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 22),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              boxShadow: AppShadows.hero,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Qual carta?', style: AppType.listTitleLg),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < choices.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: _PickOption(card: choices[i], onTap: () {
                        HapticFeedback.selectionClick();
                        onPick(choices[i]);
                      })),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onDismiss,
                  child: Text('Nenhuma', style: AppType.button.copyWith(color: AppColors.text4)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickOption extends StatelessWidget {
  const _PickOption({required this.card, required this.onTap});

  final TcgCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.listRow),
          border: Border.all(color: AppColors.border1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            card.thumbnailUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.miniArt),
                    child: Image.network(card.thumbnailUrl!, width: 60, height: 84, fit: BoxFit.cover),
                  )
                : const ArtPlaceholder(width: 60, height: 84, radius: AppRadii.miniArt),
            const SizedBox(height: 6),
            Text(
              card.name,
              style: AppType.caption.copyWith(color: AppColors.text1, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text('#${card.localId}', style: AppType.caption),
          ],
        ),
      ),
    );
  }
}
