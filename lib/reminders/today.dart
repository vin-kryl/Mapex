import '../model/board.dart';
import '../model/node.dart';
import '../model/tree_ops.dart';
import '../settings/app_settings.dart';
import 'timing.dart';

enum TodayGroup {
  /// Its time has come and it still needs a "Done?" or "Which one?" answer.
  awaiting,

  /// Its day has passed and it is still open.
  overdue,

  /// Due later today.
  today,
}

class TodayItem {
  const TodayItem({
    required this.group,
    required this.boardId,
    required this.boardTitle,
    required this.node,
    required this.sortKey,
  });

  final TodayGroup group;
  final String boardId;
  final String boardTitle;
  final Node node;
  final DateTime sortKey;
}

/// Everything due today, overdue, or awaiting an answer, across boards.
abstract final class TodayList {
  static List<TodayItem> build(
    Iterable<Board> boards,
    AppSettings settings,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final items = <TodayItem>[];
    for (final board in boards) {
      for (final (:node, depth: _) in TreeOps.walk(board.root)) {
        if (!Timing.isOpen(node)) continue;
        final day = Timing.day(node);
        if (day == null) continue;
        final prompt = Timing.promptAt(node, settings);
        final TodayGroup? group;
        if (prompt != null && !prompt.isAfter(now)) {
          group = TodayGroup.awaiting;
        } else if (day.isBefore(today)) {
          group = TodayGroup.overdue;
        } else if (day == today) {
          group = TodayGroup.today;
        } else {
          group = null;
        }
        if (group == null) continue;
        items.add(
          TodayItem(
            group: group,
            boardId: board.id,
            boardTitle: board.title,
            node: node,
            sortKey: Timing.dueAt(node) ?? day,
          ),
        );
      }
    }
    items.sort((a, b) {
      final g = a.group.index.compareTo(b.group.index);
      return g != 0 ? g : a.sortKey.compareTo(b.sortKey);
    });
    return items;
  }
}
