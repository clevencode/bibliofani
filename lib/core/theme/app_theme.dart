import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';

/// Temas Material 3 alinhados à grelha **8pt** ([AppSpacing], [AppRadii]).
abstract final class AppTheme {
  /// Crossfade ao mudar claro ↔ escuro ([MaterialApp.themeAnimationDuration]).
  static const Duration themeCrossfadeDuration = Duration(milliseconds: 520);
  static const Curve themeCrossfadeCurve = Curves.easeInOutCubicEmphasized;

  static ThemeData _baseTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? ColorScheme.fromSeed(
            // Neutro (sem acento verde); hierarquia M3 de superfícies.
            seedColor: const Color(0xFF6B7280),
            brightness: Brightness.dark,
            surfaceTint: Colors.transparent,
          ).copyWith(
            surface: const Color(0xFF0F1012),
            onSurface: const Color(0xFFE8E8ED),
            onSurfaceVariant: const Color(0xFFB4B4BC),
            surfaceContainerLowest: const Color(0xFF08090A),
            surfaceContainerLow: const Color(0xFF141416),
            surfaceContainer: const Color(0xFF1A1A1E),
            surfaceContainerHigh: const Color(0xFF242428),
            surfaceContainerHighest: const Color(0xFF2E2E34),
            outline: const Color(0xFF6E6E76),
            outlineVariant: const Color(0xFF3F3F46),
            primary: const Color(0xFFD1D5DC),
            onPrimary: const Color(0xFF18181B),
            primaryContainer: const Color(0xFF3F3F46),
            onPrimaryContainer: const Color(0xFFE8E8ED),
            secondary: const Color(0xFF9CA3AF),
            onSecondary: const Color(0xFF18181B),
            error: const Color(0xFFFFB4AB),
            onError: const Color(0xFF690005),
            errorContainer: const Color(0xFF93000A),
            onErrorContainer: const Color(0xFFFFDAD6),
            shadow: Colors.black,
            scrim: const Color(0xCC000000),
          )
        : const ColorScheme.light(
            // Estética Bible FM (mockup): neutro, texto preto, acento verde floresta.
            primary: Color(0xFF1A3D2E),
            onPrimary: Color(0xFFFFFFFF),
            secondary: Color(0xFFBDBDBD),
            onSecondary: Color(0xFF111111),
            error: Color(0xFFD32F2F),
            onError: Color(0xFFFFFFFF),
            surface: Color(0xFFF5F5F5),
            onSurface: Color(0xFF111111),
            onSurfaceVariant: Color(0xFF49454F),
            surfaceContainerHighest: Color(0xFFFFFFFF),
            outline: Color(0xFFE0E0E0),
            outlineVariant: Color(0xFFEEEEEE),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? Colors.black : scheme.surface,
      applyElevationOverlayColor: !isDark,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? Colors.black : scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: isDark ? 0.28 : 0.4),
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerHighest.withValues(alpha: 0.95),
        selectedColor: scheme.primary.withValues(alpha: 0.2),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
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
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      textTheme: (isDark ? Typography.material2021().white : Typography.material2021().black).apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          ),
    );
  }

  static ThemeData get light => _baseTheme(Brightness.light);

  static ThemeData get dark => _baseTheme(Brightness.dark);

  /// Base do gradiente escuro (zona do rodapé), coerente com [surfaceContainerLowest].
  static Color footerSurfaceColor(ColorScheme scheme) =>
      Color.lerp(scheme.surface, scheme.surfaceContainerLowest, 0.72)!;

  /// Hover / splash no modo escuro: mesma família cromática do rodapé.
  static Color darkHoverOverlay(ColorScheme scheme) =>
      footerSurfaceColor(scheme).withValues(alpha: 0.22);
}
