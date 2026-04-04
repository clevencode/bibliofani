import 'package:flutter/material.dart';
import 'package:bibleco/core/theme/app_spacing.dart';

abstract final class AppTheme {
  static const double notionControlRadius = 4;
  static const double notionBlockRadius = 6;

  static const Color _premiumDarkBg = Color(0xFF09090B);
  static const Color _premiumDarkSurfaceLowest = Color(0xFF0C0C0F);
  static const Color _premiumDarkSurfaceLow = Color(0xFF121215);
  static const Color _premiumDarkSurfaceContainer = Color(0xFF18181C);
  static const Color _premiumDarkSurfaceHigh = Color(0xFF1F1F24);
  static const Color _premiumDarkSurfaceHighest = Color(0xFF26262C);
  static const Color _premiumDarkOnSurface = Color(0xFFFAFAFA);
  static const Color _premiumDarkOnSurfaceVariant = Color(0xFF71717A);
  static const Color _premiumDarkOutline = Color(0xFF2A2A32);
  static const Color _premiumDarkOutlineVariant = Color(0xFF1F1F24);
  static const Color _premiumDarkPrimary = Color(0xFFE4E4E7);
  static const Color _premiumDarkOnPrimary = Color(0xFF09090B);
  static const Color _premiumDarkPrimaryContainer = Color(0xFF3F3F46);
  static const Color _premiumDarkOnPrimaryContainer = Color(0xFFF4F4F5);
  static const Color _premiumDarkError = Color(0xFFFCA5A5);
  static const Color _premiumDarkErrorContainer = Color(0xFF450A0A);

  static const Color _premiumLightLiveBorder = Color(0xFFD6D3CD);

  static BoxDecoration transportCapsuleDecoration({
    required Brightness brightness,
    required double radius,
  }) {
    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: transportCapsuleOutline(brightness),
        width: 1,
      ),
    );
  }

  static const double _notionCornerRadius = notionControlRadius;

  static const Color _notionInk = Color(0xFF37352F);
  static const Color _notionInkSecondary = Color(0xFF787774);
  static const Color _notionBlue = Color(0xFF2383E2);
  static const Color _notionRed = Color(0xFFEB5757);

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
    final accent = isDark ? _premiumDarkPrimary : _notionBlue;

    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surfaceTint: Colors.transparent,
      contrastLevel: isDark ? 0.0 : 0.1,
    );

    if (isDark) {
      return base.copyWith(
        surface: _premiumDarkBg,
        onSurface: _premiumDarkOnSurface,
        onSurfaceVariant: _premiumDarkOnSurfaceVariant,
        surfaceContainerLowest: _premiumDarkSurfaceLowest,
        surfaceContainerLow: _premiumDarkSurfaceLow,
        surfaceContainer: _premiumDarkSurfaceContainer,
        surfaceContainerHigh: _premiumDarkSurfaceHigh,
        surfaceContainerHighest: _premiumDarkSurfaceHighest,
        outline: _premiumDarkOutline,
        outlineVariant: _premiumDarkOutlineVariant,
        primary: _premiumDarkPrimary,
        onPrimary: _premiumDarkOnPrimary,
        primaryContainer: _premiumDarkPrimaryContainer,
        onPrimaryContainer: _premiumDarkOnPrimaryContainer,
        secondary: _premiumDarkOnSurfaceVariant,
        onSecondary: _premiumDarkBg,
        error: _premiumDarkError,
        onError: _premiumDarkOnPrimary,
        errorContainer: _premiumDarkErrorContainer,
        onErrorContainer: const Color(0xFFFFE4E6),
        inverseSurface: _premiumDarkOnSurface,
        onInverseSurface: _premiumDarkBg,
        inversePrimary: _premiumDarkOnPrimary,
        shadow: const Color(0xE6000000),
        scrim: const Color(0xD9000000),
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

    final textTheme = _textTheme(isDark, scheme);

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
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.12,
          height: 1.35,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: isDark ? 0.45 : 0.88),
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
            color: scheme.outline.withValues(alpha: isDark ? 0.35 : 0.72),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        checkmarkColor: scheme.onPrimary,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.18,
          height: 1.35,
        ),
        secondaryLabelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.12,
          height: 1.35,
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
          textStyle: TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            height: 1.25,
          ),
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
          textStyle: TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.18,
            height: 1.25,
          ),
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
          textStyle: TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.15,
            height: 1.25,
          ),
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
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.12,
          height: 1.45,
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
        textStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
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

    final titleTight = isDark ? -0.22 : -0.18;
    final bodyTrack = 0.14;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: isDark ? -0.45 : -0.35,
        height: 1.08,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: isDark ? -0.38 : -0.28,
        height: 1.1,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: isDark ? -0.32 : -0.22,
        height: 1.12,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: -0.28,
        height: 1.14,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.22,
        height: 1.18,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.18,
        height: 1.22,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: titleTight,
        height: 1.28,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.02,
        height: 1.32,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.06,
        height: 1.36,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: bodyTrack,
        height: 1.55,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: bodyTrack,
        height: 1.55,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0.12,
        height: 1.45,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.38,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0.16,
        height: 1.36,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.34,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  static ThemeData get dark => _baseTheme(Brightness.dark);

  static Color liveStreamBroadcastIconColor(Brightness brightness) =>
      Colors.white;

  static Color liveStreamButtonHover(Brightness brightness) =>
      Colors.white.withValues(alpha: 0.10);

  static Color liveStreamButtonSplash(Brightness brightness) =>
      Colors.white.withValues(alpha: 0.18);

  static Color transportLiveBorder(Brightness brightness) =>
      brightness == Brightness.light
          ? _premiumLightLiveBorder
          : const Color(0xFF3F3F48);

  static Color transportCapsuleOutline(Brightness brightness) =>
      transportLiveBorder(brightness).withValues(
        alpha: brightness == Brightness.dark ? 0.35 : 0.88,
      );
}
