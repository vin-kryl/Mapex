import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/node.dart';
import '../reminders/timing.dart';
import '../reminders/today.dart';
import '../state/providers.dart';
import 'board/node_style.dart';
import 'prompt_sheet.dart';
import 'theme.dart';

/// The start screen: what needs attention today, across every board.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(allBoardsProvider);
    final settings = ref.watch(settingsProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: boards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not read boards.\n$e')),
        data: (boards) {
          final items = TodayList.build(boards, settings, DateTime.now());
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Metrics.gutter * 2),
                child: Text(
                  'Nothing due today.\nAdd a date to any node to see it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: muted),
                ),
              ),
            );
          }
          final children = <Widget>[];
          TodayGroup? group;
          for (final item in items) {
            if (item.group != group) {
              group = item.group;
              children.add(_Header(group: group));
            }
            children.add(_ItemTile(item: item));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allBoardsProvider),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Metrics.maxContentWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Metrics.gutter,
                    0,
                    Metrics.gutter,
                    Metrics.gutter * 2,
                  ),
                  children: children,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.group});

  final TodayGroup group;

  @override
  Widget build(BuildContext context) {
    final text = switch (group) {
      TodayGroup.awaiting => 'Waiting for your answer',
      TodayGroup.overdue => 'Overdue',
      TodayGroup.today => 'Later today',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, Metrics.gutter, 4, Metrics.gap / 2),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item});

  final TodayItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = item.node;
    final scheme = Theme.of(context).colorScheme;
    final loc = MaterialLocalizations.of(context);
    final due = Timing.dueAt(n);
    final day = Timing.day(n)!;
    final when = [
      if (item.group == TodayGroup.overdue ||
          (item.group == TodayGroup.awaiting &&
              !DateUtils.isSameDay(day, DateTime.now())))
        loc.formatShortMonthDay(day),
      if (due != null) loc.formatTimeOfDay(TimeOfDay.fromDateTime(due)),
    ].join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: Metrics.gap / 2),
      child: Card(
        child: ListTile(
          leading: Icon(
            NodeStyle.statusIcon(n),
            color: NodeStyle.statusColor(n, scheme),
          ),
          title: Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [item.boardTitle, if (when.isNotEmpty) when].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: item.group == TodayGroup.awaiting
              ? Text(
                  n.type == NodeType.decision ? 'Decide' : 'Answer',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : const Icon(Icons.chevron_right),
          onTap: () async {
            if (item.group == TodayGroup.awaiting) {
              await showPromptSheet(
                context,
                ref,
                boardId: item.boardId,
                nodeId: n.id,
              );
            } else {
              openBoardAt(context, boardId: item.boardId, nodeId: n.id);
            }
          },
        ),
      ),
    );
  }
}
