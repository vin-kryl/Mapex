import '../model/node.dart';
import '../model/reminder.dart';
import '../settings/app_settings.dart';

/// Time maths for reminders, prompts and the Today screen. All times here
/// are local wall-clock times; the platform layer handles time zones.
abstract final class Timing {
  /// The node's calendar day, or null when it has no date.
  static DateTime? day(Node n) {
    final d = n.date;
    if (d == null) return null;
    final p = d.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  /// The node's date and time, or null unless it has both.
  static DateTime? dueAt(Node n) {
    final d = day(n);
    final t = n.time;
    if (d == null || t == null) return null;
    final p = t.split(':').map(int.parse).toList();
    return DateTime(d.year, d.month, d.day, p[0], p[1]);
  }

  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  /// Whether the node still wants attention (not done, not eliminated).
  static bool isOpen(Node n) =>
      n.status == NodeStatus.pending || n.status == NodeStatus.notYet;

  static int leadMinutes(Reminder r, AppSettings s) =>
      r.leadMinutes ?? s.defaultReminderLeadMinutes;

  /// When the "Done?" / "Which did you do?" question is due: a task at its
  /// time, a decision after the decision-prompt delay.
  static DateTime? promptAt(Node n, AppSettings s) {
    final due = dueAt(n);
    if (due == null) return null;
    return n.type == NodeType.decision
        ? due.add(Duration(minutes: s.decisionPromptDelayMinutes))
        : due;
  }

  /// The next occurrence of a repeating node's time after [due], or null if
  /// it does not repeat.
  static DateTime? nextOccurrence(DateTime due, Reminder? r) {
    switch (r?.repeat) {
      case null:
      case RepeatKind.none:
        return null;
      case RepeatKind.daily:
        return DateTime(due.year, due.month, due.day + 1, due.hour, due.minute);
      case RepeatKind.weekly:
        return DateTime(due.year, due.month, due.day + 7, due.hour, due.minute);
      case RepeatKind.interval:
        return due.add(Duration(minutes: r!.intervalMinutes!));
    }
  }

  /// The first occurrence at or after [now] (the due time itself when it is
  /// still ahead, or when the node does not repeat).
  static DateTime upcoming(DateTime due, Reminder? r, DateTime now) {
    var t = due;
    var guard = 0;
    while (t.isBefore(now) && guard++ < 100000) {
      final next = nextOccurrence(t, r);
      if (next == null) return t;
      t = next;
    }
    return t;
  }

  /// The first occurrence after both [due] and [now], or null if the node
  /// does not repeat. Used when a repeating task is ticked done.
  static DateTime? nextAfter(DateTime due, Reminder? r, DateTime now) {
    var t = nextOccurrence(due, r);
    if (t == null) return null;
    var guard = 0;
    while (!t!.isAfter(now) && guard++ < 100000) {
      t = nextOccurrence(t, r);
    }
    return t;
  }
}
