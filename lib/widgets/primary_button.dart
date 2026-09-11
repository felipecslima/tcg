import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'loaders/miudo_loader.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.listRow),
          boxShadow: enabled ? AppShadows.primaryButton : null,
        ),
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadii.listRow),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppRadii.listRow),
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: Center(child: _buildContent()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!loading) return Text(label, style: AppType.buttonPrimary);
    if (loadingLabel != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiudoLoader(size: 20),
          const SizedBox(width: 10),
          Text(loadingLabel!, style: AppType.buttonPrimary),
        ],
      );
    }
    return const MiudoLoader(size: 20);
  }
}

/// Botão secundário: contorno lilás, texto claro.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.border2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
      ),
      child: Text(label, style: AppType.button),
    );
  }
}
