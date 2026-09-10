import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/batch_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

class BatchTray extends StatelessWidget {
  const BatchTray({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BatchSession>();
    if (session.isEmpty) return const SizedBox.shrink();

    final lastThree = session.entries.reversed.take(3).toList();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.purple800,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppShadows.action,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniStack(entries: lastThree),
            const SizedBox(width: 10),
            Text(
              '${session.count} ${session.count == 1 ? 'carta' : 'cartas'}',
              style: AppType.button.copyWith(color: Colors.white),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text('Revisar', style: AppType.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStack extends StatelessWidget {
  const _MiniStack({required this.entries});

  final List<BatchEntry> entries;

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    const overlap = 8.0;
    final width = size + (entries.length - 1) * (size - overlap);

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < entries.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.miniArt),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.miniArt - 1),
                  child: entries[i].card.thumbnailUrl != null
                      ? Image.network(entries[i].card.thumbnailUrl!, fit: BoxFit.cover)
                      : Container(color: AppColors.purple600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
