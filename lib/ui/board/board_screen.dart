import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/node.dart';
import '../../model/tree_ops.dart';
import '../../state/board_editor.dart';
import '../../state/providers.dart';
import '../dialogs.dart';
import '../theme.dart';
import 'canvas_view.dart';
import 'node_sheets.dart';
import 'outline_view.dart';

enum BoardView { canvas, outline }

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.boardId});

  final String boardId;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  BoardView _view = BoardView.canvas;
  String? _selectedId;

  /// Focus mode: show only this node's branch.
  String? _focusId;

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
        final root = s.board.root;
        final focus = _focusId == null ? null : TreeOps.find(root, _focusId!);
        final shown = focus ?? root;
        final selected = _selectedId == null
            ? null
            : TreeOps.find(shown, _selectedId!);
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
                title: Text(
                  s.board.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    tooltip: s.canUndo ? 'Undo ${s.undoLabel}' : 'Undo',
                    icon: const Icon(Icons.undo),
                    onPressed: s.canUndo ? _editor.undo : null,
                  ),
                  IconButton(
                    tooltip: s.canRedo ? 'Redo ${s.redoLabel}' : 'Redo',
                    icon: const Icon(Icons.redo),
                    onPressed: s.canRedo ? _editor.redo : null,
                  ),
                  IconButton(
                    tooltip: _view == BoardView.canvas
                        ? 'Outline view'
                        : 'Tree view',
                    icon: Icon(
                      _view == BoardView.canvas
                          ? Icons.format_list_bulleted
                          : Icons.account_tree_outlined,
                    ),
                    onPressed: () => setState(
                      () => _view = _view == BoardView.canvas
                          ? BoardView.outline
                          : BoardView.canvas,
                    ),
                  ),
                  const SizedBox(width: Metrics.gutter / 2),
                ],
              ),
              body: Column(
                children: [
                  if (focus != null)
                    _FocusBar(
                      path: [
                        for (final id in TreeOps.pathTo(root, focus.id))
                          TreeOps.find(root, id)!,
                      ],
                      onPick: (id) =>
                          setState(() => _focusId = id == root.id ? null : id),
                    ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => setState(() => _selectedId = null),
                      child: _view == BoardView.canvas
                          ? CanvasView(
                              root: shown,
                              direction: direction,
                              selectedId: selected?.id,
                              onTap: _onTap,
                              onLongPress: (n) => _onLongPress(n, root),
                              onToggleCollapse: _toggle,
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
              bottomNavigationBar: selected == null
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

  /// Tap selects; tapping the selected node again opens its editor.
  void _onTap(Node node) {
    if (_selectedId == node.id) {
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
    final result = await showEditSheet(context, node);
    if (result == null) return;
    _editor.editNode(
      node.id,
      title: result.title,
      notes: result.notes,
      status: result.status,
      color: result.color,
      tags: result.tags,
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
        borderRadius: BorderRadius.circular(Metrics.radius),
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
