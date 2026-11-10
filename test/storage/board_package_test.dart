import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapex/model/json_read.dart';
import 'package:mapex/model/node.dart';
import 'package:mapex/model/schema.dart';
import 'package:mapex/model/tree_ops.dart';
import 'package:mapex/model/voice_note.dart';
import 'package:mapex/storage/board_package.dart';
import 'package:mapex/storage/board_repository.dart';
import 'package:mapex/ui/export_import.dart';

void main() {
  late Directory tmp;
  late BoardRepository repo;
  var n = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mapex_pkg_');
    repo = BoardRepository(root: tmp, historyCap: () => 200);
  });

  tearDown(() => tmp.delete(recursive: true));

  VoiceNote note(String id) => VoiceNote(
    id: id,
    path: 'audio/$id.m4a',
    createdAt: DateTime.utc(2026, 11, 10),
    durationMs: 1200,
  );

  /// A board whose root has voice notes [ids]; audio is written for [withFile].
  Future<String> boardWithVoice(
    List<String> ids, {
    Set<String>? withFile,
  }) async {
    final b = await repo.createBoard('Trip ${n++}', rootType: NodeType.task);
    for (final id in withFile ?? ids.toSet()) {
      await repo.audioFile(b.id, 'audio/$id.m4a').writeAsBytes([1, 2, 3]);
    }
    await repo.saveBoard(
      b.copyWith(
        root: b.root.copyWith(voiceNotes: [for (final id in ids) note(id)]),
      ),
      label: 'Voice',
    );
    return b.id;
  }

  Future<Uint8List> export(String id, ExportFormat f) async =>
      BoardPackager.export(
        await repo.loadBoard(id),
        f,
        readAudio: (p) => repo.readAudio(id, p),
      );

  test('.mapex carries the board and its audio', () async {
    final id = await boardWithVoice(['a', 'b'], withFile: {'a'});
    final bytes = await export(id, ExportFormat.mapex);
    final pkg = BoardPackager.read(bytes);
    expect(pkg.board.id, id);
    // b's file was missing, so b is left out rather than broken.
    expect(pkg.board.root.voiceNotes.map((v) => v.id), ['a']);
    expect(pkg.audio.keys, ['audio/a.m4a']);
    expect(pkg.audio['audio/a.m4a'], [1, 2, 3]);
  });

  test('plain JSON drops voice notes and reads back', () async {
    final id = await boardWithVoice(['a']);
    final bytes = await export(id, ExportFormat.json);
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    expect((json['root']! as Map)['voiceNotes'], isEmpty);
    final pkg = BoardPackager.read(bytes);
    expect(pkg.board.id, id);
    expect(pkg.audio, isEmpty);
  });

  test('junk and unsafe files are refused or ignored', () async {
    expect(
      () => BoardPackager.read(Uint8List.fromList([0xff, 0xfe, 0])),
      throwsA(isA<SchemaException>()),
    );
    expect(
      () => BoardPackager.read(Uint8List.fromList(utf8.encode('{"a":1}'))),
      throwsA(isA<SchemaException>()),
    );
    final noBoard = ZipEncoder().encodeBytes(
      Archive()..add(ArchiveFile.string('notes.txt', 'hi')),
    );
    expect(() => BoardPackager.read(noBoard), throwsA(isA<SchemaException>()));

    final id = await boardWithVoice(['a']);
    final board = await repo.loadBoard(id);
    final evil = ZipEncoder().encodeBytes(
      Archive()
        ..add(ArchiveFile.string('board.json', BoardSchema.encode(board)))
        ..add(ArchiveFile.bytes('../escape.m4a', [9]))
        ..add(ArchiveFile.bytes('audio/../../x', [9]))
        ..add(ArchiveFile.bytes('audio/a.m4a', [7])),
    );
    final pkg = BoardPackager.read(evil);
    expect(pkg.audio.keys, ['audio/a.m4a']);
    expect(BoardPackager.isSafeAudioPath('audio/../x'), isFalse);
    expect(BoardPackager.isSafeAudioPath('audio/sub/x.m4a'), isFalse);
    expect(BoardPackager.isSafeAudioPath('audio/x.m4a'), isTrue);
  });

  group('import', () {
    test('a new board is added with its audio', () async {
      final id = await boardWithVoice(['a']);
      final bytes = await export(id, ExportFormat.mapex);
      await repo.moveToTrash(id);
      await repo.deleteForever(id);

      final board = await repo.importBoard(BoardPackager.read(bytes));
      expect(board.id, id);
      expect(await repo.readAudio(id, 'audio/a.m4a'), [1, 2, 3]);
      expect((await repo.listHistory(id)).single.label, 'Imported');
    });

    test('keep both adds a copy under a new id', () async {
      final id = await boardWithVoice(['a']);
      final pkg = BoardPackager.read(await export(id, ExportFormat.mapex));
      final copy = await repo.importBoard(pkg);
      expect(copy.id, isNot(id));
      expect((await repo.listBoards()).boards, hasLength(2));
      expect(await repo.readAudio(copy.id, 'audio/a.m4a'), [1, 2, 3]);
    });

    test('replace sends the one here to the trash', () async {
      final id = await boardWithVoice(['a']);
      final pkg = BoardPackager.read(await export(id, ExportFormat.json));
      await repo.renameBoard(id, 'Changed here');
      final board = await repo.importBoard(
        pkg,
        conflict: ImportConflict.replace,
      );
      expect(board.id, id);
      expect((await repo.loadBoard(id)).title, startsWith('Trip'));
      expect((await repo.listTrash()).boards.single.title, 'Changed here');
    });
  });

  test('unused audio is pruned, audio in history is kept', () async {
    final id = await boardWithVoice(['a', 'b']);
    await repo.audioFile(id, 'audio/stray.m4a').writeAsBytes([0]);
    final b = await repo.loadBoard(id);
    await repo.saveBoard(
      b.copyWith(root: b.root.copyWith(voiceNotes: [note('a')])),
      label: 'Delete voice note',
    );
    expect(await repo.pruneAudio(id), 1);
    expect(await repo.readAudio(id, 'audio/stray.m4a'), isNull);
    // b is gone from the board but a revert can still bring it back.
    expect(await repo.readAudio(id, 'audio/b.m4a'), isNotNull);
    expect(TreeOps.find(b.root, b.root.id)!.voiceNotes, hasLength(2));
  });

  test('file names are safe on every platform', () {
    expect(fileSafe('Plan: A/B?'), 'Plan A B');
    expect(fileSafe('   '), 'Board');
    expect(fileSafe('.hidden'), 'Board');
  });
}
