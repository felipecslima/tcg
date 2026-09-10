import 'package:flutter/material.dart';

/// Tokens de cor do design (design_handoff_pokedex_tcg/README.md § Design Tokens).
/// Tema escuro, primária lilás (Espeon), dourado só para raridade/valor.
abstract final class AppColors {
  // Fundos
  static const bgRoot = Color(0xFF0D0A14);
  static const bgScreen = Color(0xFF120E1E);
  static const bgScanTop = Color(0xFF191228);
  static const bgSheet = Color(0xFF171128);
  static const bgTabBar = Color(0xDC1C142D); // rgba(28,20,45,.86)

  // Superfícies
  static const surface1 = Color(0x08FFFFFF); // rgba(255,255,255,.03)
  static const surface2 = Color(0x06FFFFFF); // rgba(255,255,255,.025)
  static const surfaceAccent = Color(0x12C08FE8); // rgba(192,143,232,.07)
  static const surfaceAccentStrong = Color(0x2EC08FE8); // .18

  // Primária
  static const primary = Color(0xFFC08FE8);
  static const primaryHover = Color(0xFFD3A7F0);
  static const primaryDeep = Color(0xFF7A4BC4);
  static const onPrimary = Color(0xFF1A1029);

  // Texto
  static const text1 = Color(0xFFFFFFFF);
  static const text2 = Color(0xFFCDC4DD);
  static const text3 = Color(0xFFA89CBD);
  static const text4 = Color(0xFF8D81A8);
  static const text5 = Color(0xFF6F6489);
  static const text6 = Color(0xFF5C5375);
  static const textDisabled = Color(0xFF4A4260);

  // Acentos semânticos
  static const gold = Color(0xFFF0C36B); // raridade, HP, progresso parcial
  static const green = Color(0xFF8CD9A8); // valorização, alto match
  static const red = Color(0xFFE08A8A); // desvalorização

  // Bordas
  static const border1 = Color(0x1AC08FE8); // rgba(192,143,232,.1)
  static const border2 = Color(0x4DC08FE8); // .3
  static const borderFocus = primary;

  // Gradientes de placeholder de arte (trocar por Image real da carta)
  static const artGradient = LinearGradient(
    begin: Alignment(-0.7, -1),
    end: Alignment(0.7, 1),
    colors: [primaryDeep, primary, gold],
    stops: [0.0, 0.55, 1.0],
  );
}
