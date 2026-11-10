import 'package:flutter/material.dart';

import '../../model/node.dart';
import '../theme.dart';
import 'node_style.dart';
import 'when_editor.dart';

/// What the edit sheet returns.
class NodeEdit {
  const NodeEdit({
    required this.title,
    required this.notes,
    required this.status,
    required this.color,
    required this.tags,
    required this.when,
  });

  final String title;
  final String notes;
  final NodeStatus status;
  final String? color;
  final List<String> tags;
  final WhenValue when;
}

Future<NodeEdit?> showEditSheet(
  BuildContext context,
  Node node, {
  required int defaultLeadMinutes,
  Widget? voiceNotes,
}) {
  return showModalBottomSheet<NodeEdit>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _EditSheet(
      node: node,
      defaultLeadMinutes: defaultLeadMinutes,
      voiceNotes: voiceNotes,
    ),
  );
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({
    required this.node,
    required this.defaultLeadMinutes,
    this.voiceNotes,
  });

  final Node node;
  final int defaultLeadMinutes;
  final Widget? voiceNotes;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _title = TextEditingController(text: widget.node.title);
  late final _notes = TextEditingController(text: widget.node.notes);
  final _tag = TextEditingController();
  late NodeStatus _status = widget.node.status;
  late String? _color = widget.node.color;
  late final List<String> _tags = [...widget.node.tags];
  late WhenValue _when = WhenValue.of(widget.node);

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _addTag() {
    final t = _tag.text.trim();
    if (t.isNotEmpty && !_tags.contains(t)) setState(() => _tags.add(t));
    _tag.clear();
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      NodeEdit(
        title: _title.text.trim(),
        notes: _notes.text,
        status: _status,
        color: _color,
        tags: _tags,
        when: _when,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eliminated = widget.node.status == NodeStatus.eliminated;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Metrics.gutter,
          0,
          Metrics.gutter,
          Metrics.gutter,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Notes'),
            ),
            if (widget.voiceNotes case final voice?) ...[
              const SizedBox(height: Metrics.gap),
              voice,
            ],
            const SizedBox(height: Metrics.gutter),
            if (!eliminated && widget.node.type == NodeType.task)
              SegmentedButton<NodeStatus>(
                showSelectedIcon: false,
                segments: [
                  for (final s in [
                    NodeStatus.pending,
                    NodeStatus.done,
                    NodeStatus.notYet,
                  ])
                    ButtonSegment(
                      value: s,
                      label: Text(NodeStyle.statusLabel(s)),
                    ),
                ],
                selected: {_status},
                onSelectionChanged: (v) => setState(() => _status = v.first),
              ),
            const SizedBox(height: Metrics.gutter),
            WhenEditor(
              value: _when,
              defaultLeadMinutes: widget.defaultLeadMinutes,
              onChanged: (w) => setState(() => _when = w),
            ),
            const SizedBox(height: Metrics.gutter),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Swatch(
                  color: null,
                  selected: _color == null,
                  onTap: () => setState(() => _color = null),
                ),
                for (final c in Palette.accents)
                  _Swatch(
                    color: c,
                    selected: _color == NodeStyle.toHex(c),
                    onTap: () => setState(() => _color = NodeStyle.toHex(c)),
                  ),
              ],
            ),
            const SizedBox(height: Metrics.gutter),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final t in _tags)
                  InputChip(
                    label: Text(t),
                    onDeleted: () => setState(() => _tags.remove(t)),
                  ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _tag,
                    decoration: const InputDecoration(
                      hintText: 'Add tag',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Metrics.gutter * 1.5),
            FilledButton(
              onPressed: _title.text.trim().isEmpty ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: scheme.primary,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: color == null ? 'No colour' : 'Colour',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color ?? scheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: color == null
              ? Icon(Icons.block, size: 16, color: scheme.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }
}

/// Lets the user pick which alternatives were taken. Returns the picked ids
/// (possibly empty for "none yet"), or null when cancelled.
Future<Set<String>?> showDecideSheet(BuildContext context, Node decision) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _DecideSheet(decision: decision),
  );
}

class _DecideSheet extends StatefulWidget {
  const _DecideSheet({required this.decision});

  final Node decision;

  @override
  State<_DecideSheet> createState() => _DecideSheetState();
}

class _DecideSheetState extends State<_DecideSheet> {
  late final Set<String> _picked = {...widget.decision.chosenChildIds};

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Which of these did you do?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Pick one or more. The rest are greyed out and kept.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Metrics.gap),
          for (final c in widget.decision.children)
            CheckboxListTile(
              value: _picked.contains(c.id),
              title: Text(c.title),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(
                () => v == true ? _picked.add(c.id) : _picked.remove(c.id),
              ),
            ),
          const SizedBox(height: Metrics.gap),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.of(context).pop(<String>{}),
                  child: const Text('None yet'),
                ),
              ),
              const SizedBox(width: Metrics.gap),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _picked.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_picked),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum NodeAction {
  moveUp,
  moveDown,
  move,
  toTask,
  toDecision,
  reopen,
  focus,
  delete,
}

/// The long-press menu.
Future<NodeAction?> showNodeMenu(
  BuildContext context,
  Node node, {
  required bool isRoot,
  required bool isFirst,
  required bool isLast,
}) {
  ListTile item(NodeAction a, IconData icon, String label) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    onTap: () => Navigator.of(context).pop(a),
  );
  return showModalBottomSheet<NodeAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.status == NodeStatus.eliminated)
            item(NodeAction.reopen, Icons.undo, 'Reopen'),
          if (!isRoot && !isFirst)
            item(NodeAction.moveUp, Icons.arrow_upward, 'Move up'),
          if (!isRoot && !isLast)
            item(NodeAction.moveDown, Icons.arrow_downward, 'Move down'),
          if (!isRoot)
            item(NodeAction.move, Icons.drive_file_move_outline, 'Move to…'),
          if (node.type == NodeType.task)
            item(NodeAction.toDecision, Icons.call_split, 'Make it a decision')
          else
            item(NodeAction.toTask, Icons.checklist, 'Make it a task'),
          if (node.children.isNotEmpty)
            item(
              NodeAction.focus,
              Icons.center_focus_strong,
              'Focus on branch',
            ),
          if (!isRoot) item(NodeAction.delete, Icons.delete_outline, 'Delete'),
          const SizedBox(height: Metrics.gap),
        ],
      ),
    ),
  );
}

/// Pick a new parent. Returns its id.
Future<String?> showMovePicker(BuildContext context, List<Node> targets) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, scroll) => ListView(
        controller: scroll,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Metrics.gutter,
              0,
              Metrics.gutter,
              Metrics.gap,
            ),
            child: Text(
              'Move under…',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          for (final t in targets)
            ListTile(
              leading: Icon(NodeStyle.statusIcon(t)),
              title: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(t.id),
            ),
        ],
      ),
    ),
  );
}
