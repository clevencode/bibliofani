import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meu_app/core/theme/app_spacing.dart';

/// Tema **claro e escuro** inspirado no **Notion**: texto «#37352F», páginas
/// quentes claras, azul de link, cantos subtis, bordas em vez de sombras.
/// Tipografia **Inter** (a app Notion usa equivalente).
///
/// [AppSpacing] mantém a grelha 8pt.
abstract final class AppTheme {
  /// Transição claro ↔ escuro: um pouco mais longa, curva tipo Material 3.
  static const Duration themeCrossfadeDuration = Duration(milliseconds: 420);
  static const Curve themeCrossfadeCurve = Curves.easeInOutCubicEmphasized;

  /// Cantos de controlos (botões, campos).
  static const double notionControlRadius = 4;

  /// Cantos de blocos / cartões (alinhado à UI Notion).
  static const double notionBlockRadius = 6;

  static const double _notionCornerRadius = notionControlRadius;

  // Paleta Notion (aproximação dos valores públicos da UI).
  static const Color _notionInk = Color(0xFF37352F);
  static const Color _notionInkSecondary = Color(0xFF787774);
  static const Color _notionBlue = Color(0xFF2383E2);
  static const Color _notionBlueDark = Color(0xFF529CCA);
  static const Color _notionRed = Color(0xFFEB5757);

  /// Fundo **opaco** da notificação MediaStyle no Android (recomendado pelo
  /// `audio_service`: contraste com ícone branco monocromático e barra de acções).
  static const Color mediaNotificationBackground = Color(0xFF1565A0);

  /// Fundo principal da app em modo escuro (corpo / scaffold).
  static const Color darkAppBackground = Color(0xFF171717);

  /// Fundo claro: cinzento quente tipo sidebar + página (sem gradiente forte).
  static const LinearGradient notionLightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.55, 1.0],
    colors: [
      Color(0xFFF7F6F3),
      Color(0xFFFBFBFA),
      Color(0xFFFFFFFF),
    ],
  );

  static ColorScheme _notionColorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final accent = isDark ? _notionBlueDark : _notionBlue;

    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surfaceTint: Colors.transparent,
      contrastLevel: isDark ? 0.06 : 0.1,
    );

    if (isDark) {
      return base.copyWith(
        surface: darkAppBackground,
        onSurface: const Color(0xFFE6E6E4),
        onSurfaceVariant: const Color(0xFF9B9B9B),
        surfaceContainerLowest: const Color(0xFF121212),
        surfaceContainerLow: const Color(0xFF1C1C1C),
        surfaceContainer: const Color(0xFF242424),
        surfaceContainerHigh: const Color(0xFF2A2A2A),
        surfaceContainerHighest: const Color(0xFF303030),
        outline: const Color(0xFF373737),
        outlineVariant: const Color(0xFF2C2C2C),
        primary: _notionBlueDark,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF1E3A4C),
        onPrimaryContainer: const Color(0xFFC2E5FF),
        secondary: const Color(0xFF9B9B9B),
        onSecondary: darkAppBackground,
        error: const Color(0xFFFF8B7B),
        onError: const Color(0xFF370000),
        errorContainer: const Color(0xFF6B2A2A),
        onErrorContainer: const Color(0xFFFFDAD4),
        inverseSurface: const Color(0xFFFBFBFA),
        onInverseSurface: _notionInk,
        inversePrimary: _notionBlue,
        shadow: Colors.black,
        scrim: const Color(0xCC000000),
      );
    }

    return base.copyWith(
      surface: const Color(0xFFF7F6F3),
      onSurface: _notionInk,
      onSurfaceVariant: _notionInkSecondary,
      surfaceContainerLowest: const Color(0xFFF1F0ED),
      surfaceContainerLow: const Color(0xFFF3F2EF),
      surfaceContainer: const Color(0xFFFBFBFA),
      surfaceContainerHigh: const Color(0xFFFFFFFF),
      surfaceContainerHighest: const Color(0xFFFFFFFF),
      outline: const Color(0xFFE3E2E0),
      outlineVariant: const Color(0xFFECECEA),
      primary: _notionBlue,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE7F3FF),
      onPrimaryContainer: const Color(0xFF0B4F8F),
      secondary: _notionInkSecondary,
      onSecondary: Colors.white,
      error: _notionRed,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFE4E2),
      onErrorContainer: const Color(0xFF5C1A16),
      inverseSurface: _notionInk,
      onInverseSurface: const Color(0xFFFBFBFA),
      inversePrimary: const Color(0xFF7EC0FF),
      shadow: _notionInk,
      scrim: const Color(0x8037352F),
    );
  }

  static ThemeData _baseTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _notionColorScheme(brightness);
    final minimumTap =
        const Size(kMinInteractiveDimension, kMinInteractiveDimension);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_notionCornerRadius),
    );

    final rawTextTheme = _textTheme(isDark, scheme);
    final textTheme = GoogleFonts.interTextTheme(rawTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      applyElevationOverlayColor: !isDark,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: isDark ? 0.72 : 0.88),
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(notionBlockRadius),
          side: BorderSide(
            color: scheme.outline.withValues(alpha: isDark ? 0.58 : 0.72),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        checkmarkColor: scheme.onPrimary,
        labelStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          color: scheme.onSurfaceVariant,
        ),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s2,
          ),
          minimumSize: minimumTap,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: minimumTap,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s2,
          ),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.82)),
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          minimumSize: minimumTap,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.s2,
            vertical: AppSpacing.s2,
          ),
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: minimumTap,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: Color.lerp(
          isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
          scheme.outline,
          isDark ? 0.22 : 0.18,
        )!,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: GoogleFonts.inter(
          color: scheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: scheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(notionBlockRadius),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 480),
        showDuration: const Duration(seconds: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        textStyle: GoogleFonts.inter(
          color: scheme.onInverseSurface,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(notionControlRadius),
          border: Border.all(
            color: scheme.onInverseSurface.withValues(alpha: 0.14),
          ),
        ),
      ),
      textTheme: textTheme,
    );
  }

  static TextTheme _textTheme(bool isDark, ColorScheme scheme) {
    final base = (isDark
            ? Typography.material2021().white
            : Typography.material2021().black)
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    var themed = base.copyWith(
      bodySmall: base.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.4,
      ),
      labelSmall: base.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.35,
      ),
      labelMedium: base.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
    );
    themed = themed.copyWith(
      titleLarge: themed.titleLarge?.copyWith(
        height: 1.22,
        fontWeight: FontWeight.w600,
        letterSpacing: isDark ? -0.18 : -0.2,
      ),
      titleMedium: themed.titleMedium?.copyWith(height: 1.3),
      titleSmall: themed.titleSmall?.copyWith(
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: themed.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: themed.bodyMedium?.copyWith(height: 1.5),
    );
    return themed;
  }

  static ThemeData get light => _baseTheme(Brightness.light);

  static ThemeData get dark => _baseTheme(Brightness.dark);

  /// Play: só preto/branco (tinta em claro, branco em escuro — como botões neutros Notion).
  static Color transportPlayFill(Brightness brightness) =>
      brightness == Brightness.light ? _notionInk : Colors.white;

  static Color transportPlayIcon(Brightness brightness) =>
      brightness == Brightness.light ? Colors.white : _notionInk;

  static Color transportLiveIcon(Brightness brightness) =>
      brightness == Brightness.light ? _notionInk : const Color(0xFFE6E6E4);

  /// Traço fino tipo callout Notion sobre fundo claro (#E3E2E0) / contorno painel escuro.
  static Color transportLiveBorder(Brightness brightness) =>
      brightness == Brightness.light
          ? const Color(0xFFE3E2E0)
          : const Color(0xFF4A4A4A);

  /// Círculo do indicador de pulso em **en direct** (a reproduzir).
  static Color transportLivePulseColor(Brightness brightness) =>
      brightness == Brightness.light
          ? const Color(0xFF0F7B6C)
          : const Color(0xFF4DAB9A);

  /// Tom **âmbar / amarelo** suave (pílula de estado, indicador «en écoute»).
  static Color transportDeferredPulseColor(Brightness brightness) =>
      brightness == Brightness.light
          ? const Color(0xFFC2760A)
          : const Color(0xFFE8C547);

  /// Vermelho Notion suave para **En pause** (indicador + pílula), alinhado a [_notionRed] / erro.
  static Color transportPausedPulseColor(Brightness brightness) =>
      brightness == Brightness.light
          ? _notionRed
          : const Color(0xFFFF8B7B);

  /// Fundo da pílula «En direct / Différé / En pause»: lavado suave com a mesma família cromática do círculo.
  /// [neutralPause]: «En pause» voluntário — cinza neutro (sem tom de erro).
  static Color statusPillBackground({
    required ColorScheme scheme,
    required Brightness brightness,
    required bool isListening,
    required bool isLiveMode,
    bool neutralPause = false,
  }) {
    final isDark = brightness == Brightness.dark;
    if (!isListening) {
      if (neutralPause) {
        return Color.lerp(
          scheme.surfaceContainerLow,
          scheme.outline,
          isDark ? 0.22 : 0.14,
        )!;
      }
      return Color.lerp(
        scheme.surfaceContainerLow,
        transportPausedPulseColor(brightness),
        isDark ? 0.28 : 0.11,
      )!;
    }
    if (isLiveMode) {
      return Color.lerp(
        scheme.surfaceContainerHighest,
        transportLivePulseColor(brightness),
        isDark ? 0.24 : 0.11,
      )!;
    }
    return Color.lerp(
      scheme.surfaceContainerHighest,
      transportDeferredPulseColor(brightness),
      isDark ? 0.26 : 0.12,
    )!;
  }

  /// Borda da pílula de estado: eco do verde (live), âmbar (écoute) ou vermelho (pause).
  static Color statusPillBorder({
    required ColorScheme scheme,
    required Brightness brightness,
    required bool isListening,
    required bool isLiveMode,
    bool neutralPause = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final edge = scheme.outline.withValues(alpha: isDark ? 0.75 : 0.88);
    if (!isListening) {
      if (neutralPause) {
        return scheme.outline.withValues(alpha: isDark ? 0.52 : 0.58);
      }
      return Color.lerp(edge, transportPausedPulseColor(brightness), 0.42)!;
    }
    if (isLiveMode) {
      return Color.lerp(edge, transportLivePulseColor(brightness), 0.42)!;
    }
    return Color.lerp(edge, transportDeferredPulseColor(brightness), 0.40)!;
  }

  static Color footerSurfaceColor(ColorScheme scheme) =>
      Color.lerp(scheme.surface, scheme.surfaceContainerLowest, 0.72)!;

  static Color darkHoverOverlay(ColorScheme scheme) =>
      footerSurfaceColor(scheme).withValues(alpha: 0.22);
}
