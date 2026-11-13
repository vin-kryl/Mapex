import '../model/json_read.dart';
import '../model/node.dart';

enum LayoutDirection {
  topDown,
  leftRight;

  static LayoutDirection fromJson(Object? v, String p) =>
      readEnum(values, v, p);
}

enum ThemeChoice {
  system,
  light,
  dark;

  static ThemeChoice fromJson(Object? v, String p) => readEnum(values, v, p);
}

/// Every user-adjustable value lives here; nothing else in the app should
/// hard-code these. Stored as `settings.json` in the app folder.
///
/// Unknown or missing keys fall back to [AppSettings.defaults], so older
/// settings files keep working when new settings are added.
class AppSettings {
  const AppSettings({
    required this.layoutDirection,
    required this.defaultNodeType,
    required this.defaultReminderLeadMinutes,
    required this.decisionPromptDelayMinutes,
    required this.notificationSound,
    required this.theme,
    required this.fontScale,
    required this.exportWithAudio,
    required this.undoHistoryDepth,
    required this.historyCap,
    required this.snoozeMinutes,
    required this.repeatsScheduledAhead,
    required this.accentColor,
    required this.nodeColors,
    required this.decisionColor,
    required this.takenColor,
    required this.doneColor,
    required this.notYetColor,
    required this.cornerRadius,
    required this.wallpaperColors,
  });

  static const defaults = AppSettings(
    layoutDirection: LayoutDirection.topDown,
    defaultNodeType: NodeType.task,
    defaultReminderLeadMinutes: 0,
    decisionPromptDelayMinutes: 60,
    notificationSound: true,
    theme: ThemeChoice.system,
    fontScale: 1.0,
    exportWithAudio: true,
    undoHistoryDepth: 100,
    historyCap: 200,
    snoozeMinutes: 60,
    repeatsScheduledAhead: 5,
    accentColor: null,
    nodeColors: [
      '#8E7CF0',
      '#5FBF95',
      '#E8A07A',
      '#7AA8E8',
      '#E8C95F',
      '#E87A9A',
    ],
    decisionColor: '#8E8E93',
    takenColor: null,
    doneColor: '#34C759',
    notYetColor: '#FF9F0A',
    cornerRadius: 10,
    wallpaperColors: false,
  );

  /// Defaults from earlier versions. A settings file still holding one of
  /// these was never changed by the user, so it gets today's default.
  static const _retired = {
    'nodeColors': [
      '#C9B8FF',
      '#B5EBD3',
      '#FFD2B8',
      '#B8DBFF',
      '#FFEDA8',
      '#FFC2D4',
    ],
    'decisionColor': '#9B84F0',
    'takenColor': '#7DD3AE',
    'doneColor': '#2F9E6E',
    'notYetColor': '#C77D1E',
    'cornerRadius': 16,
  };

  /// Bounds used by the settings screen and when reading the file.
  static const historyCapRange = (min: 1, max: 5000);
  static const undoDepthRange = (min: 1, max: 1000);
  static const fontScaleRange = (min: 0.8, max: 1.6);
  static const snoozeRange = (min: 1, max: 10080);
  static const repeatsAheadRange = (min: 1, max: 50);
  static const cornerRadiusRange = (min: 0.0, max: 28.0);
  static const nodeColorsRange = (min: 1, max: 16);

  /// `#RRGGBB`.
  static final hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

  final LayoutDirection layoutDirection;
  final NodeType defaultNodeType;
  final int defaultReminderLeadMinutes;
  final int decisionPromptDelayMinutes;
  final bool notificationSound;
  final ThemeChoice theme;
  final double fontScale;
  final bool exportWithAudio;
  final int undoHistoryDepth;

  /// How many history snapshots each board keeps.
  final int historyCap;

  /// The "Not yet" quick option pushes a node back by this many minutes.
  final int snoozeMinutes;

  /// For custom-interval repeats, how many upcoming reminders are booked
  /// with the system at a time. Topped up whenever the app opens.
  final int repeatsScheduledAhead;

  /// The app's main colour as `#RRGGBB`, or null for the platform's own
  /// (system blue on Apple devices, Sortle indigo elsewhere).
  final String? accentColor;

  /// The colours offered for colour-coding nodes.
  final List<String> nodeColors;

  /// Marks decision nodes.
  final String decisionColor;

  /// Outlines the path picked in a decision, or null to use the main colour.
  final String? takenColor;
  final String doneColor;
  final String notYetColor;

  /// How rounded cards, nodes and buttons are.
  final double cornerRadius;

  /// Android 12 and later: take the main colour from the wallpaper, unless
  /// a main colour is picked.
  final bool wallpaperColors;

  AppSettings copyWith({
    LayoutDirection? layoutDirection,
    NodeType? defaultNodeType,
    int? defaultReminderLeadMinutes,
    int? decisionPromptDelayMinutes,
    bool? notificationSound,
    ThemeChoice? theme,
    double? fontScale,
    bool? exportWithAudio,
    int? undoHistoryDepth,
    int? historyCap,
    int? snoozeMinutes,
    int? repeatsScheduledAhead,
    String? Function()? accentColor,
    List<String>? nodeColors,
    String? decisionColor,
    String? Function()? takenColor,
    String? doneColor,
    String? notYetColor,
    double? cornerRadius,
    bool? wallpaperColors,
  }) {
    return AppSettings(
      layoutDirection: layoutDirection ?? this.layoutDirection,
      defaultNodeType: defaultNodeType ?? this.defaultNodeType,
      defaultReminderLeadMinutes:
          defaultReminderLeadMinutes ?? this.defaultReminderLeadMinutes,
      decisionPromptDelayMinutes:
          decisionPromptDelayMinutes ?? this.decisionPromptDelayMinutes,
      notificationSound: notificationSound ?? this.notificationSound,
      theme: theme ?? this.theme,
      fontScale: fontScale ?? this.fontScale,
      exportWithAudio: exportWithAudio ?? this.exportWithAudio,
      undoHistoryDepth: undoHistoryDepth ?? this.undoHistoryDepth,
      historyCap: historyCap ?? this.historyCap,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      repeatsScheduledAhead:
          repeatsScheduledAhead ?? this.repeatsScheduledAhead,
      accentColor: accentColor == null ? this.accentColor : accentColor(),
      nodeColors: nodeColors ?? this.nodeColors,
      decisionColor: decisionColor ?? this.decisionColor,
      takenColor: takenColor == null ? this.takenColor : takenColor(),
      doneColor: doneColor ?? this.doneColor,
      notYetColor: notYetColor ?? this.notYetColor,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      wallpaperColors: wallpaperColors ?? this.wallpaperColors,
    );
  }

  Map<String, Object?> toJson() => {
    'layoutDirection': layoutDirection.name,
    'defaultNodeType': defaultNodeType.name,
    'defaultReminderLeadMinutes': defaultReminderLeadMinutes,
    'decisionPromptDelayMinutes': decisionPromptDelayMinutes,
    'notificationSound': notificationSound,
    'theme': theme.name,
    'fontScale': fontScale,
    'exportWithAudio': exportWithAudio,
    'undoHistoryDepth': undoHistoryDepth,
    'historyCap': historyCap,
    'snoozeMinutes': snoozeMinutes,
    'repeatsScheduledAhead': repeatsScheduledAhead,
    'accentColor': accentColor,
    'nodeColors': nodeColors,
    'decisionColor': decisionColor,
    'takenColor': takenColor,
    'doneColor': doneColor,
    'notYetColor': notYetColor,
    'cornerRadius': cornerRadius,
    'wallpaperColors': wallpaperColors,
  };

  /// Lenient: a bad or missing value is replaced by its default.
  static AppSettings fromJson(Object? json) {
    const d = defaults;
    final Map<String, Object?> map;
    try {
      map = readMap(json, 'settings');
    } on SchemaException {
      return d;
    }
    T pick<T>(T Function() read, T fallback) {
      try {
        return read();
      } on SchemaException {
        return fallback;
      }
    }

    int intIn(String key, int fallback, ({int min, int max}) range) {
      final v = pick(() => readInt(map, key, 'settings'), fallback);
      return v.clamp(range.min, range.max);
    }

    int nonNegative(String key, int fallback) {
      final v = pick(() => readInt(map, key, 'settings'), fallback);
      return v < 0 ? fallback : v;
    }

    String color(String key, String fallback) {
      final v = map[key];
      if (v is String && v.toUpperCase() == _retired[key]) return fallback;
      return v is String && hexColor.hasMatch(v) ? v.toUpperCase() : fallback;
    }

    bool sameList(List<String> a, Object? b) =>
        b is List &&
        a.length == b.length &&
        a.indexed.every((e) => b[e.$1] == e.$2);

    final rawNodeColors = map['nodeColors'];
    final nodeColors = rawNodeColors is List
        ? [
            for (final c in rawNodeColors)
              if (c is String && hexColor.hasMatch(c)) c.toUpperCase(),
          ].take(nodeColorsRange.max).toList()
        : d.nodeColors;
    final retiredColors = sameList(nodeColors, _retired['nodeColors']);
    final rawTaken = map['takenColor'];
    final rawAccent = map['accentColor'];
    final rawRadius = map['cornerRadius'] == _retired['cornerRadius']
        ? null
        : map['cornerRadius'];

    final rawScale = map['fontScale'];
    final scale = rawScale is num
        ? rawScale.toDouble().clamp(fontScaleRange.min, fontScaleRange.max)
        : d.fontScale;

    return AppSettings(
      layoutDirection: pick(
        () => LayoutDirection.fromJson(map['layoutDirection'], 's'),
        d.layoutDirection,
      ),
      defaultNodeType: pick(
        () => NodeType.fromJson(map['defaultNodeType'], 's'),
        d.defaultNodeType,
      ),
      defaultReminderLeadMinutes: nonNegative(
        'defaultReminderLeadMinutes',
        d.defaultReminderLeadMinutes,
      ),
      decisionPromptDelayMinutes: nonNegative(
        'decisionPromptDelayMinutes',
        d.decisionPromptDelayMinutes,
      ),
      notificationSound: pick(
        () => readBool(map, 'notificationSound', 's'),
        d.notificationSound,
      ),
      theme: pick(() => ThemeChoice.fromJson(map['theme'], 's'), d.theme),
      fontScale: scale,
      exportWithAudio: pick(
        () => readBool(map, 'exportWithAudio', 's'),
        d.exportWithAudio,
      ),
      undoHistoryDepth: intIn(
        'undoHistoryDepth',
        d.undoHistoryDepth,
        undoDepthRange,
      ),
      historyCap: intIn('historyCap', d.historyCap, historyCapRange),
      snoozeMinutes: intIn('snoozeMinutes', d.snoozeMinutes, snoozeRange),
      repeatsScheduledAhead: intIn(
        'repeatsScheduledAhead',
        d.repeatsScheduledAhead,
        repeatsAheadRange,
      ),
      accentColor: rawAccent is String && hexColor.hasMatch(rawAccent)
          ? rawAccent.toUpperCase()
          : null,
      nodeColors: nodeColors.isEmpty || retiredColors
          ? d.nodeColors
          : nodeColors,
      decisionColor: color('decisionColor', d.decisionColor),
      takenColor:
          rawTaken is String &&
              hexColor.hasMatch(rawTaken) &&
              rawTaken.toUpperCase() != _retired['takenColor']
          ? rawTaken.toUpperCase()
          : null,
      doneColor: color('doneColor', d.doneColor),
      notYetColor: color('notYetColor', d.notYetColor),
      cornerRadius: rawRadius is num
          ? rawRadius.toDouble().clamp(
              cornerRadiusRange.min,
              cornerRadiusRange.max,
            )
          : d.cornerRadius,
      wallpaperColors: pick(
        () => readBool(map, 'wallpaperColors', 's'),
        d.wallpaperColors,
      ),
    );
  }
}
