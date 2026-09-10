import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Escala tipográfica — Pokédex TCG Design System (`design_system/tokens/typography.css`).
///
/// Três famílias com papéis rígidos:
/// - **Sora** — só títulos e nomes próprios (tracking −.02em acima de 24px).
/// - **DM Sans** — todo texto corrido, legenda e botão.
/// - **DM Mono** — tudo que é dado: preço, %, numeração de carta, HP e rótulos
///   de seção em maiúsculas (tracking .14em). Um número nunca aparece em DM Sans.
abstract final class AppType {
  // ── Display — Sora ─────────────────────────────────────────────────
  static TextStyle get hero => GoogleFonts.sora(
        fontSize: 36,
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.72,
        color: AppColors.text1,
      );

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
        letterSpacing: -0.48,
        color: AppColors.text1,
      );

  static TextStyle get cardTitle => GoogleFonts.sora(
        fontSize: 25,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.text1,
      );

  static TextStyle get listTitle => GoogleFonts.sora(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.text1,
      );

  static TextStyle get listTitleLg => GoogleFonts.sora(
        fontSize: 19,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: AppColors.text1,
      );

  /// Alias histórico (hero de valor).
  static TextStyle get heroValue => hero;

  // ── Corpo — DM Sans ────────────────────────────────────────────────
  static TextStyle get body => GoogleFonts.dmSans(
        fontSize: 15,
        height: 1.5,
        color: AppColors.text2,
      );

  static TextStyle get bodySm => GoogleFonts.dmSans(
        fontSize: 14,
        height: 1.5,
        color: AppColors.text2,
      );

  static TextStyle get caption => GoogleFonts.dmSans(
        fontSize: 12,
        height: 1.4,
        color: AppColors.text4,
      );

  static TextStyle get button => GoogleFonts.dmSans(
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w600,
        color: AppColors.text2,
      );

  static TextStyle get buttonPrimary => GoogleFonts.dmSans(
        fontSize: 15,
        height: 1,
        fontWeight: FontWeight.w600,
        color: AppColors.onPrimary,
      );

  // ── Dados e rótulos — DM Mono ──────────────────────────────────────
  /// Rótulo de seção: MAIÚSCULAS, 1–2 palavras, tracking .14em.
  static TextStyle get sectionLabel => GoogleFonts.dmMono(
        fontSize: 11,
        height: 1,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.54,
        color: AppColors.text3,
      );

  static TextStyle get mono => GoogleFonts.dmMono(
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w500,
        color: AppColors.text2,
      );

  static TextStyle get price => GoogleFonts.dmMono(
        fontSize: 20,
        height: 1,
        fontWeight: FontWeight.w500,
        color: AppColors.text1,
      );
}
