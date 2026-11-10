import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../model/board.dart';
import '../model/json_read.dart';
import '../model/node.dart';
import '../model/schema.dart';
import 'atomic_file.dart';

/// What the board list shows, without holding whole trees in memory.
class BoardSummary {
  const BoardSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.nodeCount,
    this.trashedAt,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final int nodeCount;

  /// Set only for boards in the trash.
  final DateTime? trashedAt;
}

/// A board folder that could not be read. Shown in the list so nothing
/// disappears silently.
class BrokenBoard {
  const BrokenBoard({required this.id, required this.reason});

  final String id;
  final String reason;
}

class BoardListing {
  const BoardListing({required this.boards, required this.broken});

  final List<BoardSummary> boards;
  final List<BrokenBoard> broken;
}

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.savedAt,
    required this.label,
  });

  /// File name inside the board's `history/` folder, without `.json`.
  final String id;
  final DateTime savedAt;
  final String label;
}

/// Reads and writes boards on disk.
///
/// ```text
/// <root>/boards/<boardId>/board.json
///                         audio/
///                         history/<time>-<n>.json
/// <root>/trash/<boardId>/... (same layout) + trashed.json
/// ```
class BoardRepository {
  BoardRepository({
    required this.root,
    required this._historyCap,
    DateTime Function()? clock,
    String Function()? newId,
    this.onSaved,
    this.onRemoved,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  final Directory root;
  final int Function() _historyCap;

  /// Called after a board is written, so reminders can follow it.
  final Future<void> Function(Board board)? onSaved;

  /// Called after a board leaves the board list (trash or delete).
  final Future<void> Function(String boardId)? onRemoved;
  final DateTime Function() _clock;
  final String Function() _newId;

  static const boardFileName = 'board.json';
  static const audioDirName = 'audio';
  static const historyDirName = 'history';
  static const trashMetaFileName = 'trashed.json';

  Directory get _boardsDir => Directory(_join(root.path, 'boards'));
  Directory get _trashDir => Directory(_join(root.path, 'trash'));

  Directory boardDir(String id) => Directory(_join(_boardsDir.path, id));
  Directory _trashedDir(String id) => Directory(_join(_trashDir.path, id));
  File _boardFile(Directory dir) => File(_join(dir.path, boardFileName));
  Directory _historyDir(Directory dir) =>
      Directory(_join(dir.path, historyDirName));

  DateTime _now() => _clock().toUtc();

  // ---- Listing ----------------------------------------------------------

  Future<BoardListing> listBoards() => _list(_boardsDir, trashed: false);

  Future<BoardListing> listTrash() => _list(_trashDir, trashed: true);

  Future<BoardListing> _list(Directory parent, {required bool trashed}) async {
    final boards = <BoardSummary>[];
    final broken = <BrokenBoard>[];
    if (!await parent.exists()) {
      return BoardListing(boards: boards, broken: broken);
    }
    await for (final entity in parent.list()) {
      if (entity is! Directory) continue;
      final id = _baseName(entity.path);
      try {
        final board = await _readBoard(entity);
        DateTime? trashedAt;
        if (trashed) {
          trashedAt = await _readTrashedAt(entity);
        }
        boards.add(
          BoardSummary(
            id: board.id,
            title: board.title,
            updatedAt: board.updatedAt,
            nodeCount: board.nodeCount,
            trashedAt: trashedAt,
          ),
        );
      } on SchemaException catch (e) {
        broken.add(BrokenBoard(id: id, reason: e.message));
      } on FileSystemException catch (e) {
        broken.add(BrokenBoard(id: id, reason: e.message));
      }
    }
    if (trashed) {
      boards.sort((a, b) => b.trashedAt!.compareTo(a.trashedAt!));
    } else {
      boards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return BoardListing(boards: boards, broken: broken);
  }

  /// Every readable board in full. Damaged ones are skipped (the board list
  /// shows them).
  Future<List<Board>> loadAllBoards() async {
    final out = <Board>[];
    if (!await _boardsDir.exists()) return out;
    await for (final entity in _boardsDir.list()) {
      if (entity is! Directory) continue;
      try {
        out.add(await _readBoard(entity));
      } on SchemaException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return out;
  }

  // ---- Single board -----------------------------------------------------

  Future<Board> loadBoard(String id) => _readBoard(boardDir(id));

  Future<Board> _readBoard(Directory dir) async {
    final file = _boardFile(dir);
    if (!await file.exists()) {
      throw SchemaException('board.json is missing');
    }
    final board = BoardSchema.decode(await file.readAsString());
    if (board.id != _baseName(dir.path)) {
      throw SchemaException(
        'board id "${board.id}" does not match its folder name',
      );
    }
    return board;
  }

  Future<Board> createBoard(String title, {required NodeType rootType}) async {
    final clean = _cleanTitle(title);
    final now = _now();
    final board = Board(
      id: _newId(),
      title: clean,
      createdAt: now,
      updatedAt: now,
      root: Node(
        id: _newId(),
        title: clean,
        type: rootType,
        status: NodeStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final dir = boardDir(board.id);
    await Directory(_join(dir.path, audioDirName)).create(recursive: true);
    await _historyDir(dir).create(recursive: true);
    await _write(dir, board, label: 'Created');
    return board;
  }

  /// Saves [board] and records a history snapshot labelled [label].
  Future<Board> saveBoard(Board board, {required String label}) async {
    final dir = boardDir(board.id);
    if (!await dir.exists()) {
      throw FileSystemException('board not found', dir.path);
    }
    final updated = board.copyWith(updatedAt: _now());
    await _write(dir, updated, label: label);
    return updated;
  }

  Future<Board> renameBoard(String id, String title) async {
    final board = await loadBoard(id);
    return saveBoard(
      board.copyWith(title: _cleanTitle(title)),
      label: 'Renamed',
    );
  }

  /// Copies a board, with its audio, under a new id. History starts fresh.
  Future<Board> duplicateBoard(String id, {required String title}) async {
    final source = await loadBoard(id);
    final now = _now();
    final copy = source.copyWith(
      id: _newId(),
      title: _cleanTitle(title),
      createdAt: now,
      updatedAt: now,
    );
    final dir = boardDir(copy.id);
    final audioTarget = Directory(_join(dir.path, audioDirName));
    await _copyDir(
      Directory(_join(boardDir(id).path, audioDirName)),
      audioTarget,
    );
    await audioTarget.create(recursive: true);
    await _historyDir(dir).create(recursive: true);
    await _write(dir, copy, label: 'Duplicated');
    return copy;
  }

  Future<void> _write(
    Directory dir,
    Board board, {
    required String label,
  }) async {
    await writeAtomically(_boardFile(dir), BoardSchema.encode(board));
    await _addSnapshot(dir, board, label);
    await onSaved?.call(board);
  }

  // ---- History ----------------------------------------------------------

  int _snapshotCounter = 0;

  Future<void> _addSnapshot(Directory dir, Board board, String label) async {
    final now = _now();
    final name =
        '${now.microsecondsSinceEpoch.toString().padLeft(20, '0')}-'
        '${(_snapshotCounter++ % 1000).toString().padLeft(3, '0')}';
    final entry = {
      'savedAt': now.toIso8601String(),
      'label': label,
      'board': board.toJson(),
    };
    await writeAtomically(
      File(_join(_historyDir(dir).path, '$name.json')),
      jsonEncode(entry),
    );
    await _pruneHistory(dir);
  }

  Future<List<File>> _historyFiles(Directory dir) async {
    final history = _historyDir(dir);
    if (!await history.exists()) return [];
    final files = <File>[
      await for (final e in history.list())
        if (e is File && e.path.endsWith('.json')) e,
    ];
    files.sort((a, b) => _baseName(a.path).compareTo(_baseName(b.path)));
    return files;
  }

  Future<void> _pruneHistory(Directory dir) async {
    final files = await _historyFiles(dir);
    final cap = _historyCap();
    for (var i = 0; i < files.length - cap; i++) {
      await files[i].delete();
    }
  }

  /// Newest first.
  Future<List<HistoryEntry>> listHistory(String boardId) async {
    final files = await _historyFiles(boardDir(boardId));
    final entries = <HistoryEntry>[];
    for (final file in files.reversed) {
      try {
        final map = readMap(jsonDecode(await file.readAsString()), 'history');
        entries.add(
          HistoryEntry(
            id: _baseName(file.path).replaceAll('.json', ''),
            savedAt: readDateTime(map, 'savedAt', 'history'),
            label: readString(map, 'label', 'history'),
          ),
        );
      } on Object {
        // A damaged snapshot is skipped rather than blocking the list.
      }
    }
    return entries;
  }

  /// Makes the snapshot [entryId] the current board. The revert itself is
  /// recorded as a new history entry, so it can be undone too.
  Future<Board> revertTo(String boardId, String entryId) async {
    if (entryId.contains('/') || entryId.contains('\\')) {
      throw ArgumentError.value(entryId, 'entryId');
    }
    final dir = boardDir(boardId);
    final file = File(_join(_historyDir(dir).path, '$entryId.json'));
    final map = readMap(jsonDecode(await file.readAsString()), 'history');
    final snapshot = Board.fromJson(BoardSchema.migrate(map['board']));
    return saveBoard(snapshot, label: 'Reverted');
  }

  // ---- Trash ------------------------------------------------------------

  Future<void> moveToTrash(String id) async {
    final from = boardDir(id);
    final to = _trashedDir(id);
    await _trashDir.create(recursive: true);
    if (await to.exists()) await to.delete(recursive: true);
    await from.rename(to.path);
    await writeAtomically(
      File(_join(to.path, trashMetaFileName)),
      jsonEncode({'trashedAt': _now().toIso8601String()}),
    );
    await onRemoved?.call(id);
  }

  Future<void> restoreFromTrash(String id) async {
    final from = _trashedDir(id);
    final to = boardDir(id);
    if (await to.exists()) {
      throw FileSystemException('a board with this id already exists', to.path);
    }
    await _boardsDir.create(recursive: true);
    final meta = File(_join(from.path, trashMetaFileName));
    if (await meta.exists()) await meta.delete();
    await from.rename(to.path);
    if (onSaved != null) await onSaved!(await loadBoard(id));
  }

  Future<void> deleteForever(String id) async {
    final dir = _trashedDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> emptyTrash() async {
    if (await _trashDir.exists()) await _trashDir.delete(recursive: true);
  }

  Future<DateTime> _readTrashedAt(Directory dir) async {
    final file = File(_join(dir.path, trashMetaFileName));
    if (await file.exists()) {
      try {
        final map = readMap(jsonDecode(await file.readAsString()), 'trash');
        return readDateTime(map, 'trashedAt', 'trash');
      } on Object {
        // Fall through to the folder's timestamp.
      }
    }
    return (await dir.stat()).modified.toUtc();
  }

  // ---- Helpers ----------------------------------------------------------

  String _cleanTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) throw ArgumentError.value(title, 'title', 'is empty');
    return t;
  }

  static Future<void> _copyDir(Directory from, Directory to) async {
    if (!await from.exists()) return;
    await to.create(recursive: true);
    await for (final e in from.list()) {
      final target = _join(to.path, _baseName(e.path));
      if (e is File) {
        await e.copy(target);
      } else if (e is Directory) {
        await _copyDir(e, Directory(target));
      }
    }
  }

  static String _join(String a, String b) => '$a${Platform.pathSeparator}$b';

  static String _baseName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => path);
  }
}
