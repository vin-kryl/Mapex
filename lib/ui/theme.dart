import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// Colour tokens. Black and white with pastel accents.
abstract final class Palette {
  static const ink = Color(0xFF111111);
  static const paper = Color(0xFFFFFFFF);
  static const night = Color(0xFF0E0E10);
  static const nightSurface = Color(0xFF1A1A1D);
  static const mist = Color(0xFFF4F4F5);
  static const line = Color(0xFFE4E4E7);
  static const lineDark = Color(0xFF2E2E33);
  static const muted = Color(0xFF6B6B73);
  static const mutedDark = Color(0xFFA1A1AA);

  /// Pastel accents, also offered for node colour-coding.
  static const lavender = Color(0xFFC9B8FF);
  static const mint = Color(0xFFB5EBD3);
  static const peach = Color(0xFFFFD2B8);
  static const sky = Color(0xFFB8DBFF);
  static const butter = Color(0xFFFFEDA8);
  static const rose = Color(0xFFFFC2D4);

  static const accents = [lavender, mint, peach, sky, butter, rose];

  /// Status colours.
  static const done = Color(0xFF2F9E6E);
  static const notYet = Color(0xFFC77D1E);
  static const danger = Color(0xFFD64545);
}

/// Spacing and shape tokens.
abstract final class Metrics {
  static const gutter = 16.0;
  static const gap = 12.0;
  static const radius = 16.0;
  static const maxContentWidth = 720.0;
}

const fontFamily = 'FunnelDisplay';

ThemeMode themeModeOf(ThemeChoice choice) => switch (choice) {
  ThemeChoice.system => ThemeMode.system,
  ThemeChoice.light => ThemeMode.light,
  ThemeChoice.dark => ThemeMode.dark,
};

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? Palette.paper : Palette.ink,
    onPrimary: dark ? Palette.ink : Palette.paper,
    secondary: Palette.lavender,
    onSecondary: Palette.ink,
    tertiary: Palette.mint,
    onTertiary: Palette.ink,
    error: Palette.danger,
    onError: Palette.paper,
    surface: dark ? Palette.night : Palette.paper,
    onSurface: dark ? Palette.paper : Palette.ink,
    onSurfaceVariant: dark ? Palette.mutedDark : Palette.muted,
    surfaceContainerLowest: dark ? Palette.night : Palette.paper,
    surfaceContainerLow: dark ? Palette.nightSurface : Palette.mist,
    surfaceContainer: dark ? Palette.nightSurface : Palette.mist,
    surfaceContainerHigh: dark ? Palette.nightSurface : Palette.paper,
    surfaceContainerHighest: dark ? Palette.lineDark : Palette.line,
    outline: dark ? Palette.lineDark : Palette.line,
    outlineVariant: dark ? Palette.lineDark : Palette.line,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Metrics.radius),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: shape,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      shape: shape,
    ),
    dialogTheme: DialogThemeData(shape: shape),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Metrics.radius / 2),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
