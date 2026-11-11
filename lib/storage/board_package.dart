import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../model/board.dart';
import '../model/json_read.dart';
import '../model/node.dart';
import '../model/schema.dart';

/// How a board leaves the app.
enum ExportFormat {
  /// `.sortle`: a zip with `board.json` and the voice notes in `audio/`.
  sortle('sortle'),

  /// `.json`: the board on its own, without voice notes.
  json('json');

  const ExportFormat(this.extension);

  final String extension;
}

/// A board read from an export file, checked and migrated to the current
/// schema, with the audio files its voice notes point at.
class BoardPackage {
  const BoardPackage({required this.board, this.audio = const {}});

  final Board board;

  /// Keyed by the voice note's relative path, for example `audio/x.m4a`.
  final Map<String, Uint8List> audio;
}

/// Builds and reads export files. Pure: no disk access, so it is easy to
/// test and the same on every platform.
abstract final class BoardPackager {
  static const boardEntry = 'board.json';

  /// Stops a hostile file from filling the disk on import.
  static const maxImportBytes = 1024 * 1024 * 1024;

  /// [readAudio] returns the bytes of a voice note's file, or null when it
  /// is missing. Notes whose file is missing are left out of the export.
  static Future<Uint8List> export(
    Board board,
    ExportFormat format, {
    required Future<Uint8List?> Function(String path) readAudio,
  }) async {
    switch (format) {
      case ExportFormat.json:
        final plain = board.copyWith(root: _withoutVoice(board.root));
        return Uint8List.fromList(utf8.encode(BoardSchema.encode(plain)));
      case ExportFormat.sortle:
        final audio = <String, Uint8List>{};
        for (final path in _audioPaths(board.root)) {
          final bytes = await readAudio(path);
          if (bytes != null) audio[path] = bytes;
        }
        final kept = board.copyWith(
          root: _keepVoice(board.root, audio.keys.toSet()),
        );
        final archive = Archive()
          ..add(ArchiveFile.string(boardEntry, BoardSchema.encode(kept)));
        for (final MapEntry(:key, :value) in audio.entries) {
          archive.add(ArchiveFile.noCompress(key, value.length, value));
        }
        return ZipEncoder().encodeBytes(archive);
    }
  }

  /// Reads a `.sortle` zip or a plain board JSON file. Throws
  /// [SchemaException] with a readable reason when the file is not a board.
  static BoardPackage read(Uint8List bytes) {
    if (bytes.length > maxImportBytes) {
      throw SchemaException('the file is too large to import');
    }
    if (_isZip(bytes)) return _readZip(bytes);
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw SchemaException('this is not a Sortle file');
    }
    final board = BoardSchema.decode(text);
    // A plain JSON file carries no audio, so its voice notes would point at
    // nothing.
    return BoardPackage(board: board.copyWith(root: _withoutVoice(board.root)));
  }

  static BoardPackage _readZip(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw SchemaException('the .sortle file is damaged');
    }
    var total = 0;
    String? boardText;
    final files = <String, ArchiveFile>{};
    for (final entry in archive) {
      if (!entry.isFile) continue;
      total += entry.size;
      if (total > maxImportBytes) {
        throw SchemaException('the file is too large to import');
      }
      if (entry.name == boardEntry) {
        try {
          boardText = utf8.decode(entry.content);
        } on FormatException {
          throw SchemaException('board.json is not text');
        }
      } else if (isSafeAudioPath(entry.name)) {
        files[entry.name] = entry;
      }
      // Anything else is ignored rather than written to disk.
    }
    if (boardText == null) {
      throw SchemaException('the .sortle file has no board.json');
    }
    final board = BoardSchema.decode(boardText);
    final wanted = _audioPaths(board.root).toSet();
    final audio = <String, Uint8List>{
      for (final path in wanted)
        if (files[path] case final f?) path: f.content,
    };
    return BoardPackage(
      board: board.copyWith(root: _keepVoice(board.root, audio.keys.toSet())),
      audio: audio,
    );
  }

  /// `audio/<name>` with no folders, dots-only names or odd characters.
  static bool isSafeAudioPath(String path) =>
      RegExp(r'^audio/[A-Za-z0-9_-][A-Za-z0-9._-]{0,127}$').hasMatch(path) &&
      !path.contains('..');

  static bool _isZip(Uint8List b) =>
      b.length >= 4 && b[0] == 0x50 && b[1] == 0x4B && b[2] == 3 && b[3] == 4;

  static Iterable<String> _audioPaths(Node node) sync* {
    for (final v in node.voiceNotes) {
      yield v.path;
    }
    for (final c in node.children) {
      yield* _audioPaths(c);
    }
  }

  static Node _withoutVoice(Node node) => _keepVoice(node, const {});

  static Node _keepVoice(Node node, Set<String> paths) {
    final notes = [
      for (final v in node.voiceNotes)
        if (paths.contains(v.path)) v,
    ];
    final kids = [for (final c in node.children) _keepVoice(c, paths)];
    return node.copyWith(voiceNotes: notes, children: kids);
  }
}
