import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../model/board.dart';
import '../model/node.dart';
import '../model/tree_ops.dart';
import 'providers.dart';

class EditorState {
  const EditorState({
    required this.board,
    this.undo = const [],
    this.redo = const [],
  });

  final Board board;

  /// Earlier boards, oldest first, each with what the change was.
  final List<({Board board, String label})> undo;
  final List<({Board board, String label})> redo;

  bool get canUndo => undo.isNotEmpty;
  bool get canRedo => redo.isNotEmpty;
  String? get undoLabel => undo.isEmpty ? null : undo.last.label;
  String? get redoLabel => redo.isEmpty ? null : redo.last.label;
}

/// Holds the open board, applies edits, keeps undo/redo and saves every
/// change to disk (which also records it in the board's history).
class BoardEditor extends AsyncNotifier<EditorState> {
  BoardEditor(this.boardId);

  final String boardId;
  Future<void> _saving = Future.value();

  DateTime _now() => ref.read(clockProvider)().toUtc();
  String _newId() => ref.read(idProvider)();

  @override
  Future<EditorState> build() async {
    final board = await ref.read(boardRepositoryProvider).loadBoard(boardId);
    return EditorState(board: board);
  }

  EditorState get _s => state.requireValue;

  /// Applies [edit] to the tree as one undoable step labelled [label].
  void apply(String label, Node Function(Node root, DateTime now) edit) {
    final s = _s;
    final now = _now();
    final root = edit(s.board.root, now);
    if (identical(root, s.board.root)) return;
    final depth = ref.read(settingsProvider).undoHistoryDepth;
    final undo = [...s.undo, (board: s.board, label: label)];
    if (undo.length > depth) undo.removeRange(0, undo.length - depth);
    final board = s.board.copyWith(root: root, updatedAt: now);
    state = AsyncData(EditorState(board: board, undo: undo));
    _save(board, label);
  }

  void undo() {
    final s = _s;
    if (!s.canUndo) return;
    final last = s.undo.last;
    final board = last.board.copyWith(updatedAt: _now());
    state = AsyncData(
      EditorState(
        board: board,
        undo: s.undo.sublist(0, s.undo.length - 1),
        redo: [...s.redo, (board: s.board, label: last.label)],
      ),
    );
    _save(board, 'Undo ${last.label.toLowerCase()}');
  }

  void redo() {
    final s = _s;
    if (!s.canRedo) return;
    final next = s.redo.last;
    final board = next.board.copyWith(updatedAt: _now());
    state = AsyncData(
      EditorState(
        board: board,
        undo: [...s.undo, (board: s.board, label: next.label)],
        redo: s.redo.sublist(0, s.redo.length - 1),
      ),
    );
    _save(board, 'Redo ${next.label.toLowerCase()}');
  }

  void _save(Board board, String label) {
    final repo = ref.read(boardRepositoryProvider);
    _saving = _saving.then((_) async {
      await repo.saveBoard(board, label: label);
      ref.invalidate(boardListProvider);
      ref.invalidate(historyProvider(boardId));
    });
  }

  /// Waits for pending saves. Used by tests and before leaving the board.
  Future<void> flush() => _saving;

  // ---- Edits ------------------------------------------------------------

  /// Adds a child and returns its id.
  String addChild(String parentId, String title) {
    final id = _newId();
    final type = ref.read(settingsProvider).defaultNodeType;
    apply('Add', (root, now) {
      final child = Node(
        id: id,
        title: title.trim(),
        type: type,
        status: NodeStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      return TreeOps.addChild(root, parentId, child);
    });
    return id;
  }

  /// Saves the edit sheet's fields in one step.
  void editNode(
    String id, {
    required String title,
    required String notes,
    required NodeStatus status,
    required String? color,
    required List<String> tags,
  }) {
    apply('Edit', (root, now) {
      var next = TreeOps.update(
        root,
        id,
        (n) =>
            n.title == title.trim() &&
                n.notes == notes &&
                n.color == color &&
                _sameList(n.tags, tags)
            ? n
            : n.copyWith(
                title: title.trim(),
                notes: notes,
                color: () => color,
                tags: tags,
                updatedAt: now,
              ),
      );
      if (TreeOps.find(next, id)?.status != status) {
        next = TreeOps.setStatus(next, id, status, now);
      }
      return next;
    });
  }

  void setStatus(String id, NodeStatus status) =>
      apply('Status', (root, now) => TreeOps.setStatus(root, id, status, now));

  void decide(String decisionId, Set<String> picked) => apply(
    'Decide',
    (root, now) => TreeOps.decide(root, decisionId, picked, now),
  );

  void reopen(String id) =>
      apply('Reopen', (root, now) => TreeOps.reopen(root, id, now));

  void changeType(String id, NodeType type) => apply(
    'Change type',
    (root, now) => TreeOps.changeType(root, id, type, now),
  );

  void delete(String id) =>
      apply('Delete', (root, _) => TreeOps.remove(root, id));

  void reorder(String id, int delta) =>
      apply('Reorder', (root, _) => TreeOps.reorder(root, id, delta));

  void move(String id, String newParentId) =>
      apply('Move', (root, _) => TreeOps.move(root, id, newParentId));

  void setCollapsed(String id, bool collapsed) => apply(
    collapsed ? 'Collapse' : 'Expand',
    (root, _) => TreeOps.setCollapsed(root, id, collapsed),
  );

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final boardEditorProvider =
    AsyncNotifierProvider.family<BoardEditor, EditorState, String>(
      BoardEditor.new,
    );

/// Injectable for tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final idProvider = Provider<String Function()>((ref) => const Uuid().v4);
