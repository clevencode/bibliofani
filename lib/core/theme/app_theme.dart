import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData _baseTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFFB8D8A5),
            onPrimary: Color(0xFF132011),
            secondary: Color(0xFFF1C27B),
            onSecondary: Color(0xFF2B1C09),
            error: Color(0xFFF25C54),
            onError: Color(0xFF410002),
            surface: Color(0xFF11180F),
            onSurface: Color(0xFFEFF8DE),
            surfaceContainerHighest: Color(0xFF1A2517),
            outline: Color(0xFF42523C),
            outlineVariant: Color(0xFF313D2D),
          )
        : const ColorScheme.light(
            primary: Color(0xFF7FB069),
            onPrimary: Color(0xFFFFFFFF),
            secondary: Color(0xFFFFB347),
            onSecondary: Color(0xFF3A2600),
            error: Color(0xFFF25C54),
            onError: Color(0xFFFFFFFF),
            surface: Color(0xFFF8FFE5),
            onSurface: Color(0xFF1F2A1C),
            surfaceContainerHighest: Color(0xFFEEF7D4),
            outline: Color(0xFFC7D6B3),
            outlineVariant: Color(0xFFDCE8CC),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant, width: 1.1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
}
