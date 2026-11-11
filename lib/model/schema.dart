import 'dart:convert';

import 'board.dart';
import 'json_read.dart';

/// Moves a raw board map from one schema version to the next.
typedef Migration = Map<String, Object?> Function(Map<String, Object?> json);

/// Versioning for the board file format.
///
/// When the format changes: bump [currentVersion], add a migration keyed by
/// the old version to [migrations], and update docs/schema/.
class BoardSchema {
  static const int currentVersion = 1;

  /// `migrations[n]` turns a version `n` file into version `n + 1`.
  static final Map<int, Migration> migrations = {};

  /// Parses board JSON text of any supported version, migrating it forward.
  static Board decode(String text, {Map<int, Migration>? migrations}) {
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException catch (e) {
      throw SchemaException('not valid JSON (${e.message})');
    }
    return Board.fromJson(migrate(raw, migrations: migrations));
  }

  static Map<String, Object?> migrate(
    Object? raw, {
    Map<int, Migration>? migrations,
    int target = currentVersion,
  }) {
    final steps = migrations ?? BoardSchema.migrations;
    var map = readMap(raw, 'board');
    var version = readInt(map, 'schemaVersion', 'board');
    if (version < 1) {
      throw SchemaException('board.schemaVersion $version is not valid');
    }
    if (version > target) {
      throw SchemaException(
        'this board was made by a newer version of Sortle '
        '(format $version). Update the app to open it.',
      );
    }
    while (version < target) {
      final step = steps[version];
      if (step == null) {
        throw SchemaException('no migration from format $version');
      }
      map = Map<String, Object?>.of(step(map));
      version++;
      map['schemaVersion'] = version;
    }
    return map;
  }

  static String encode(Board board) =>
      const JsonEncoder.withIndent('  ').convert(board.toJson());
}
