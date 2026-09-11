import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/eevee_assets.dart';

class RodaLoader extends StatefulWidget {
  const RodaLoader({super.key, this.size = 200});

  final double size;

  @override
  State<RodaLoader> createState() => _RodaLoaderState();
}

class _RodaLoaderState extends State<RodaLoader>
    with TickerProviderStateMixin {
  late final AnimationController _orbitCtrl;
  late final AnimationController _swayCtrl;
  late final AnimationController _glowCtrl;

  static const _orbiters = [
    'espeon', 'umbreon', 'vaporeon', 'jolteon',
    'flareon', 'leafeon', 'glaceon', 'sylveon',
  ];

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _swayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _swayCtrl.dispose();
    _glowCtrl.dispose();
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
          EeveeAssets.path('eevee'),
          fit: BoxFit.contain,
        ),
      );
    }

    final s = widget.size;
    final orbitRadius = s * 0.38;
    final childSize = s * 0.18;
    final centerSize = s * 0.28;

    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _orbitCtrl,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Eevee central com sway
              AnimatedBuilder(
                animation: _swayCtrl,
                builder: (context, child) {
                  final angle = (-5 + 10 * _swayCtrl.value) * math.pi / 180;
                  return Transform.rotate(angle: angle, child: child);
                },
                child: Image.asset(
                  EeveeAssets.path('eevee'),
                  width: centerSize,
                  height: centerSize,
                  fit: BoxFit.contain,
                ),
              ),
              // 8 orbitando
              for (int i = 0; i < _orbiters.length; i++)
                _buildOrbiter(i, orbitRadius, childSize),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrbiter(int i, double radius, double childSize) {
    final baseAngle = (2 * math.pi / _orbiters.length) * i;
    final angle = baseAngle + _orbitCtrl.value * 2 * math.pi;
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;

    final glowSlice = 1.0 / _orbiters.length;
    final glowStart = i * glowSlice;
    final glowT = _glowCtrl.value;
    final inGlow = glowT >= glowStart && glowT < glowStart + glowSlice * 0.5;
    final glowOpacity = inGlow ? 1.0 : 0.6;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: -angle,
        child: Opacity(
          opacity: glowOpacity,
          child: Image.asset(
            EeveeAssets.path(_orbiters[i]),
            width: childSize,
            height: childSize,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
