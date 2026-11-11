import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../model/board.dart';
import '../model/node.dart';
import '../model/reminder.dart';
import '../model/tree_ops.dart';
import '../model/voice_note.dart';
import '../reminders/timing.dart';
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
    final repo = ref.read(boardRepositoryProvider);
    final board = await repo.loadBoard(boardId);
    // Audio left behind by deleted voice notes is cleared when the board
    // opens, once nothing (not even history) points at it.
    await repo.pruneAudio(boardId);
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

  /// Expands every collapsed ancestor of [id] so it can be seen. Not an
  /// undo step: it only changes what is visible.
  void reveal(String id) {
    final s = _s;
    final path = TreeOps.pathTo(s.board.root, id);
    var root = s.board.root;
    for (final ancestor in path.take(path.length - 1)) {
      if (TreeOps.find(root, ancestor)!.collapsed) {
        root = TreeOps.setCollapsed(root, ancestor, false);
      }
    }
    if (identical(root, s.board.root)) return;
    final board = s.board.copyWith(root: root);
    state = AsyncData(EditorState(board: board, undo: s.undo, redo: s.redo));
    _save(board, 'Expand');
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
    DateTime? date,
    DateTime? time,
    Reminder? reminder,
    bool setWhen = false,
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
      if (setWhen) next = _withWhen(next, id, date, time, reminder, now);
      if (TreeOps.find(next, id)?.status != status) {
        next = TreeOps.setStatus(next, id, status, now);
      }
      return next;
    });
  }

  /// Sets or clears a node's date, time and reminder. A reminder needs both
  /// a date and a time.
  static Node _withWhen(
    Node root,
    String id,
    DateTime? date,
    DateTime? time,
    Reminder? reminder,
    DateTime now,
  ) {
    return TreeOps.update(root, id, (n) {
      final d = date == null ? null : Timing.formatDate(date);
      final t = date == null || time == null ? null : Timing.formatTime(time);
      final r = t == null ? null : reminder;
      if (n.date == d && n.time == t && n.reminder == r) return n;
      return n.copyWith(
        date: () => d,
        time: () => t,
        reminder: () => r,
        updatedAt: now,
      );
    });
  }

  /// "Not yet": pushes the node to [newDue] and marks it not yet.
  void snooze(String id, DateTime newDue) {
    apply('Not yet', (root, now) {
      return TreeOps.update(
        root,
        id,
        (n) => n.copyWith(
          status: NodeStatus.notYet,
          date: () => Timing.formatDate(newDue),
          time: () => Timing.formatTime(newDue),
          updatedAt: now,
        ),
      );
    });
  }

  /// "Done" from the task prompt. A repeating task rolls forward to its next
  /// time after now and stays open; anything else is ticked done.
  void answerDone(String id) {
    apply('Done', (root, now) {
      final node = TreeOps.find(root, id);
      final due = node == null ? null : Timing.dueAt(node);
      final target = due == null || !rollRepeatsForward
          ? null
          : Timing.nextAfter(due, node!.reminder, now.toLocal());
      if (target == null) {
        return TreeOps.setStatus(root, id, NodeStatus.done, now);
      }
      return TreeOps.update(
        root,
        id,
        (n) => n.copyWith(
          status: NodeStatus.pending,
          date: () => Timing.formatDate(target),
          time: () => Timing.formatTime(target),
          updatedAt: now,
        ),
      );
    });
  }

  /// Whether ticking a repeating task done rolls it to its next time.
  static const rollRepeatsForward = true;

  // ---- Voice notes ------------------------------------------------------

  /// A fresh id and the relative path its audio should be recorded to.
  ({String id, String path}) newVoicePath(String extension) {
    final id = _newId();
    return (id: id, path: 'audio/$id.$extension');
  }

  void addVoiceNote(String nodeId, VoiceNote note) => apply(
    'Voice note',
    (root, now) => TreeOps.update(
      root,
      nodeId,
      (n) => n.copyWith(voiceNotes: [...n.voiceNotes, note], updatedAt: now),
    ),
  );

  /// Re-record: [note] takes the place of [oldId], in the same position.
  void replaceVoiceNote(String nodeId, String oldId, VoiceNote note) => apply(
    'Re-record',
    (root, now) => TreeOps.update(
      root,
      nodeId,
      (n) => n.copyWith(
        voiceNotes: [for (final v in n.voiceNotes) v.id == oldId ? note : v],
        updatedAt: now,
      ),
    ),
  );

  /// The audio file stays on disk until nothing points at it, so undo can
  /// bring the note back.
  void removeVoiceNote(String nodeId, String noteId) => apply(
    'Delete voice note',
    (root, now) => TreeOps.update(root, nodeId, (n) {
      if (!n.voiceNotes.any((v) => v.id == noteId)) return n;
      return n.copyWith(
        voiceNotes: [
          for (final v in n.voiceNotes)
            if (v.id != noteId) v,
        ],
        updatedAt: now,
      );
    }),
  );

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

  /// Drops nodes where the user dragged them on the canvas.
  void place(Map<String, NodePosition> positions) =>
      apply('Move on canvas', (root, _) => TreeOps.place(root, positions));

  /// Lines the whole board up neatly again.
  void tidyUp() => apply('Tidy up', (root, _) => TreeOps.clearPositions(root));

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
