import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/node.dart';
import '../../model/tree_ops.dart';
import '../../reminders/permission.dart';
import '../../state/board_editor.dart';
import '../../state/providers.dart';
import '../dialogs.dart';
import '../theme.dart';
import 'canvas_view.dart';
import 'node_sheets.dart';
import 'node_style.dart';
import 'voice_notes.dart';
import 'outline_view.dart';

enum BoardView { canvas, outline }

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({
    super.key,
    required this.boardId,
    this.initialNodeId,
    this.embedded = false,
  });

  final String boardId;

  /// Shown inside the desktop window beside the sidebar, not as its own page.
  final bool embedded;

  /// Wide enough for the inspector beside the board.
  static const inspectorBreakpoint = 900.0;

  /// Opens with this node selected and its branch expanded.
  final String? initialNodeId;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  BoardView _view = BoardView.canvas;
  late String? _selectedId = widget.initialNodeId;
  bool _revealed = false;

  /// Focus mode: show only this node's branch.
  String? _focusId;

  /// Whether the inspector beside the board is open on wide screens.
  bool _inspector = true;

  BoardEditor get _editor =>
      ref.read(boardEditorProvider(widget.boardId).notifier);

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(boardEditorProvider(widget.boardId));
    final direction = ref.watch(settingsProvider).layoutDirection;
    return editor.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not open board.\n$e')),
      ),
      data: (s) {
        if (!_revealed && widget.initialNodeId != null) {
          _revealed = true;
          final id = widget.initialNodeId!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _editor.reveal(id);
          });
        }
        final root = s.board.root;
        final focus = _focusId == null ? null : TreeOps.find(root, _focusId!);
        final shown = focus ?? root;
        final selected = _selectedId == null
            ? null
            : TreeOps.find(shown, _selectedId!);
        final wide =
            MediaQuery.sizeOf(context).width >= BoardScreen.inspectorBreakpoint;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
                _editor.undo,
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                _editor.undo,
            const SingleActivator(
              LogicalKeyboardKey.keyZ,
              meta: true,
              shift: true,
            ): _editor.redo,
            const SingleActivator(
              LogicalKeyboardKey.keyZ,
              control: true,
              shift: true,
            ): _editor.redo,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: !widget.embedded,
                toolbarHeight: widget.embedded ? 52 : null,
                titleSpacing: widget.embedded ? 20 : null,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.board.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      NodeStyle.progress(root),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: Tones.of(context).secondary,
                      ),
                    ),
                  ],
                ),
                actions: [
                  _ViewSwitch(
                    view: _view,
                    onChanged: (v) => setState(() => _view = v),
                  ),
                  const SizedBox(width: 8),
                  _ToolButton(
                    tooltip: s.canUndo ? 'Undo ${s.undoLabel}' : 'Undo',
                    icon: Icons.undo_rounded,
                    onPressed: s.canUndo ? _editor.undo : null,
                  ),
                  _ToolButton(
                    tooltip: s.canRedo ? 'Redo ${s.redoLabel}' : 'Redo',
                    icon: Icons.redo_rounded,
                    onPressed: s.canRedo ? _editor.redo : null,
                  ),
                  if (_view == BoardView.canvas)
                    _ToolButton(
                      tooltip: 'Tidy up',
                      icon: Icons.format_align_left_rounded,
                      onPressed: _editor.tidyUp,
                    ),
                  if (wide) ...[
                    _ToolButton(
                      tooltip: 'Add a step',
                      icon: Icons.add_rounded,
                      onPressed: () => _addChild(selected ?? shown),
                    ),
                    _ToolButton(
                      tooltip: _inspector ? 'Hide inspector' : 'Show inspector',
                      icon: Icons.view_sidebar_outlined,
                      selected: _inspector,
                      onPressed: () => setState(() => _inspector = !_inspector),
                    ),
                  ],
                  const SizedBox(width: Metrics.gutter / 2),
                ],
              ),
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (focus != null)
                          _FocusBar(
                            path: [
                              for (final id in TreeOps.pathTo(root, focus.id))
                                TreeOps.find(root, id)!,
                            ],
                            onPick: (id) => setState(
                              () => _focusId = id == root.id ? null : id,
                            ),
                          ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => setState(() => _selectedId = null),
                            child: _view == BoardView.canvas
                                ? CanvasView(
                                    root: root,
                                    shown: shown,
                                    direction: direction,
                                    selectedId: selected?.id,
                                    onTap: _onTap,
                                    onLongPress: (n) => _onLongPress(n, root),
                                    onToggleCollapse: _toggle,
                                    onPlace: _editor.place,
                                    onDropOn: _editor.dropOn,
                                  )
                                : OutlineView(
                                    root: shown,
                                    selectedId: selected?.id,
                                    onTap: _onTap,
                                    onLongPress: (n) => _onLongPress(n, root),
                                    onToggleCollapse: _toggle,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wide && _inspector)
                    _Inspector(
                      boardId: widget.boardId,
                      node: selected,
                      root: root,
                      onAdd: _addChild,
                      onDone: _toggleDone,
                      onDecide: _decide,
                      onMore: (n) => _onLongPress(n, root),
                      onSave: _save,
                    ),
                ],
              ),
              bottomNavigationBar: selected == null || wide
                  ? null
                  : _ActionBar(
                      node: selected,
                      onAdd: () => _addChild(selected),
                      onEdit: () => _edit(selected),
                      onDone: () => _toggleDone(selected),
                      onDecide: () => _decide(selected),
                      onMore: () => _onLongPress(selected, root),
                    ),
            ),
          ),
        );
      },
    );
  }

  /// Tap selects; tapping the selected node again opens its editor. With
  /// the inspector open the editor is already showing.
  void _onTap(Node node) {
    final wide =
        MediaQuery.sizeOf(context).width >= BoardScreen.inspectorBreakpoint;
    if (_selectedId == node.id && !(wide && _inspector)) {
      _edit(node);
    } else {
      setState(() => _selectedId = node.id);
    }
  }

  void _toggle(Node node) => _editor.setCollapsed(node.id, !node.collapsed);

  Future<void> _addChild(Node parent) async {
    final title = await askForTitle(
      context,
      heading: 'New step under "${parent.title}"',
      action: 'Add',
    );
    if (title == null) return;
    final id = _editor.addChild(parent.id, title);
    setState(() => _selectedId = id);
  }

  Future<void> _edit(Node node) async {
    final result = await showEditSheet(
      context,
      node,
      defaultLeadMinutes: ref.read(settingsProvider).defaultReminderLeadMinutes,
      voiceNotes: VoiceNotesSection(boardId: widget.boardId, nodeId: node.id),
    );
    if (result == null) return;
    await _save(node, result);
  }

  Future<void> _save(Node node, NodeEdit result) async {
    if (result.when.reminder != null && node.reminder == null) {
      await askForRemindersOnce(ref);
    }
    _editor.editNode(
      node.id,
      title: result.title,
      notes: result.notes,
      status: result.status,
      color: result.color,
      tags: result.tags,
      setWhen: true,
      date: result.when.date,
      time: result.when.timeAsDateTime,
      reminder: result.when.reminder,
    );
  }

  void _toggleDone(Node node) => _editor.setStatus(
    node.id,
    node.status == NodeStatus.done ? NodeStatus.pending : NodeStatus.done,
  );

  Future<void> _decide(Node node) async {
    if (node.children.isEmpty) {
      showMessage(context, 'Add the alternatives first.');
      return;
    }
    final picked = await showDecideSheet(context, node);
    if (picked == null) return;
    _editor.decide(node.id, picked);
  }

  Future<void> _onLongPress(Node node, Node root) async {
    final parent = TreeOps.parentOf(root, node.id);
    final siblings = parent?.children ?? const <Node>[];
    final action = await showNodeMenu(
      context,
      node,
      isRoot: parent == null,
      isFirst: siblings.isEmpty || siblings.first.id == node.id,
      isLast: siblings.isEmpty || siblings.last.id == node.id,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case NodeAction.moveUp:
        _editor.reorder(node.id, -1);
      case NodeAction.moveDown:
        _editor.reorder(node.id, 1);
      case NodeAction.move:
        final target = await showMovePicker(
          context,
          TreeOps.moveTargets(root, node.id),
        );
        if (target != null) _editor.move(node.id, target);
      case NodeAction.toTask:
        _editor.changeType(node.id, NodeType.task);
      case NodeAction.toDecision:
        _editor.changeType(node.id, NodeType.decision);
      case NodeAction.reopen:
        _editor.reopen(node.id);
      case NodeAction.focus:
        setState(() => _focusId = node.id);
      case NodeAction.delete:
        final count = node.nodeCount;
        final ok = await confirm(
          context,
          heading: 'Delete "${node.title}"?',
          message: count > 1
              ? 'This deletes it and the ${count - 1} steps under it. '
                    'You can undo this.'
              : 'You can undo this.',
          action: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        _editor.delete(node.id);
        setState(() {
          if (_selectedId == node.id) _selectedId = null;
          if (_focusId == node.id) _focusId = null;
        });
    }
  }
}

class _FocusBar extends StatelessWidget {
  const _FocusBar({required this.path, required this.onPick});

  final List<Node> path;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: Metrics.gutter / 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: [
            for (var i = 0; i < path.length; i++) ...[
              if (i > 0)
                Icon(Icons.chevron_right, size: 18, color: scheme.outline),
              TextButton(
                onPressed: i == path.length - 1
                    ? null
                    : () => onPick(path[i].id),
                child: Text(path[i].title),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thumb-reach actions for the selected node.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.node,
    required this.onAdd,
    required this.onEdit,
    required this.onDone,
    required this.onDecide,
    required this.onMore,
  });

  final Node node;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onDone;
  final VoidCallback onDecide;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eliminated = node.status == NodeStatus.eliminated;
    Widget action(IconData icon, String label, VoidCallback? onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Look.of(context).radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: Metrics.gutter / 2),
        child: Row(
          children: [
            action(Icons.add_circle_outline, 'Add', onAdd),
            action(Icons.edit_outlined, 'Edit', onEdit),
            if (node.type == NodeType.decision)
              action(Icons.call_split, 'Decide', eliminated ? null : onDecide)
            else
              action(
                node.status == NodeStatus.done
                    ? Icons.remove_done
                    : Icons.check_circle_outline,
                node.status == NodeStatus.done ? 'Undone' : 'Done',
                eliminated ? null : onDone,
              ),
            action(Icons.more_horiz, 'More', onMore),
          ],
        ),
      ),
    );
  }
}

/// Canvas or outline, as a small segmented switch.
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.view, required this.onChanged});

  final BoardView view;
  final ValueChanged<BoardView> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    Widget item(BoardView v, IconData icon, String tip) {
      final on = v == view;
      return Tooltip(
        message: tip,
        child: InkWell(
          onTap: () => onChanged(v),
          borderRadius: BorderRadius.circular(5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 24,
            decoration: BoxDecoration(
              color: on ? t.card : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 1.5,
                        offset: const Offset(0, 0.5),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, size: 16, color: on ? t.text : t.secondary),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.hairline,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(BoardView.canvas, Icons.account_tree_outlined, 'Tree view'),
          item(BoardView.outline, Icons.format_list_bulleted, 'Outline view'),
        ],
      ),
    );
  }
}

/// A quiet toolbar icon button.
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      color: selected ? t.text : t.secondary,
      disabledColor: t.tertiary,
      style: IconButton.styleFrom(
        backgroundColor: selected ? t.hairline : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        minimumSize: const Size(34, 30),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// The panel beside the board on wide screens: every field of the selected
/// node, ready to edit, and its main actions.
class _Inspector extends ConsumerWidget {
  const _Inspector({
    required this.boardId,
    required this.node,
    required this.root,
    required this.onAdd,
    required this.onDone,
    required this.onDecide,
    required this.onMore,
    required this.onSave,
  });

  final String boardId;
  final Node? node;
  final Node root;
  final ValueChanged<Node> onAdd;
  final ValueChanged<Node> onDone;
  final ValueChanged<Node> onDecide;
  final ValueChanged<Node> onMore;
  final void Function(Node node, NodeEdit edit) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Tones.of(context);
    final n = node;
    final parent = n == null ? null : TreeOps.parentOf(root, n.id);
    return Container(
      width: Metrics.inspectorWidth,
      decoration: BoxDecoration(
        color: t.grouped,
        border: Border(left: BorderSide(color: t.hairline, width: 0.5)),
      ),
      child: n == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Metrics.gutter * 2),
                child: Text(
                  'Select a node to see its details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.secondary),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          parent == null
                              ? NodeStyle.typeLabel(n.type)
                              : '${NodeStyle.typeLabel(n.type)} in '
                                    '${parent.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: sectionLabel(context),
                        ),
                      ),
                      IconButton(
                        tooltip: 'More',
                        icon: const Icon(Icons.more_horiz_rounded, size: 20),
                        color: t.secondary,
                        onPressed: () => onMore(n),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: NodeForm(
                    key: ValueKey('${n.id}/${n.updatedAt}'),
                    node: n,
                    defaultLeadMinutes: ref
                        .read(settingsProvider)
                        .defaultReminderLeadMinutes,
                    voiceNotes: VoiceNotesSection(
                      boardId: boardId,
                      nodeId: n.id,
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    onSave: (edit) => onSave(n, edit),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: t.hairline, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onAdd(n),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add step'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: n.type == NodeType.decision
                            ? OutlinedButton.icon(
                                onPressed: n.status == NodeStatus.eliminated
                                    ? null
                                    : () => onDecide(n),
                                icon: const Icon(
                                  Icons.call_split_rounded,
                                  size: 18,
                                ),
                                label: const Text('Decide'),
                              )
                            : OutlinedButton.icon(
                                onPressed: n.status == NodeStatus.eliminated
                                    ? null
                                    : () => onDone(n),
                                icon: Icon(
                                  n.status == NodeStatus.done
                                      ? Icons.remove_done_rounded
                                      : Icons.check_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  n.status == NodeStatus.done
                                      ? 'Not done'
                                      : 'Done',
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
