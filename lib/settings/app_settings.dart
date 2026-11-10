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
  );

  /// Bounds used by the settings screen and when reading the file.
  static const historyCapRange = (min: 1, max: 5000);
  static const undoDepthRange = (min: 1, max: 1000);
  static const fontScaleRange = (min: 0.8, max: 1.6);
  static const snoozeRange = (min: 1, max: 10080);
  static const repeatsAheadRange = (min: 1, max: 50);

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
    );
  }
}
