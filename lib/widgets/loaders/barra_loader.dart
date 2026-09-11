import 'package:flutter/material.dart';

import '../../constants/eevee_assets.dart';
import '../../theme/app_colors.dart';

class BarraLoader extends StatefulWidget {
  const BarraLoader({
    super.key,
    this.progress = 0.0,
    this.height = 32,
  });

  final double progress;
  final double height;

  @override
  State<BarraLoader> createState() => _BarraLoaderState();
}

class _BarraLoaderState extends State<BarraLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _walkCtrl;

  static const _walkers = ['sylveon', 'eevee', 'flareon'];

  @override
  void initState() {
    super.initState();
    _walkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();
  }

  @override
  void dispose() {
    _walkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final iconSize = widget.height * 0.85;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!reduceMotion)
          SizedBox(
            height: iconSize + 4,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                return AnimatedBuilder(
                  animation: _walkCtrl,
                  builder: (context, _) {
                    final n = _walkers.length;
                    final slice = 1.0 / n;
                    return Stack(
                      children: List.generate(n, (i) {
                        final start = i * slice;
                        final end = start + slice;
                        final inSlice = _walkCtrl.value >= start &&
                            _walkCtrl.value < end;
                        if (!inSlice) return const SizedBox.shrink();
                        final local =
                            (_walkCtrl.value - start) / (end - start);
                        final x = local * (maxW - iconSize);
                        return Positioned(
                          left: x,
                          bottom: 0,
                          child: Image.asset(
                            EeveeAssets.path(_walkers[i]),
                            width: iconSize,
                            height: iconSize,
                            fit: BoxFit.contain,
                          ),
                        );
                      }),
                    );
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: widget.progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.lilac200,
              valueColor: const AlwaysStoppedAnimation(AppColors.purple500),
            ),
          ),
        ),
      ],
    );
  }
}
