import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/eevee_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'auth/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final AnimationController _rippleCtrl;
  late final AnimationController _fadeInCtrl;
  Timer? _autoNav;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _fadeInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _autoNav = Timer(const Duration(milliseconds: 2600), _navigate);
  }

  @override
  void dispose() {
    _autoNav?.cancel();
    _glowCtrl.dispose();
    _rippleCtrl.dispose();
    _fadeInCtrl.dispose();
    super.dispose();
  }

  void _navigate() {
    if (!mounted || _navigated) return;
    _navigated = true;
    _glowCtrl.stop();
    _rippleCtrl.stop();
    _fadeInCtrl.stop();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _autoNav?.cancel();
        _navigate();
      },
      child: Scaffold(
        backgroundColor: AppColors.purple900,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Arte de fundo — Tie com as eeveelutions
            Image.asset(
              'assets/splash/splash_art.jpeg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            // Gradiente escuro na parte inferior para legibilidade
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      AppColors.purple900.withValues(alpha: 0.6),
                      AppColors.purple900.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.45, 0.72, 1.0],
                  ),
                ),
              ),
            ),
            // Logo + texto na parte inferior
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _fadeInCtrl,
                    curve: Curves.easeOut,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 20),
                        Text(
                          'TieDex',
                          style: AppType.screenTitle.copyWith(
                            fontSize: 34,
                            color: Colors.white,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Para treinadores pokemon',
                          style: AppType.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    const circleSize = 100.0;
    const imageSize = 68.0;

    return SizedBox(
      width: circleSize * 1.6,
      height: circleSize * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _rippleCtrl,
            builder: (context, _) {
              final scale = 0.7 + _rippleCtrl.value * 1.0;
              final opacity = (0.4 * (1 - _rippleCtrl.value)).clamp(0.0, 1.0);
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (context, child) {
              final glowOpacity = 0.2 + 0.3 * _glowCtrl.value;
              return Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple300.withValues(alpha: glowOpacity),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Center(
                child: Image.asset(
                  EeveeAssets.path(EeveeAssets.brand),
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
