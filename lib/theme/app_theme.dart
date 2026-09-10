import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Raios de borda do design (README § Raio de borda).
abstract final class AppRadii {
  static const miniArt = 6.0;
  static const gridArt = 11.0;
  static const chip = 14.0;
  static const listRow = 17.0;
  static const card = 20.0;
  static const tabBar = 26.0;
  static const sheet = 28.0;
  static const pill = 99.0;
}

/// Sombras do design (README § Sombras).
abstract final class AppShadows {
  static const primaryButton = [
    BoxShadow(color: Color(0x47C08FE8), blurRadius: 30, offset: Offset(0, 10)),
  ];
  static const toast = [
    BoxShadow(color: Color(0x59C08FE8), blurRadius: 34, offset: Offset(0, 14)),
  ];
  static const cardLarge = [
    BoxShadow(color: Color(0x99000000), blurRadius: 50, offset: Offset(0, 22)),
  ];
}

abstract final class AppTheme {
  static const screenPadding = EdgeInsets.fromLTRB(22, 66, 22, 120);

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgScreen,
      canvasColor: AppColors.bgScreen,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.gold,
        surface: AppColors.bgScreen,
        onSurface: AppColors.text1,
        error: AppColors.red,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text2,
        displayColor: AppColors.text1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgScreen,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppType.scanTitle,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x0AFFFFFF),
        hintStyle: AppType.body.copyWith(color: AppColors.text5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _inputBorder(AppColors.border1),
        enabledBorder: _inputBorder(AppColors.border1),
        focusedBorder: _inputBorder(AppColors.primary),
        errorBorder: _inputBorder(AppColors.red),
        focusedErrorBorder: _inputBorder(AppColors.red),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: TextStyle(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.listRow),
        borderSide: BorderSide(color: color),
      );
}
