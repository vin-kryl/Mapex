import '../model/board.dart';
import '../settings/app_settings.dart';
import 'alert_platform.dart';
import 'plan.dart';

/// Keeps the system's booked notifications in line with the boards.
class ReminderScheduler {
  ReminderScheduler({
    required this.platform,
    required this.settings,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AlertPlatform platform;
  final AppSettings Function() settings;
  final DateTime Function() _clock;

  Future<void> _queue = Future.value();

  /// Runs jobs one at a time so two quick saves cannot interleave.
  Future<void> _serial(Future<void> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.catchError((Object _) {});
    return next;
  }

  /// Replaces every booked notification of [board] with a fresh plan.
  Future<void> syncBoard(Board board) => _serial(() async {
    final s = settings();
    final planned = AlertPlanner.plan(
      board,
      s,
      _clock(),
      nativeRepeats: platform.repeatsNatively,
    );
    await _cancelBoard(board.id, keep: {for (final a in planned) a.id});
    for (final alert in planned) {
      await platform.schedule(alert, sound: s.notificationSound);
    }
  });

  /// Cancels everything for a board (moved to trash or deleted).
  Future<void> removeBoard(String boardId) =>
      _serial(() => _cancelBoard(boardId, keep: const {}));

  /// Re-plans every board, and drops alerts for boards that no longer exist.
  Future<void> syncAll(Iterable<Board> boards) async {
    final ids = {for (final b in boards) b.id};
    await _serial(() async {
      for (final p in await platform.pending()) {
        final boardId = p.payload?.boardId;
        if (boardId == null || !ids.contains(boardId)) {
          await platform.cancel(p.id);
        }
      }
    });
    for (final b in boards) {
      await syncBoard(b);
    }
  }

  Future<void> _cancelBoard(String boardId, {required Set<int> keep}) async {
    for (final p in await platform.pending()) {
      if (p.payload?.boardId == boardId && !keep.contains(p.id)) {
        await platform.cancel(p.id);
      }
    }
  }
}
