import 'json_read.dart';
import 'node.dart';
import 'schema.dart';

/// One board: a single tree, saved as one `board.json`. The in-app state and
/// the file on disk have the same structure.
class Board {
  const Board({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.root,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Node root;

  int get nodeCount => root.nodeCount;

  Board copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    Node? root,
  }) {
    return Board(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      root: root ?? this.root,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': BoardSchema.currentVersion,
    'id': id,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'root': root.toJson(),
  };

  /// Parses a board that is already at [BoardSchema.currentVersion].
  /// Use [BoardSchema.decode] for files that may be older.
  static Board fromJson(Object? json) {
    const path = 'board';
    final map = readMap(json, path);
    final version = readInt(map, 'schemaVersion', path);
    if (version != BoardSchema.currentVersion) {
      throw SchemaException(
        'board.schemaVersion is $version, expected '
        '${BoardSchema.currentVersion}',
      );
    }
    final id = readString(map, 'id', path);
    // The id becomes a folder name, so keep it to safe characters.
    if (!_idPattern.hasMatch(id)) {
      throw SchemaException('board.id has characters that are not allowed');
    }
    final title = readString(map, 'title', path);
    if (title.trim().isEmpty) {
      throw SchemaException('board.title must not be empty');
    }
    final board = Board(
      id: id,
      title: title,
      createdAt: readDateTime(map, 'createdAt', path),
      updatedAt: readDateTime(map, 'updatedAt', path),
      root: Node.fromJson(map['root'], 'board.root'),
    );
    _checkUniqueIds(board.root, <String>{});
    return board;
  }

  static final _idPattern = RegExp(r'^[A-Za-z0-9-]{1,64}$');

  static void _checkUniqueIds(Node node, Set<String> seen) {
    if (!seen.add(node.id)) {
      throw SchemaException('node id "${node.id}" is used more than once');
    }
    for (final child in node.children) {
      _checkUniqueIds(child, seen);
    }
  }
}
