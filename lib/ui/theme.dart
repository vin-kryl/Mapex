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

  static const lavender = Color(0xFFC9B8FF);
  static const mint = Color(0xFFB5EBD3);
  static const danger = Color(0xFFD64545);

  /// Offered in the colour picker, alongside a field for any hex colour.
  static const choices = [
    Color(0xFFC9B8FF),
    Color(0xFFB5EBD3),
    Color(0xFFFFD2B8),
    Color(0xFFB8DBFF),
    Color(0xFFFFEDA8),
    Color(0xFFFFC2D4),
    Color(0xFFE2E2E2),
    Color(0xFFD9F99D),
    Color(0xFFA5F3FC),
    Color(0xFFFBCFE8),
    Color(0xFFFED7AA),
    Color(0xFFDDD6FE),
    Color(0xFF9B84F0),
    Color(0xFF7DD3AE),
    Color(0xFF2F9E6E),
    Color(0xFFC77D1E),
    Color(0xFF2563EB),
    Color(0xFF0EA5E9),
    Color(0xFF14B8A6),
    Color(0xFF16A34A),
    Color(0xFFEAB308),
    Color(0xFFF97316),
    Color(0xFFDC2626),
    Color(0xFFDB2777),
    Color(0xFF7C3AED),
    Color(0xFF4F46E5),
    Color(0xFF475569),
    Color(0xFF111111),
  ];
}

/// Spacing and shape tokens. Corner roundness is a setting, read through
/// [Look.of].
abstract final class Metrics {
  static const gutter = 16.0;
  static const gap = 12.0;
  static const maxContentWidth = 720.0;
}

Color hexToColor(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

/// The colours and shape the user picked in Settings, available to every
/// widget through the theme.
class Look extends ThemeExtension<Look> {
  const Look({
    required this.nodeColors,
    required this.decision,
    required this.taken,
    required this.done,
    required this.notYet,
    required this.radius,
  });

  factory Look.from(AppSettings s) => Look(
    nodeColors: [for (final c in s.nodeColors) hexToColor(c)],
    decision: hexToColor(s.decisionColor),
    taken: hexToColor(s.takenColor),
    done: hexToColor(s.doneColor),
    notYet: hexToColor(s.notYetColor),
    radius: s.cornerRadius,
  );

  final List<Color> nodeColors;
  final Color decision;
  final Color taken;
  final Color done;
  final Color notYet;
  final double radius;

  static Look of(BuildContext context) =>
      Theme.of(context).extension<Look>() ?? Look.from(AppSettings.defaults);

  @override
  Look copyWith({
    List<Color>? nodeColors,
    Color? decision,
    Color? taken,
    Color? done,
    Color? notYet,
    double? radius,
  }) => Look(
    nodeColors: nodeColors ?? this.nodeColors,
    decision: decision ?? this.decision,
    taken: taken ?? this.taken,
    done: done ?? this.done,
    notYet: notYet ?? this.notYet,
    radius: radius ?? this.radius,
  );

  @override
  Look lerp(Look? other, double t) => t < 0.5 || other == null ? this : other;
}

const fontFamily = 'FunnelDisplay';

ThemeMode themeModeOf(ThemeChoice choice) => switch (choice) {
  ThemeChoice.system => ThemeMode.system,
  ThemeChoice.light => ThemeMode.light,
  ThemeChoice.dark => ThemeMode.dark,
};

/// Black or white, whichever reads better on [c].
Color onColor(Color c) =>
    c.computeLuminance() > 0.45 ? Palette.ink : Palette.paper;

ThemeData buildTheme(Brightness brightness, AppSettings settings) {
  final dark = brightness == Brightness.dark;
  final look = Look.from(settings);
  final accent = settings.accentColor == null
      ? null
      : hexToColor(settings.accentColor!);
  final primary = accent ?? (dark ? Palette.paper : Palette.ink);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onColor(primary),
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
    borderRadius: BorderRadius.circular(look.radius),
  );
  return ThemeData(
    useMaterial3: true,
    extensions: [look],
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
        borderRadius: BorderRadius.circular(look.radius / 2),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
