import 'package:flutter/material.dart';

import 'linos_palette.dart';

class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFFD29A3C);

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final LinosPalette palette = LinosPalette.forBrightness(brightness);
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      primary: palette.accent,
      onPrimary: palette.onAccent,
      secondary: palette.inTune,
      onSecondary: isDark ? const Color(0xFF0C2318) : const Color(0xFFFAF5EA),
      tertiary: palette.sharp,
      onTertiary: isDark ? const Color(0xFF2A1505) : const Color(0xFFFAF5EA),
      surface: palette.background,
      onSurface: palette.text,
      onSurfaceVariant: palette.textMuted,
      outline: isDark ? const Color(0xFF4A4134) : const Color(0xFFC5BAA6),
      outlineVariant: palette.panelBorder,
      surfaceContainerHighest: palette.panel,
      surfaceContainerLow: palette.panel,
      surfaceContainer: palette.panel,
    );

    final TextTheme base = ThemeData(brightness: brightness).textTheme;
    final TextTheme text = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 8,
        color: palette.text,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: palette.text,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: palette.textMuted,
        height: 1.4,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 2.5,
        color: palette.text,
      ),
      labelMedium: base.labelMedium?.copyWith(
        letterSpacing: 1.5,
        color: palette.textMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      textTheme: text,
      dividerTheme: DividerThemeData(color: palette.panelBorder),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.accent, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: text.labelLarge,
        ),
      ),
    );
  }
}