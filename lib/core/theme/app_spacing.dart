import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Mobile-first & grelha 8pt — guia de utilização
// ---------------------------------------------------------------------------
//
// **Mobile-first**
// - Desenhar e testar primeiro em ~360–390 pt de largura; só depois tablet /
//   paisagem ([AppLayoutBreakpoints]).
// - [mobileLayoutScale] uniformiza margens e tipografia em função do menor
//   lado do ecrã (referência 390 pt), mantendo múltiplos de 8 pt lógicos.
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

  /// Larguras máximas de painel (múltiplos de 8).
  static const double panelWidthCompact = 280;
  static const double panelWidthPhone = 440;
  static const double panelWidthTablet = 456;

  /// Escala pelo menor lado do ecrã (referência ~390pt largura típica).
  static double mobileLayoutScale(double shortestSide) =>
      (shortestSide / 390).clamp(0.84, 1.12).toDouble();

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

  /// Margens laterais da barra **live + play** (mais próximas da borda).
  static int marginTransportHorizontalSteps({required bool narrow}) =>
      narrow ? 1 : 2;

  /// Espaço entre a barra de transporte e o fundo seguro (acima do home indicator).
  static const int transportBottomMarginSteps = 2;

  /// Respiro vertical padrão entre secções (header, scroll).
  static const int sectionVerticalPaddingSteps = 2;

  /// Passos de altura livre entre botões da barra e o cartão ([postButtonGap]).
  static int transportStackGapSteps({required bool compactHeight}) =>
      compactHeight ? 2 : 3;

  /// Tamanho base do botão play/live em passos (altura/diâmetro).
  static int playControlDiameterSteps({
    required bool narrow,
    required bool compactHeight,
  }) {
    if (narrow) return 12;
    if (compactHeight) return 13;
    return 14;
  }

  static const int playControlDiameterMinSteps = 9;
  static const int playControlDiameterMaxSteps = 14;

  /// Largura mínima da pílula **live** (× 8pt × escala).
  static int livePillMinWidthSteps({required bool narrow}) =>
      narrow ? 17 : 15;

  /// Título de marca (ex. cabeçalho): fluido com a largura, limitado a
  /// **3–4 passos** da grelha (24–32 pt em escala 1).
  static double responsiveBrandTitleFontSize(double width, double layoutScale) {
    final raw = width * 0.076 * layoutScale;
    return raw.clamp(g(3, layoutScale), g(4, layoutScale));
  }

  /// Tamanho principal do contador digital: fluido, entre **3 e 6** passos.
  static double responsiveTimerValueFontSize(double width, double layoutScale) {
    final raw = width * 0.118 * layoutScale;
    return raw.clamp(g(3, layoutScale), g(6, layoutScale));
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

  /// Largura máxima do cartão: mobile-first, depois tablet.
  static double maxPanelWidth(double width, double height, double scale) {
    if (isLandscape(width, height)) return width * 0.74;
    if (isTablet(width)) return AppSpacing.panelWidthTablet;
    return AppSpacing.panelWidthPhone * scale;
  }

  /// Cantos do cartão do player (pt lógicos antes de × [layoutScale]).
  static const double playerCardCornerPt = 10;
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
