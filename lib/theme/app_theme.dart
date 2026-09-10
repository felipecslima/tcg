import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Raios de borda — Pokédex TCG Design System (`design_system/tokens/radius.css`).
/// 6 mini-thumb · 10 arte em grade · 13 chips/rádios · 16 botões/linhas ·
/// 20 cards · 26 tab bar/sheet · 99 pílulas.
abstract final class AppRadii {
  static const xs = 6.0; // mini arte de carta
  static const sm = 10.0; // arte em grade
  static const md = 13.0; // chips, rádios
  static const lg = 16.0; // botões, linhas de lista
  static const xl = 20.0; // cards
  static const xxl = 26.0; // tab bar, sheet
  static const pill = 99.0;

  // Aliases históricos.
  static const miniArt = xs;
  static const gridArt = sm;
  static const chip = md;
  static const listRow = lg;
  static const card = xl;
  static const tabBar = xxl;
  static const sheet = xxl;
}

/// Sombras — Pokédex TCG Design System (`design_system/tokens/shadows.css`).
/// Reservadas ao que flutua de verdade: arte de carta, bottom sheet, botão de
/// ação. Difusas e arroxeadas — nunca preto puro. Cards não têm sombra.
abstract final class AppShadows {
  static const raised = [
    BoxShadow(color: AppColors.shadowRaised, blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const card = [
    BoxShadow(color: AppColors.shadowCard, blurRadius: 34, offset: Offset(0, 14)),
  ];
  static const hero = [
    BoxShadow(color: AppColors.shadowHero, blurRadius: 50, offset: Offset(0, 22)),
  ];
  static const sheet = [
    BoxShadow(color: AppColors.shadowSheet, blurRadius: 60, offset: Offset(0, -20)),
  ];
  static const action = [
    BoxShadow(color: AppColors.shadowAction, blurRadius: 30, offset: Offset(0, 10)),
  ];

  // Aliases históricos.
  static const primaryButton = action;
  static const toast = hero;
  static const cardLarge = hero;
}

abstract final class AppTheme {
  /// Gutter 22 · topo 66 (status bar) · rodapé 120 (folga da tab bar flutuante).
  static const screenPadding = EdgeInsets.fromLTRB(22, 66, 22, 120);

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.gold,
        onSecondary: AppColors.surface,
        secondaryContainer: AppColors.tint,
        onSecondaryContainer: AppColors.purple900,
        surface: AppColors.surface,
        onSurface: AppColors.text1,
        surfaceContainerHighest: AppColors.surfaceSunken,
        outline: AppColors.border2,
        outlineVariant: AppColors.border1,
        error: AppColors.red,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text2,
        displayColor: AppColors.text1,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border1,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text1,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: AppType.scanTitle,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: const BorderSide(color: AppColors.border1),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.text4,
        textColor: AppColors.text1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppType.body.copyWith(color: AppColors.text4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _inputBorder(AppColors.border2),
        enabledBorder: _inputBorder(AppColors.border2),
        focusedBorder: _inputBorder(AppColors.primary),
        errorBorder: _inputBorder(AppColors.red),
        focusedErrorBorder: _inputBorder(AppColors.red),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.purple800,
        contentTextStyle: AppType.bodySm.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        borderSide: BorderSide(color: color),
      );
}
