import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapex/model/node.dart';
import 'package:mapex/storage/board_repository.dart';

void main() {
  late Directory tmp;
  late BoardRepository repo;
  late DateTime now;
  var cap = 200;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mapex_test_');
    now = DateTime.utc(2026, 11, 10, 9);
    cap = 200;
    repo = BoardRepository(
      root: tmp,
      historyCap: () => cap,
      clock: () => now = now.add(const Duration(seconds: 1)),
    );
  });

  tearDown(() => tmp.delete(recursive: true));

  Directory boardDir(String id) => Directory('${tmp.path}/boards/$id');

  test('create writes board.json, audio/ and history/', () async {
    final b = await repo.createBoard('  Career  ', rootType: NodeType.decision);
    expect(b.title, 'Career');
    expect(b.root.title, 'Career');
    expect(b.root.type, NodeType.decision);
    final dir = boardDir(b.id);
    expect(File('${dir.path}/board.json').existsSync(), isTrue);
    expect(Directory('${dir.path}/audio').existsSync(), isTrue);
    expect(Directory('${dir.path}/history').listSync(), hasLength(1));
    expect((await repo.loadBoard(b.id)).title, 'Career');
  });

  test('empty titles are refused', () {
    expect(
      () => repo.createBoard('   ', rootType: NodeType.task),
      throwsArgumentError,
    );
  });

  test('list is sorted by last edit, newest first', () async {
    final a = await repo.createBoard('A', rootType: NodeType.task);
    final b = await repo.createBoard('B', rootType: NodeType.task);
    await repo.renameBoard(a.id, 'A2');
    final list = await repo.listBoards();
    expect(list.boards.map((s) => s.title), ['A2', 'B']);
    expect(list.boards.first.id, a.id);
    expect(b.id, isNot(a.id));
  });

  test('duplicate gets a new id, copies audio, starts fresh history', () async {
    final a = await repo.createBoard('A', rootType: NodeType.task);
    File('${boardDir(a.id).path}/audio/v1.m4a').writeAsStringSync('sound');
    await repo.renameBoard(a.id, 'A');
    final copy = await repo.duplicateBoard(a.id, title: 'A copy');
    expect(copy.id, isNot(a.id));
    expect(copy.root.id, a.root.id);
    final dir = boardDir(copy.id);
    expect(File('${dir.path}/audio/v1.m4a').readAsStringSync(), 'sound');
    expect(Directory('${dir.path}/history').listSync(), hasLength(1));
    expect((await repo.listBoards()).boards, hasLength(2));
  });

  test('trash, restore, delete forever and empty trash', () async {
    final a = await repo.createBoard('A', rootType: NodeType.task);
    final b = await repo.createBoard('B', rootType: NodeType.task);

    await repo.moveToTrash(a.id);
    expect((await repo.listBoards()).boards.map((s) => s.id), [b.id]);
    final trash = await repo.listTrash();
    expect(trash.boards.single.id, a.id);
    expect(trash.boards.single.trashedAt, isNotNull);

    await repo.restoreFromTrash(a.id);
    expect((await repo.listBoards()).boards, hasLength(2));
    expect((await repo.listTrash()).boards, isEmpty);
    expect(File('${boardDir(a.id).path}/trashed.json').existsSync(), isFalse);

    await repo.moveToTrash(a.id);
    await repo.deleteForever(a.id);
    expect((await repo.listTrash()).boards, isEmpty);

    await repo.moveToTrash(b.id);
    await repo.emptyTrash();
    expect((await repo.listTrash()).boards, isEmpty);
    expect((await repo.listBoards()).boards, isEmpty);
  });

  test('history keeps at most the cap, dropping the oldest', () async {
    cap = 3;
    final a = await repo.createBoard('v0', rootType: NodeType.task);
    for (var i = 1; i <= 5; i++) {
      await repo.renameBoard(a.id, 'v$i');
    }
    final history = await repo.listHistory(a.id);
    expect(history, hasLength(3));
    expect(history.first.savedAt.isAfter(history.last.savedAt), isTrue);
  });

  test('revert brings back an old version and is itself recorded', () async {
    final a = await repo.createBoard('First', rootType: NodeType.task);
    await repo.renameBoard(a.id, 'Second');
    final history = await repo.listHistory(a.id);
    expect(history.map((h) => h.label), ['Renamed', 'Created']);

    final reverted = await repo.revertTo(a.id, history.last.id);
    expect(reverted.title, 'First');
    expect((await repo.loadBoard(a.id)).title, 'First');
    expect((await repo.listHistory(a.id)).first.label, 'Reverted');
  });

  test('revert refuses ids that point outside history/', () async {
    final a = await repo.createBoard('A', rootType: NodeType.task);
    expect(() => repo.revertTo(a.id, '../board'), throwsArgumentError);
  });

  test('a damaged board shows up as broken instead of vanishing', () async {
    final good = await repo.createBoard('Good', rootType: NodeType.task);
    final bad = Directory('${tmp.path}/boards/bad')..createSync();
    File('${bad.path}/board.json').writeAsStringSync('{"schemaVersion": 1}');
    final list = await repo.listBoards();
    expect(list.boards.single.id, good.id);
    expect(list.broken.single.id, 'bad');
  });

  test('a board whose id does not match its folder is reported', () async {
    final a = await repo.createBoard('A', rootType: NodeType.task);
    final moved = Directory('${tmp.path}/boards/other');
    await boardDir(a.id).rename(moved.path);
    final list = await repo.listBoards();
    expect(list.broken.single.reason, contains('folder'));
  });

  test('saves leave no temporary files behind', () async {
    final a = await repo.createBoard('A', rootType: NodeType.task);
    await repo.renameBoard(a.id, 'B');
    final leftovers = boardDir(a.id)
        .listSync(recursive: true)
        .where((e) => e.path.endsWith('.tmp'));
    expect(leftovers, isEmpty);
    final json = jsonDecode(
      File('${boardDir(a.id).path}/board.json').readAsStringSync(),
    );
    expect((json as Map)['title'], 'B');
  });
}
