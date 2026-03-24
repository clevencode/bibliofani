import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Mobile-first & grelha 8pt — guia de utilização
// ---------------------------------------------------------------------------
//
// **Mobile-first**
// - Desenhar e testar primeiro em ~360–390 pt de largura; só depois tablet /
//   paisagem ([AppLayoutBreakpoints]).
// - [mobileLayoutScale] parte do **telemóvel típico** (~360–390 pt); só depois
//   amplia em tablet. Referência 390 pt no menor lado, sem encolher demais o alvo de toque.
//
// **Android — estrutura de conteúdo (Material / guia mobile)**
// - Margens laterais compactas ~16 dp nas bordas do corpo; ampliar em ecrãs
//   maiores — ver [margens de conteúdo](https://developer.android.com/design/ui/mobile/guides/layout-and-content/content-structure?hl=pt-br).
// - Contenção explícita (cartões) + espaço em branco para agrupar; alinhar
//   blocos à mesma grelha; respeitar encartes da barra de sistema (SafeArea).
//
// **Grelha 8 pt**
// - Espaçamento estrutural: sempre [g] com **n inteiro** → n × 8 pt × escala.
// - Exceção pontual: [gHalf] = 4 pt × escala (metade do passo), p.ex. entre
//   linhas de texto ou separadores finos — nunca como margem principal.
// - Raios: [AppRadii] (8, 16, 24, 32…) × [layoutScale] onde aplicável.
// - Tipografia: [AppTypeScale] em múltiplos de **4 pt** (subgrelha da 8 pt).
//
// ---------------------------------------------------------------------------

/// Tokens de espaçamento e helpers alinhados à **grelha 8pt** (mobile-first).
abstract final class AppSpacing {
  static const double grid = 8;
  static const double halfGrid = 4;

  // --- Espaçamento em pt (antes de aplicar [mobileLayoutScale]) ---

  static const double s2 = 16;
  static const double s3 = 24;
  static const double s4 = 32;

  /// Alvo mínimo de toque (Material Design).
  static const double minTouchTarget = 48;

  /// Larguras máximas de painel (múltiplos de 8) — pensadas primeiro para telemóvel.
  static const double panelWidthCompact = 280;
  /// Alvo máximo em **retrato telefone** (~largura útil; não assumir ecrã desktop).
  static const double panelWidthPhone = 384;
  static const double panelWidthTablet = 456;

  /// Referência de layout mobile-first (menor lado típico de um telemóvel).
  static const double layoutReferenceShortestSidePt = 390;

  /// Escala pelo menor lado: 1,0 ≈ telemóvel de referência; tablet cresce pouco.
  static double mobileLayoutScale(double shortestSide) =>
      (shortestSide / layoutReferenceShortestSidePt).clamp(0.9, 1.1).toDouble();

  /// `n` × 8pt × escala — use **n inteiro** para manter a grelha.
  static double g(int n, double layoutScale) => n * grid * layoutScale;

  /// Meio passo da grelha × escala (só quando necessário).
  static double gHalf(double layoutScale) => halfGrid * layoutScale;

  /// Insets simétricos em múltiplos de 8pt.
  static EdgeInsets insetSymmetric({
    required double layoutScale,
    int horizontal = 0,
    int vertical = 0,
  }) =>
      EdgeInsets.symmetric(
        horizontal: g(horizontal, layoutScale),
        vertical: g(vertical, layoutScale),
      );

  // --- Passos da grelha (apenas inteiros n em [g]) para margens reutilizadas ---

  /// Margens laterais do conteúdo / scroll (header, cartão).
  static int marginContentHorizontalSteps({required bool narrow}) =>
      narrow ? 2 : 3;

  /// Padding horizontal interno do cartão do player.
  static int marginPanelInnerHorizontalSteps({required bool narrow}) =>
      narrow ? 2 : 3;

  /// Margens laterais da barra **live + play** — alinhadas à mesma base que o
  /// corpo (~16 dp em telas estreitas, 24 dp em mais largas), p. ex. ações
  /// principais dentro das margens do conteúdo.
  static int marginTransportHorizontalSteps({required bool narrow}) =>
      narrow ? 2 : 3;

  /// Espaço entre a barra de transporte e o fundo seguro (acima do home indicator).
  static const int transportBottomMarginSteps = 2;

  /// Respiro vertical padrão entre secções (header, scroll).
  static const int sectionVerticalPaddingSteps = 2;

  /// Passos de altura livre entre botões da barra e o cartão ([postButtonGap]).
  static int transportStackGapSteps({required bool compactHeight}) =>
      compactHeight ? 2 : 3;

  /// Diâmetro play / altura da pílula live em **passos da grelha** (mobile-first).
  ///
  /// Base = retrato em telemóvel típico (~11 → 88 pt em escala 1); ecrãs estreitos
  /// ou baixos reduzem um passo; tablet ou paisagem larga aumentam.
  static int playControlDiameterSteps({
    required double layoutWidth,
    required double layoutHeight,
  }) {
    final narrow = AppLayoutBreakpoints.isNarrow(layoutWidth);
    final compactH = AppLayoutBreakpoints.isCompactHeight(layoutHeight);
    final tablet = AppLayoutBreakpoints.isTablet(layoutWidth);
    final landscape =
        AppLayoutBreakpoints.isLandscape(layoutWidth, layoutHeight);

    var steps = 11;
    if (tablet) {
      steps = 13;
    } else if (landscape && !narrow) {
      steps = 12;
    }
    if (narrow) steps -= 1;
    if (compactH) steps -= 1;

    return steps.clamp(
      playControlDiameterMinSteps,
      playControlDiameterMaxSteps,
    );
  }

  /// Largura do cartão na área com margens; fração menor que 1 dá respiro
  /// óptico em retrato telefone (mobile-first).
  static double clampCardContentWidth({
    required double contentWidth,
    required double panelCap,
    double contentWidthFraction = 1.0,
  }) {
    if (contentWidth <= 0) return 0;
    final eff = contentWidth * contentWidthFraction.clamp(0.86, 1.0);
    return math.min(eff, panelCap);
  }

  static const int playControlDiameterMinSteps = 9;
  static const int playControlDiameterMaxSteps = 14;

  /// Largura mínima da pílula **live** (× 8pt × escala).
  static int livePillMinWidthSteps({required bool narrow}) =>
      narrow ? 17 : 15;

  /// Título de marca: escala com a largura até ~430 pt (mobile-first), depois estabiliza.
  static double responsiveBrandTitleFontSize(double width, double layoutScale) {
    final baseW = math.min(width, 430);
    final raw = baseW * 0.076 * layoutScale;
    return raw.clamp(g(3, layoutScale), g(4, layoutScale));
  }

  /// Contador digital: escala com a **largura do cartão** (não a do ecrã inteiro).
  /// Em ecrã estreito limita o máximo a 5 passos para menos "zona morta".
  static double responsiveTimerValueFontSize(
    double width,
    double layoutScale, {
    bool narrow = false,
  }) {
    final baseW = math.min(width, 400);
    final raw = baseW * 0.112 * layoutScale;
    final maxStep = narrow ? 5 : 6;
    return raw.clamp(g(3, layoutScale), g(maxStep, layoutScale));
  }
}

/// Breakpoints mobile-first: valores base para telemóvel, depois sobreposições.
abstract final class AppLayoutBreakpoints {
  /// Largura base (mobile portrait típico).
  static const double mobile = 360;

  /// A partir daqui: tablet / modo paisagem.
  static const double tablet = 600;

  /// Margem lateral: mobile estreito (< 360).
  static const double narrowWidth = 360;

  /// Altura compacta: mobile curto.
  static const double compactHeight = 720;

  static bool isNarrow(double width) => width < narrowWidth;
  static bool isCompactHeight(double height) => height < compactHeight;
  static bool isTablet(double width) => width >= tablet;
  static bool isLandscape(double width, double height) => width > height;

  /// Largura máxima do cartão (largura **total** da janela útil): telemóvel primeiro.
  static double maxPanelWidth(double width, double height, double scale) {
    if (isLandscape(width, height)) {
      return math.min(width * 0.74, AppSpacing.panelWidthTablet);
    }
    if (isTablet(width)) {
      return math.min(AppSpacing.panelWidthTablet, width * 0.88);
    }
    return math.min(
      AppSpacing.panelWidthPhone * scale,
      width,
    );
  }

  /// Cantos do cartão principal — alinhado a contentores M3 (~16 pt lógicos).
  static const double playerCardCornerPt = 16;
}

/// Raios de canto alinhados à grelha 8pt.
abstract final class AppRadii {
  static const double sm = 16;
  static const double md = 24;
  static const double pill = 999;

  static BorderRadius borderRadius(double radius, double layoutScale) =>
      BorderRadius.circular(radius * layoutScale);
}

/// Escala de tipo (múltiplos de **4 pt** × [layoutScale] no uso típico).
abstract final class AppTypeScale {
  static const double label = 12;
  static const double body = 14;
  static const double title = 16;
}
