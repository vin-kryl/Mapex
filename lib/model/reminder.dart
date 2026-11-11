import 'json_read.dart';

enum RepeatKind {
  none,
  daily,
  weekly,

  /// Every [Reminder.intervalMinutes] minutes.
  interval;

  static RepeatKind fromJson(Object? value, String path) =>
      readEnum(RepeatKind.values, value, path);
}

/// A node's reminder, fired as a local notification.
class Reminder {
  const Reminder({
    this.leadMinutes,
    this.repeat = RepeatKind.none,
    this.intervalMinutes,
  });

  /// Minutes before the node's date/time to fire. Null means use the
  /// default lead time from settings.
  final int? leadMinutes;
  final RepeatKind repeat;

  /// Only used when [repeat] is [RepeatKind.interval].
  final int? intervalMinutes;

  Map<String, Object?> toJson() => {
    'leadMinutes': leadMinutes,
    'repeat': repeat.name,
    'intervalMinutes': intervalMinutes,
  };

  static Reminder fromJson(Object? json, String path) {
    final map = readMap(json, path);
    final lead = readOptionalInt(map, 'leadMinutes', path);
    if (lead != null && lead < 0) {
      throw SchemaException('$path.leadMinutes must not be negative');
    }
    final repeat = RepeatKind.fromJson(map['repeat'], '$path.repeat');
    final interval = readOptionalInt(map, 'intervalMinutes', path);
    if (repeat == RepeatKind.interval && (interval == null || interval <= 0)) {
      throw SchemaException(
        '$path.intervalMinutes must be above 0 for an interval repeat',
      );
    }
    return Reminder(
      leadMinutes: lead,
      repeat: repeat,
      intervalMinutes: interval,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.leadMinutes == leadMinutes &&
      other.repeat == repeat &&
      other.intervalMinutes == intervalMinutes;

  @override
  int get hashCode => Object.hash(leadMinutes, repeat, intervalMinutes);
}
