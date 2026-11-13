import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/node.dart';
import '../reminders/timing.dart';
import '../reminders/today.dart';
import '../state/providers.dart';
import 'board/node_card.dart';
import 'prompt_sheet.dart';
import 'shell/shell_scope.dart';
import 'theme.dart';
import 'widgets.dart';

/// What needs attention today, across every board.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, this.embedded = false});

  /// Shown in the desktop window's main pane.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(allBoardsProvider);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: embedded
          ? AppBar(
              toolbarHeight: 52,
              titleSpacing: 20,
              automaticallyImplyLeading: false,
              title: const Text('Today'),
            )
          : null,
      body: boards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => QuietMessage(text: 'Could not read boards.\n$e'),
        data: (boards) {
          final items = TodayList.build(boards, settings, DateTime.now());
          final groups = <TodayGroup, List<TodayItem>>{};
          for (final item in items) {
            groups.putIfAbsent(item.group, () => []).add(item);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allBoardsProvider),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                embedded ? 36 : 20,
                embedded ? 20 : MediaQuery.paddingOf(context).top + 24,
                embedded ? 36 : 20,
                Metrics.gutter * 2,
              ),
              children: [
                if (!embedded) ...[
                  Text('Today', style: largeTitle(context)),
                  const SizedBox(height: 20),
                ],
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: QuietMessage(
                      icon: Icons.wb_sunny_outlined,
                      text:
                          'Nothing due today.\n'
                          'Give any step a date to see it here.',
                    ),
                  ),
                for (final e in groups.entries) ...[
                  Section(
                    title: switch (e.key) {
                      TodayGroup.awaiting => 'Waiting for your answer',
                      TodayGroup.overdue => 'Overdue',
                      TodayGroup.today => 'Later today',
                    },
                    child: GroupedBox(
                      children: [for (final i in e.value) TodayRow(item: i)],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One thing due: its status mark, title, board and time. Tapping answers
/// it if it is waiting, else opens it on its board.
class TodayRow extends ConsumerWidget {
  const TodayRow({super.key, required this.item});

  final TodayItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = item.node;
    final t = Tones.of(context);
    final loc = MaterialLocalizations.of(context);
    final due = Timing.dueAt(n);
    final day = Timing.day(n)!;
    final when = [
      if (!DateUtils.isSameDay(day, DateTime.now()))
        loc.formatShortMonthDay(day),
      if (due != null) loc.formatTimeOfDay(TimeOfDay.fromDateTime(due)),
    ].join(', ');
    final awaiting = item.group == TodayGroup.awaiting;
    return InkWell(
      onTap: () async {
        if (awaiting) {
          await showPromptSheet(
            context,
            ref,
            boardId: item.boardId,
            nodeId: n.id,
          );
          ref.invalidate(allBoardsProvider);
        } else {
          openBoardAt(context, boardId: item.boardId, nodeId: n.id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            SizedBox(width: 20, child: StatusMark(node: n)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isApple ? 13.5 : 15,
                      fontWeight: FontWeight.w500,
                      color: t.text,
                    ),
                  ),
                  Text(
                    item.boardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (awaiting)
              Text(
                n.type == NodeType.decision ? 'Decide' : 'Answer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            else if (when.isNotEmpty)
              Text(
                when,
                style: TextStyle(
                  fontSize: 13,
                  color: item.group == TodayGroup.overdue
                      ? Palette.danger
                      : t.secondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
