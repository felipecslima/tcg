import 'package:flutter/material.dart';

/// Tokens de cor — Pokédex TCG Design System (`design_system/tokens/colors.css`).
///
/// Modo claro. Base roxo/lilás (evolução psíquica do Eevee). Superfície é branco
/// puro sobre fundo lilás claríssimo — o contraste entre os dois separa conteúdo
/// de fundo, não sombra. Roxo cheio é raro: só ação primária, aba ativa, nó de
/// trilha iniciado e no máximo um card hero por tela. Todo o resto é tinta roxa
/// translúcida. Dourado só para raridade/HP/valor; verde e vermelho só para
/// variação de preço.
abstract final class AppColors {
  // ── Escala de marca ────────────────────────────────────────────────
  static const purple900 = Color(0xFF3A1E63);
  static const purple800 = Color(0xFF5E2E9E);
  static const purple700 = Color(0xFF6B3FB0);
  static const purple600 = Color(0xFF7A4BC4);
  static const purple500 = Color(0xFF9463DA);
  static const purple400 = Color(0xFFA76FDF);
  static const purple300 = Color(0xFFB07CE8);
  static const lilac200 = Color(0xFFE4D9F4);
  static const lilac100 = Color(0xFFEFEAF6);
  static const lilac050 = Color(0xFFFBF9FD);

  // ── Papel ──────────────────────────────────────────────────────────
  static const bg = Color(0xFFFBF9FD); // fundo do app
  static const bgDeep = Color(0xFFEFEAF6); // fora do app / trás de sheets
  static const surface = Color(0xFFFFFFFF); // cards, linhas, campos
  static const surfaceSunken = Color(0xFFFAF7FD);
  static const scrim = Color(0xE1FFFFFF); // rgba(255,255,255,.88) — só tab bar

  // Aliases mantidos para telas/scanner que assumem "fundo".
  static const bgRoot = bgDeep;
  static const bgScreen = bg;
  static const bgSheet = surface;
  static const bgTabBar = scrim;
  // Chrome escuro do visor da câmera (única superfície escura do app).
  static const scanChrome = Color(0xFF191228);
  static const bgScanTop = scanChrome;

  // ── Tintas roxas translúcidas ──────────────────────────────────────
  static const tintSoft = Color(0x0F7A4BC4); // .06
  static const tint = Color(0x1F7A4BC4); // .12
  static const tintStrong = Color(0x2E7A4BC4); // .18

  // Aliases de superfície acentuada.
  static const surface1 = tintSoft;
  static const surface2 = tintSoft;
  static const surfaceAccent = tint;
  static const surfaceAccentStrong = tintStrong;

  // ── Tinta (texto e ícones) ─────────────────────────────────────────
  static const ink1 = Color(0xFF241A35);
  static const ink2 = Color(0xFF4A3F5C);
  static const ink3 = Color(0xFF645878);
  static const ink4 = Color(0xFF6E6386);

  static const text1 = ink1; // títulos, valores
  static const text2 = ink2; // corpo
  static const text3 = ink3; // secundário
  static const text4 = ink4; // muted / rótulos
  static const text5 = Color(0xFF8478A0); // aba/ícone inativo
  static const text6 = Color(0xFFA99FC0); // muito discreto
  static const textDisabled = Color(0xFFB7ADC9);
  static const textOnPurple = Color(0xFFFFFFFF);

  // ── Ação ───────────────────────────────────────────────────────────
  static const primary = purple600; // cor de ação
  static const primaryHover = purple500;
  static const primaryDeep = purple800;
  static const onPrimary = textOnPurple;

  // ── Semânticas (todas passam 4.5:1 sobre --ds-bg) ──────────────────
  static const gold = Color(0xFF8A5C10); // raridade, HP, valor
  static const goldSurface = Color(0x21A9741A); // rgba(169,116,26,.13)
  static const green = Color(0xFF1F7346); // valorização
  static const red = Color(0xFFC04A4A); // desvalorização
  static const positive = green;
  static const negative = red;

  // ── Bordas — sempre roxo translúcido, nunca cinza ──────────────────
  static const border1 = Color(0x1F7A4BC4); // .12 em repouso
  static const border2 = Color(0x387A4BC4); // .22 em interativo
  static const borderFocus = primary; // cor cheia quando selecionado

  // ── Sombras (difusas, arroxeadas — rgba(60,40,100,·)) ──────────────
  static const shadowRaised = Color(0x243C2864); // rgba(60,40,100,.14)
  static const shadowCard = Color(0x293C2864); // .16
  static const shadowHero = Color(0x333C2864); // .20
  static const shadowSheet = Color(0x333C2864); // .20
  static const shadowAction = Color(0x477A4BC4); // rgba(122,75,196,.28)

  // ── Gradientes ─────────────────────────────────────────────────────
  static const gradHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5A3199), Color(0xFF7F4FC4)],
  );
  static const gradProgress = LinearGradient(
    colors: [Color(0xFF6B3FB0), Color(0xFFA76FDF)],
  );
  static const gradNode = LinearGradient(
    begin: Alignment(-0.7, -1),
    end: Alignment(0.7, 1),
    colors: [Color(0xFF6B3FB0), Color(0xFFA76FDF)],
  );

  /// Véu roxo que desce do topo dos heros de carta/perfil.
  static const gradVeil = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x387A4BC4), bg], // rgba(122,75,196,.22) → --ds-bg
  );

  /// Placeholder de arte: substitui `artGradient` — a arte ausente é
  /// listrada, não colorida (ver [stripedPlaceholder]).
  static const artGradient = gradHero;

  /// Listrado a 115° — significa "aqui entra uma imagem que ainda não existe".
  /// Nunca usar como decoração.
  static const stripe = Color(0x177A4BC4); // rgba(122,75,196,.09)
  static const stripeGap = Color(0x087A4BC4); // rgba(122,75,196,.03)
}
