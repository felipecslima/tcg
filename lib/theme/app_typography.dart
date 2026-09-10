import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Escala tipográfica do design.
/// - Sora: display / títulos
/// - DM Sans: corpo / UI
/// - DM Mono: números, preços, rótulos de seção
abstract final class AppType {
  static TextStyle get screenTitle => GoogleFonts.sora(
        fontSize: 30,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.text1,
      );

  static TextStyle get scanTitle => GoogleFonts.sora(
        fontSize: 24,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: AppColors.text1,
      );

  static TextStyle get cardTitle => GoogleFonts.sora(
        fontSize: 26,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: AppColors.text1,
      );

  static TextStyle get listTitle => GoogleFonts.sora(
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.text1,
      );

  static TextStyle get heroValue => GoogleFonts.sora(
        fontSize: 36,
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: AppColors.text1,
      );

  static TextStyle get body => GoogleFonts.dmSans(
        fontSize: 15,
        height: 1.5,
        color: AppColors.text2,
      );

  static TextStyle get caption => GoogleFonts.dmSans(
        fontSize: 13,
        height: 1.4,
        color: AppColors.text4,
      );

  static TextStyle get button => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.text1,
      );

  static TextStyle get buttonPrimary => GoogleFonts.sora(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.onPrimary,
      );

  static TextStyle get sectionLabel => GoogleFonts.dmMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: AppColors.text5,
      );

  static TextStyle get mono => GoogleFonts.dmMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.text2,
      );

  static TextStyle get price => GoogleFonts.dmMono(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.text1,
      );
}
