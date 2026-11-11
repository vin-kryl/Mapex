import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/node.dart';
import '../model/tree_ops.dart';
import '../reminders/timing.dart';
import '../state/board_editor.dart';
import '../state/providers.dart';
import 'shell/shell_scope.dart';
import 'theme.dart';

/// Asks "Done?" for a task or "Which one of these did you do?" for a
/// decision. "Not yet" is always offered, with a quick reschedule.
Future<void> showPromptSheet(
  BuildContext context,
  WidgetRef ref, {
  required String boardId,
  required String nodeId,
}) async {
  final editorProvider = boardEditorProvider(boardId);
  final state = await ref.read(editorProvider.future);
  final node = TreeOps.find(state.board.root, nodeId);
  if (node == null || !context.mounted) return;
  final answer = await showModalBottomSheet<_Answer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PromptSheet(node: node, boardTitle: state.board.title),
  );
  if (answer == null || !context.mounted) return;
  final editor = ref.read(editorProvider.notifier);
  switch (answer) {
    case _Done():
      editor.answerDone(node.id);
    case _Picked(:final ids):
      editor.decide(node.id, ids);
      final board = ref.read(editorProvider).requireValue.board;
      final steps = [
        for (final id in ids) ...?TreeOps.find(board.root, id)?.children,
      ];
      if (context.mounted) {
        await _showNextSteps(context, boardId: boardId, steps: steps);
      }
    case _NotYet():
      final when = await _pickReschedule(
        context,
        snoozeMinutes: ref.read(settingsProvider).snoozeMinutes,
        from: Timing.dueAt(node),
      );
      if (when != null) editor.snooze(node.id, when);
  }
}

sealed class _Answer {}

class _Done extends _Answer {}

class _NotYet extends _Answer {}

class _Picked extends _Answer {
  _Picked(this.ids);

  final Set<String> ids;
}

class _PromptSheet extends StatefulWidget {
  const _PromptSheet({required this.node, required this.boardTitle});

  final Node node;
  final String boardTitle;

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  final Set<String> _picked = {};

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final decision = n.type == NodeType.decision;
    final options = [
      for (final c in n.children)
        if (c.status != NodeStatus.eliminated || decision) c,
    ];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Metrics.gutter,
        0,
        Metrics.gutter,
        Metrics.gutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.boardTitle, style: TextStyle(color: muted)),
          const SizedBox(height: 4),
          Text(n.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Metrics.gap),
          Text(
            decision ? 'Which one of these did you do?' : 'Done?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Metrics.gap / 2),
          if (decision)
            for (final c in options)
              CheckboxListTile(
                value: _picked.contains(c.id),
                title: Text(c.title),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(
                  () => v == true ? _picked.add(c.id) : _picked.remove(c.id),
                ),
              ),
          if (decision && options.isEmpty)
            Text(
              'This decision has no alternatives yet.',
              style: TextStyle(color: muted),
            ),
          const SizedBox(height: Metrics.gap),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.of(context).pop(_NotYet()),
                  child: const Text('Not yet'),
                ),
              ),
              const SizedBox(width: Metrics.gap),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: decision
                      ? (_picked.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(_Picked(_picked)))
                      : () => Navigator.of(context).pop(_Done()),
                  child: Text(decision ? 'Save' : 'Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// +snooze, tomorrow at the same time, or any date and time.
Future<DateTime?> _pickReschedule(
  BuildContext context, {
  required int snoozeMinutes,
  required DateTime? from,
}) async {
  final now = DateTime.now();
  final base = from != null && from.isAfter(now) ? from : now;
  final soon = now.add(Duration(minutes: snoozeMinutes));
  final tomorrow = DateTime(
    now.year,
    now.month,
    now.day + 1,
    base.hour,
    base.minute,
  );
  final loc = MaterialLocalizations.of(context);
  String snoozeLabel() {
    if (snoozeMinutes % 1440 == 0) {
      final d = snoozeMinutes ~/ 1440;
      return d == 1 ? 'In 1 day' : 'In $d days';
    }
    if (snoozeMinutes % 60 == 0) {
      final h = snoozeMinutes ~/ 60;
      return h == 1 ? 'In 1 hour' : 'In $h hours';
    }
    return 'In $snoozeMinutes minutes';
  }

  final choice = await showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.snooze),
          title: Text(snoozeLabel()),
          subtitle: Text(loc.formatTimeOfDay(TimeOfDay.fromDateTime(soon))),
          onTap: () => Navigator.of(context).pop(0),
        ),
        ListTile(
          leading: const Icon(Icons.wb_sunny_outlined),
          title: const Text('Tomorrow'),
          subtitle: Text(loc.formatTimeOfDay(TimeOfDay.fromDateTime(tomorrow))),
          onTap: () => Navigator.of(context).pop(1),
        ),
        ListTile(
          leading: const Icon(Icons.event),
          title: const Text('Pick a date'),
          onTap: () => Navigator.of(context).pop(2),
        ),
        const SizedBox(height: Metrics.gap),
      ],
    ),
  );
  if (!context.mounted) return null;
  switch (choice) {
    case 0:
      return soon;
    case 1:
      return tomorrow;
    case 2:
      final date = await showDatePicker(
        context: context,
        initialDate: tomorrow,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 20),
      );
      if (date == null || !context.mounted) return null;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(base),
      );
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    default:
      return null;
  }
}

/// After a decision: the picked paths' children are what comes next.
Future<void> _showNextSteps(
  BuildContext context, {
  required String boardId,
  required List<Node> steps,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(
        Metrics.gutter,
        0,
        Metrics.gutter,
        Metrics.gutter,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your next steps',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Metrics.gap / 2),
          if (steps.isEmpty)
            Text(
              'Nothing planned under this path yet. Open the board to add '
              'the next steps.',
              style: TextStyle(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
          for (final s in steps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.arrow_forward),
              title: Text(s.title),
              onTap: () {
                Navigator.of(sheetContext).pop();
                openBoardAt(context, boardId: boardId, nodeId: s.id);
              },
            ),
          const SizedBox(height: Metrics.gap),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () {
              Navigator.of(sheetContext).pop();
              openBoardAt(context, boardId: boardId);
            },
            child: const Text('Open board'),
          ),
        ],
      ),
    ),
  );
}
