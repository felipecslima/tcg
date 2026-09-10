import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Chip-pílula com 3 estados (normal / selecionado / hover implícito).
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surfaceAccentStrong : AppColors.surface1,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border1,
            ),
          ),
          child: Text(
            label,
            style: AppType.button.copyWith(
              color: selected ? AppColors.text1 : AppColors.text3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de progresso do design: trilho translúcido, preenchimento em gradiente.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 7});

  final double value; // 0..1
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Stack(
        children: [
          Container(height: height, color: AppColors.tint),
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            child: Container(
              height: height,
              decoration: const BoxDecoration(gradient: AppColors.gradProgress),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder de arte de carta (proporção 63×88). Trocar por Image real.
class ArtPlaceholder extends StatelessWidget {
  const ArtPlaceholder({
    super.key,
    this.width,
    this.height,
    this.radius = AppRadii.gridArt,
    this.missing = false,
  });

  final double? width;
  final double? height;
  final double radius;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          border: Border.all(
            color: missing ? AppColors.border2 : AppColors.border1,
          ),
        ),
        child: CustomPaint(
          painter: _StripePainter(strong: missing),
          child: missing
              ? const Center(
                  child: Text('?',
                      style: TextStyle(
                          color: AppColors.textDisabled, fontSize: 22)))
              : null,
        ),
      ),
    );
  }
}

/// Listrado a 115° — "aqui entra uma imagem que ainda não existe"
/// (`design_system` § Fundos). Nunca usar como decoração.
class _StripePainter extends CustomPainter {
  const _StripePainter({this.strong = false});
  final bool strong;

  @override
  void paint(Canvas canvas, Size size) {
    final band = strong ? 6.0 : 9.0;
    final paint = Paint()
      ..color = strong ? const Color(0x477A4BC4) : AppColors.stripe
      ..strokeWidth = band;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // 115° ≈ inclinação para a esquerda; varre além das bordas.
    const dx = 0.466; // tan(115°-90°)
    final span = size.width + size.height;
    for (double x = -size.height * dx - span; x < span; x += band * 2) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * dx, size.height),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.strong != strong;
}

/// Pílula de raridade / valor (dourada).
class RarityPill extends StatelessWidget {
  const RarityPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.goldSurface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppType.sectionLabel.copyWith(color: AppColors.gold),
      ),
    );
  }
}

/// Stepper de quantidade (1–99).
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppType.mono.copyWith(fontSize: 18, color: AppColors.text1),
          ),
        ),
        _btn(Icons.add, value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) => Material(
        color: AppColors.surfaceAccent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon,
                size: 16,
                color: onTap == null ? AppColors.text6 : AppColors.text1),
          ),
        ),
      );
}
