import 'package:flutter/material.dart';

import '../../constants/eevee_assets.dart';
import '../../theme/app_colors.dart';

class MedalhaoLoader extends StatefulWidget {
  const MedalhaoLoader({super.key, this.size = 112});

  final double size;

  @override
  State<MedalhaoLoader> createState() => _MedalhaoLoaderState();
}

class _MedalhaoLoaderState extends State<MedalhaoLoader>
    with TickerProviderStateMixin {
  late final AnimationController _cycleCtrl;
  late final AnimationController _rippleCtrl;

  @override
  void initState() {
    super.initState();
    _cycleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _cycleCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.asset(
          EeveeAssets.path(EeveeAssets.brand),
          fit: BoxFit.contain,
        ),
      );
    }

    final s = widget.size;
    return SizedBox(
      width: s * 1.7,
      height: s * 1.7,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _rippleCtrl,
            builder: (context, _) {
              final scale = 0.7 + _rippleCtrl.value * 1.0;
              final opacity = (0.45 * (1 - _rippleCtrl.value)).clamp(0.0, 1.0);
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.purple400,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: s,
            height: s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: _CyclingImage(
              controller: _cycleCtrl,
              size: s * 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _CyclingImage extends StatelessWidget {
  const _CyclingImage({required this.controller, required this.size});

  final AnimationController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    const names = EeveeAssets.all;
    final n = names.length;
    final slice = 1.0 / n;

    return Stack(
      alignment: Alignment.center,
      children: List.generate(n, (i) {
        final start = i * slice;
        final end = (start + slice).clamp(0.0, 1.0);

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final t = controller.value;
            final inSlice = t >= start && t < end;
            return Opacity(
              opacity: inSlice ? 1.0 : 0.0,
              child: inSlice
                  ? Transform.scale(
                      scale: 0.86 + 0.14 * _fadeInCurve(t, start, end),
                      child: child,
                    )
                  : const SizedBox.shrink(),
            );
          },
          child: Image.asset(
            EeveeAssets.path(names[i]),
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        );
      }),
    );
  }

  double _fadeInCurve(double t, double start, double end) {
    final local = (t - start) / (end - start);
    if (local < 0.15) return local / 0.15;
    if (local > 0.85) return 1.0 - ((local - 0.85) / 0.15);
    return 1.0;
  }
}
