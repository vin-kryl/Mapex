import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// True on macOS and iOS, where Sortle follows Apple's look: the system
/// font, system blue, and quiet grey surfaces.
bool get isApple =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// True where a mouse and a big window are the norm.
bool get isDesktop =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// True once the Mac window has been made see-through, so the sidebar
/// shows the frosted desktop behind it. Set at startup.
bool isMacFrosted = false;

/// Colour tokens. Quiet neutrals with a single accent.
abstract final class Palette {
  static const appleBlue = Color(0xFF007AFF);
  static const appleBlueDark = Color(0xFF0A84FF);
  static const indigo = Color(0xFF5B4BD8);
  static const indigoDark = Color(0xFF8B7FF0);
  static const danger = Color(0xFFFF3B30);

  /// Offered in the colour picker, alongside a field for any hex colour.
  static const choices = [
    Color(0xFF8E7CF0),
    Color(0xFF5FBF95),
    Color(0xFFE8A07A),
    Color(0xFF7AA8E8),
    Color(0xFFE8C95F),
    Color(0xFFE87A9A),
    Color(0xFFC9B8FF),
    Color(0xFFB5EBD3),
    Color(0xFFFFD2B8),
    Color(0xFFB8DBFF),
    Color(0xFF007AFF),
    Color(0xFF5856D6),
    Color(0xFFAF52DE),
    Color(0xFFFF2D55),
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF30B0C7),
    Color(0xFF32ADE6),
    Color(0xFF5B4BD8),
    Color(0xFFA2845E),
    Color(0xFF8E8E93),
    Color(0xFF1D1D1F),
  ];
}

/// The neutral surfaces and text colours of one brightness.
class Tones extends ThemeExtension<Tones> {
  const Tones({
    required this.window,
    required this.canvas,
    required this.card,
    required this.grouped,
    required this.sidebar,
    required this.hairline,
    required this.text,
    required this.secondary,
    required this.tertiary,
    required this.wire,
    required this.gridDot,
    required this.ink,
    required this.onInk,
  });

  static const light = Tones(
    window: Color(0xFFFFFFFF),
    canvas: Color(0xFFFBFBFC),
    card: Color(0xFFFFFFFF),
    grouped: Color(0xFFF5F5F7),
    sidebar: Color(0xFFF2F2F5),
    hairline: Color(0x1A000000),
    text: Color(0xFF1D1D1F),
    secondary: Color(0xFF86868B),
    tertiary: Color(0xFFC7C7CC),
    wire: Color(0xFFC7C7CC),
    gridDot: Color(0xFFE3E3E8),
    ink: Color(0xFF18181B),
    onInk: Color(0xFFFFFFFF),
  );

  static const dark = Tones(
    window: Color(0xFF1E1E1E),
    canvas: Color(0xFF19191B),
    card: Color(0xFF2C2C2E),
    grouped: Color(0xFF242426),
    sidebar: Color(0xFF28282B),
    hairline: Color(0x1FFFFFFF),
    text: Color(0xFFF5F5F7),
    secondary: Color(0xFF98989D),
    tertiary: Color(0xFF545458),
    wire: Color(0xFF545458),
    gridDot: Color(0xFF2E2E31),
    ink: Color(0xFFF4F4F5),
    onInk: Color(0xFF18181B),
  );

  /// Behind everything.
  final Color window;

  /// Behind the nodes of a board.
  final Color canvas;

  /// Nodes and raised cards.
  final Color card;

  /// Grouped lists and form sections.
  final Color grouped;
  final Color sidebar;

  /// Thin separators and card edges.
  final Color hairline;
  final Color text;
  final Color secondary;

  /// Empty status circles and other faint marks.
  final Color tertiary;
  final Color wire;
  final Color gridDot;

  /// Strong buttons outside Apple platforms.
  final Color ink;
  final Color onInk;

  static Tones of(BuildContext context) =>
      Theme.of(context).extension<Tones>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  Tones copyWith() => this;

  @override
  Tones lerp(Tones? other, double t) => t < 0.5 || other == null ? this : other;
}

/// Spacing and shape tokens. Corner roundness is a setting, read through
/// [Look.of].
abstract final class Metrics {
  static const gutter = 16.0;
  static const gap = 12.0;
  static const maxContentWidth = 720.0;
  static const sidebarWidth = 228.0;
  static const inspectorWidth = 300.0;
}

Color hexToColor(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

String colorToHex(Color c) {
  final rgb = c.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// The main colour when the user hasn't picked one: system blue on Apple
/// devices, Sortle indigo elsewhere.
Color defaultAccent([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  if (isApple) return dark ? Palette.appleBlueDark : Palette.appleBlue;
  return dark ? Palette.indigoDark : Palette.indigo;
}

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

  factory Look.from(AppSettings s, Color accent) => Look(
    nodeColors: [for (final c in s.nodeColors) hexToColor(c)],
    decision: hexToColor(s.decisionColor),
    taken: s.takenColor == null ? accent : hexToColor(s.takenColor!),
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
      Theme.of(context).extension<Look>() ??
      Look.from(AppSettings.defaults, defaultAccent());

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

/// Bundled for Android, Windows and Linux. Apple devices use their own
/// system font.
const bodyFont = 'Inter';

/// For large page titles outside Apple devices.
const titleFont = 'FunnelDisplay';

ThemeMode themeModeOf(ThemeChoice choice) => switch (choice) {
  ThemeChoice.system => ThemeMode.system,
  ThemeChoice.light => ThemeMode.light,
  ThemeChoice.dark => ThemeMode.dark,
};

/// Black or white, whichever reads better on [c].
Color onColor(Color c) =>
    c.computeLuminance() > 0.45 ? Tones.light.text : const Color(0xFFFFFFFF);

/// Style for a page's big title.
TextStyle largeTitle(BuildContext context) => TextStyle(
  fontFamily: isApple ? null : titleFont,
  fontSize: isApple ? 26 : 30,
  fontWeight: isApple ? FontWeight.w700 : FontWeight.w600,
  letterSpacing: isApple ? -0.4 : -0.6,
  color: Tones.of(context).text,
);

/// Small grey heading over a section.
TextStyle sectionLabel(BuildContext context) => TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: Tones.of(context).secondary,
);

ThemeData buildTheme(
  Brightness brightness,
  AppSettings settings, {
  ColorScheme? wallpaper,
}) {
  final dark = brightness == Brightness.dark;
  final t = dark ? Tones.dark : Tones.light;
  final accent = settings.accentColor != null
      ? hexToColor(settings.accentColor!)
      : wallpaper?.primary ?? defaultAccent(brightness);
  final look = Look.from(settings, accent);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onColor(accent),
    secondary: accent,
    onSecondary: onColor(accent),
    error: Palette.danger,
    onError: const Color(0xFFFFFFFF),
    surface: t.window,
    onSurface: t.text,
    onSurfaceVariant: t.secondary,
    surfaceContainerLowest: t.window,
    surfaceContainerLow: t.grouped,
    surfaceContainer: t.grouped,
    surfaceContainerHigh: t.card,
    surfaceContainerHighest: t.grouped,
    outline: t.hairline,
    outlineVariant: t.hairline,
    shadow: const Color(0xFF000000),
  );
  final radius = BorderRadius.circular(look.radius);
  // Apple's main buttons are the accent colour; elsewhere they are ink.
  final strong = isApple ? accent : t.ink;
  final onStrong = isApple ? onColor(accent) : t.onInk;
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(isApple ? 7 : look.radius + 2),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    extensions: [look, t],
    colorScheme: scheme,
    fontFamily: isApple ? null : bodyFont,
    scaffoldBackgroundColor: t.window,
    canvasColor: t.window,
    dividerColor: t.hairline,
    splashFactory: isApple ? NoSplash.splashFactory : InkSparkle.splashFactory,
    visualDensity: isDesktop ? VisualDensity.compact : null,
    dividerTheme: DividerThemeData(color: t.hairline, thickness: 0.5, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: t.window,
      foregroundColor: t.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: isApple ? null : bodyFont,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: t.text,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: t.hairline, width: 0.5),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: t.secondary,
      subtitleTextStyle: TextStyle(color: t.secondary, fontSize: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: strong,
        foregroundColor: onStrong,
        shape: buttonShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.text,
        side: BorderSide(color: t.hairline),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent, shape: buttonShape),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: strong,
      foregroundColor: onStrong,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.window,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? t.text : t.secondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? t.text : t.secondary,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.window,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.window,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.hairline, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.grouped,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isApple ? 7 : 12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isApple ? 7 : 12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? (isApple ? const Color(0xFF34C759) : accent)
            : t.tertiary,
      ),
      thumbColor: const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: t.ink.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(color: t.onInk, fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      contentTextStyle: TextStyle(color: t.onInk),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
