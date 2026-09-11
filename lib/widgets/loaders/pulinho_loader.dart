import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/eevee_assets.dart';

class PulinhoLoader extends StatefulWidget {
  const PulinhoLoader({super.key, this.size = 64});

  final double size;

  @override
  State<PulinhoLoader> createState() => _PulinhoLoaderState();
}

class _PulinhoLoaderState extends State<PulinhoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _names = ['sylveon', 'eevee', 'flareon', 'umbreon'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
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

    final n = _names.length;
    final slice = 1.0 / n;

    return SizedBox(
      width: widget.size,
      height: widget.size + 22,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(n, (i) {
          final start = i * slice;
          final end = (start + slice).clamp(0.0, 1.0);

          return AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final t = _ctrl.value;
              final inSlice = t >= start && t < end;
              if (!inSlice) return const SizedBox.shrink();

              final local = (t - start) / (end - start);
              final hop = _hopCurve(local);

              return Transform.translate(
                offset: Offset(0, hop.dy),
                child: Transform.scale(
                  scaleY: hop.scaleY,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              );
            },
            child: Image.asset(
              EeveeAssets.path(_names[i]),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
            ),
          );
        }),
      ),
    );
  }

  ({double dy, double scaleY}) _hopCurve(double t) {
    if (t < 0.18) {
      final p = t / 0.18;
      return (dy: 0, scaleY: 1.0 - 0.14 * p);
    } else if (t < 0.45) {
      final p = (t - 0.18) / 0.27;
      final jump = math.sin(p * math.pi);
      return (dy: -22 * jump, scaleY: 0.86 + 0.18 * p);
    } else if (t < 0.72) {
      final p = (t - 0.45) / 0.27;
      return (dy: 0, scaleY: 1.04 - 0.12 * (1 - p));
    } else {
      return (dy: 0, scaleY: 1.0);
    }
  }
}
