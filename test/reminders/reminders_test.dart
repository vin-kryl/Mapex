import 'package:flutter_test/flutter_test.dart';
import 'package:mapex/model/board.dart';
import 'package:mapex/model/node.dart';
import 'package:mapex/model/reminder.dart';
import 'package:mapex/reminders/alert_platform.dart';
import 'package:mapex/reminders/plan.dart';
import 'package:mapex/reminders/scheduler.dart';
import 'package:mapex/reminders/timing.dart';
import 'package:mapex/reminders/today.dart';
import 'package:mapex/settings/app_settings.dart';

final t0 = DateTime.utc(2026);

Node n(
  String id, {
  NodeType type = NodeType.task,
  NodeStatus status = NodeStatus.pending,
  String? date,
  String? time,
  Reminder? reminder,
  List<Node> children = const [],
}) => Node(
  id: id,
  title: id,
  type: type,
  status: status,
  date: date,
  time: time,
  reminder: reminder,
  createdAt: t0,
  updatedAt: t0,
  children: children,
);

Board board(List<Node> kids, {String id = 'b1'}) => Board(
  id: id,
  title: 'Board',
  createdAt: t0,
  updatedAt: t0,
  root: n('root', children: kids),
);

const settings = AppSettings.defaults; // lead 0, decision delay 60

class FakePlatform implements AlertPlatform {
  final booked = <int, PlannedAlert>{};
  int cancels = 0;

  @override
  Future<void> init(void Function(AlertPayload payload) onTap) async {}

  @override
  Future<AlertPayload?> launchPayload() async => null;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<List<({int id, AlertPayload? payload})>> pending() async => [
    for (final a in booked.values) (id: a.id, payload: a.payload),
  ];

  @override
  Future<void> schedule(PlannedAlert alert, {required bool sound}) async =>
      booked[alert.id] = alert;

  @override
  Future<void> cancel(int id) async {
    cancels++;
    booked.remove(id);
  }
}

void main() {
  group('timing', () {
    test('due time needs both date and time', () {
      expect(Timing.dueAt(n('a', date: '2026-11-10')), isNull);
      expect(
        Timing.dueAt(n('a', date: '2026-11-10', time: '09:30')),
        DateTime(2026, 11, 10, 9, 30),
      );
    });

    test('decisions are asked about after the delay, tasks at their time', () {
      final task = n('t', date: '2026-11-10', time: '09:00');
      final dec = n(
        'd',
        type: NodeType.decision,
        date: '2026-11-10',
        time: '09:00',
      );
      expect(Timing.promptAt(task, settings), DateTime(2026, 11, 10, 9));
      expect(Timing.promptAt(dec, settings), DateTime(2026, 11, 10, 10));
    });

    test('repeats step forward, across month ends', () {
      const daily = Reminder(repeat: RepeatKind.daily);
      const every3h = Reminder(
        repeat: RepeatKind.interval,
        intervalMinutes: 180,
      );
      expect(
        Timing.nextOccurrence(DateTime(2026, 1, 31, 8), daily),
        DateTime(2026, 2, 1, 8),
      );
      expect(
        Timing.nextOccurrence(DateTime(2026, 1, 1, 8), every3h),
        DateTime(2026, 1, 1, 11),
      );
      expect(Timing.nextOccurrence(DateTime(2026), null), isNull);
    });

    test('nextAfter skips occurrences already past', () {
      const daily = Reminder(repeat: RepeatKind.daily);
      expect(
        Timing.nextAfter(
          DateTime(2026, 11, 1, 8),
          daily,
          DateTime(2026, 11, 10, 12),
        ),
        DateTime(2026, 11, 11, 8),
      );
      // Ticked early: the next one after the current due time.
      expect(
        Timing.nextAfter(
          DateTime(2026, 11, 10, 8),
          daily,
          DateTime(2026, 11, 10, 7),
        ),
        DateTime(2026, 11, 11, 8),
      );
    });
  });

  group('planning', () {
    final now = DateTime(2026, 11, 10, 8);

    test('no reminder, no alerts', () {
      final b = board([n('a', date: '2026-11-10', time: '09:00')]);
      expect(AlertPlanner.plan(b, settings, now), isEmpty);
    });

    test('a task gets a heads-up and a "Done?" prompt', () {
      final b = board([
        n(
          'a',
          date: '2026-11-10',
          time: '09:00',
          reminder: const Reminder(leadMinutes: 30),
        ),
      ]);
      final alerts = AlertPlanner.plan(b, settings, now);
      expect(alerts.map((a) => a.payload.kind), [
        AlertKind.headsUp,
        AlertKind.prompt,
      ]);
      expect(alerts[0].at, DateTime(2026, 11, 10, 8, 30));
      expect(alerts[1].at, DateTime(2026, 11, 10, 9));
      expect(alerts[1].body, 'Done?');
    });

    test('a decision is asked about after the delay', () {
      final b = board([
        n(
          'd',
          type: NodeType.decision,
          date: '2026-11-10',
          time: '09:00',
          reminder: const Reminder(),
        ),
      ]);
      final alerts = AlertPlanner.plan(b, settings, now);
      expect(alerts.single.at, DateTime(2026, 11, 10, 10));
      expect(alerts.single.body, 'Which one of these did you do?');
    });

    test('past, done and eliminated nodes are skipped', () {
      const r = Reminder();
      final b = board([
        n('past', date: '2026-11-09', time: '09:00', reminder: r),
        n(
          'done',
          status: NodeStatus.done,
          date: '2026-11-10',
          time: '09:00',
          reminder: r,
        ),
        n(
          'gone',
          status: NodeStatus.eliminated,
          date: '2026-11-10',
          time: '09:00',
          reminder: r,
        ),
      ]);
      expect(AlertPlanner.plan(b, settings, now), isEmpty);
    });

    test('daily repeats are booked once and repeated by the system', () {
      final b = board([
        n(
          'a',
          date: '2026-11-01',
          time: '07:00',
          reminder: const Reminder(repeat: RepeatKind.daily),
        ),
      ]);
      final a = AlertPlanner.plan(b, settings, now).single;
      expect(a.recurrence, Recurrence.daily);
      expect(a.at, DateTime(2026, 11, 11, 7));
    });

    test('custom intervals book the next few, per the setting', () {
      final b = board([
        n(
          'a',
          date: '2026-11-10',
          time: '06:00',
          reminder: const Reminder(
            repeat: RepeatKind.interval,
            intervalMinutes: 120,
          ),
        ),
      ]);
      final alerts = AlertPlanner.plan(
        b,
        settings.copyWith(repeatsScheduledAhead: 3),
        now,
      );
      expect(alerts.map((a) => a.at), [
        DateTime(2026, 11, 10, 10),
        DateTime(2026, 11, 10, 12),
        DateTime(2026, 11, 10, 14),
      ]);
      expect(alerts.map((a) => a.id).toSet(), hasLength(3));
    });

    test('ids are stable and payloads round-trip', () {
      expect(
        AlertPlanner.alertId('b', 'n', AlertKind.prompt, 0),
        AlertPlanner.alertId('b', 'n', AlertKind.prompt, 0),
      );
      expect(
        AlertPlanner.alertId('b', 'n', AlertKind.prompt, 0),
        isNot(AlertPlanner.alertId('b', 'n', AlertKind.headsUp, 0)),
      );
      const p = AlertPayload(boardId: 'b', nodeId: 'n', kind: AlertKind.prompt);
      final back = AlertPayload.decode(p.encode())!;
      expect(
        (back.boardId, back.nodeId, back.kind),
        ('b', 'n', AlertKind.prompt),
      );
      expect(AlertPayload.decode('junk'), isNull);
    });
  });

  group('scheduler', () {
    test('sync books new alerts and cancels stale ones', () async {
      final platform = FakePlatform();
      final s = ReminderScheduler(
        platform: platform,
        settings: () => settings,
        clock: () => DateTime(2026, 11, 10, 8),
      );
      const r = Reminder();
      await s.syncBoard(
        board([
          n('a', date: '2026-11-10', time: '09:00', reminder: r),
          n('b', date: '2026-11-10', time: '10:00', reminder: r),
        ]),
      );
      expect(platform.booked, hasLength(2));

      await s.syncBoard(
        board([n('a', date: '2026-11-10', time: '09:00', reminder: r)]),
      );
      expect(platform.booked.values.single.payload.nodeId, 'a');

      await s.removeBoard('b1');
      expect(platform.booked, isEmpty);
    });

    test('syncAll drops alerts for boards that no longer exist', () async {
      final platform = FakePlatform();
      final s = ReminderScheduler(
        platform: platform,
        settings: () => settings,
        clock: () => DateTime(2026, 11, 10, 8),
      );
      const r = Reminder();
      await s.syncBoard(
        board([
          n('a', date: '2026-11-10', time: '09:00', reminder: r),
        ], id: 'x'),
      );
      await s.syncAll([
        board([n('a', date: '2026-11-10', time: '09:00', reminder: r)]),
      ]);
      expect(platform.booked.values.map((a) => a.payload.boardId), ['b1']);
    });
  });

  group('today', () {
    final now = DateTime(2026, 11, 10, 12);

    test('groups awaiting, overdue and later today; skips the rest', () {
      final b = board([
        n('asked', date: '2026-11-10', time: '09:00'),
        n('overdue', date: '2026-11-08'),
        n('later', date: '2026-11-10', time: '18:00'),
        n('allday', date: '2026-11-10'),
        n('tomorrow', date: '2026-11-11'),
        n('done', date: '2026-11-10', status: NodeStatus.done),
        n('undated'),
      ]);
      final items = TodayList.build([b], settings, now);
      expect(items.map((i) => (i.node.id, i.group)), [
        ('asked', TodayGroup.awaiting),
        ('overdue', TodayGroup.overdue),
        ('allday', TodayGroup.today),
        ('later', TodayGroup.today),
      ]);
    });

    test('a decision awaits only after its delay', () {
      final b = board([
        n('d', type: NodeType.decision, date: '2026-11-10', time: '11:30'),
      ]);
      expect(
        TodayList.build([b], settings, now).single.group,
        TodayGroup.today,
      );
      expect(
        TodayList.build(
          [b],
          settings,
          DateTime(2026, 11, 10, 12, 30),
        ).single.group,
        TodayGroup.awaiting,
      );
    });
  });
}
