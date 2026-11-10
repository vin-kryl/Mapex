import 'dart:convert';

import '../model/board.dart';
import '../model/node.dart';
import '../model/reminder.dart';
import '../model/tree_ops.dart';
import '../settings/app_settings.dart';
import 'timing.dart';

enum AlertKind {
  /// Ahead of the node's time, by the lead time.
  headsUp,

  /// "Done?" for a task, "Which one of these did you do?" for a decision.
  prompt,
}

enum Recurrence { none, daily, weekly }

/// One notification to hand to the system.
class PlannedAlert {
  const PlannedAlert({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
    this.recurrence = Recurrence.none,
  });

  /// Stable per board, node, kind and occurrence, so re-planning replaces
  /// rather than duplicates.
  final int id;
  final DateTime at;
  final String title;
  final String body;
  final AlertPayload payload;
  final Recurrence recurrence;
}

/// What a tapped notification points at.
class AlertPayload {
  const AlertPayload({
    required this.boardId,
    required this.nodeId,
    required this.kind,
  });

  final String boardId;
  final String nodeId;
  final AlertKind kind;

  String encode() => jsonEncode({'b': boardId, 'n': nodeId, 'k': kind.name});

  static AlertPayload? decode(String? text) {
    if (text == null) return null;
    try {
      final m = jsonDecode(text) as Map<String, Object?>;
      return AlertPayload(
        boardId: m['b']! as String,
        nodeId: m['n']! as String,
        kind: AlertKind.values.byName(m['k']! as String),
      );
    } on Object {
      return null;
    }
  }
}

/// Works out every notification a board needs from now on.
abstract final class AlertPlanner {
  static List<PlannedAlert> plan(
    Board board,
    AppSettings settings,
    DateTime now,
  ) {
    final out = <PlannedAlert>[];
    for (final (:node, depth: _) in TreeOps.walk(board.root)) {
      final r = node.reminder;
      final due = Timing.dueAt(node);
      if (r == null || due == null || !Timing.isOpen(node)) continue;

      final lead = Duration(minutes: Timing.leadMinutes(r, settings));
      final promptOffset = Timing.promptAt(node, settings)!.difference(due);

      void add(AlertKind kind, Duration offset, String title, String body) {
        final recurrence = switch (r.repeat) {
          RepeatKind.daily => Recurrence.daily,
          RepeatKind.weekly => Recurrence.weekly,
          _ => Recurrence.none,
        };
        if (recurrence != Recurrence.none) {
          // The system repeats it; book the next one only.
          final first = _firstFiring(due, r, offset, now);
          out.add(
            PlannedAlert(
              id: alertId(board.id, node.id, kind, 0),
              at: first,
              title: title,
              body: body,
              payload: AlertPayload(
                boardId: board.id,
                nodeId: node.id,
                kind: kind,
              ),
              recurrence: recurrence,
            ),
          );
          return;
        }
        // One-off, or a custom interval: book the next few occurrences.
        if (r.repeat != RepeatKind.interval) {
          final at = due.add(offset);
          if (at.isAfter(now)) {
            out.add(
              PlannedAlert(
                id: alertId(board.id, node.id, kind, 0),
                at: at,
                title: title,
                body: body,
                payload: AlertPayload(
                  boardId: board.id,
                  nodeId: node.id,
                  kind: kind,
                ),
              ),
            );
          }
          return;
        }
        var at = _firstFiring(due, r, offset, now);
        for (var i = 0; i < settings.repeatsScheduledAhead; i++) {
          out.add(
            PlannedAlert(
              id: alertId(board.id, node.id, kind, i),
              at: at,
              title: title,
              body: body,
              payload: AlertPayload(
                boardId: board.id,
                nodeId: node.id,
                kind: kind,
              ),
            ),
          );
          at = Timing.nextOccurrence(at, r)!;
        }
      }

      if (lead > Duration.zero) {
        add(
          AlertKind.headsUp,
          -lead,
          node.title,
          'Coming up at ${Timing.formatTime(due)}',
        );
      }
      add(
        AlertKind.prompt,
        promptOffset,
        node.title,
        node.type == NodeType.decision
            ? 'Which one of these did you do?'
            : 'Done?',
      );
    }
    return out;
  }

  static DateTime _firstFiring(
    DateTime due,
    Reminder r,
    Duration offset,
    DateTime now,
  ) {
    var at = due.add(offset);
    while (!at.isAfter(now)) {
      at = Timing.nextOccurrence(at, r)!;
    }
    return at;
  }

  /// A stable 31-bit id (FNV-1a) for one alert.
  static int alertId(String boardId, String nodeId, AlertKind kind, int n) {
    var h = 0x811c9dc5;
    for (final unit in '$boardId/$nodeId/${kind.name}/$n'.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h & 0x7FFFFFFF;
  }
}
