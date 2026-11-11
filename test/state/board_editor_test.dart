import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sortle/model/node.dart';
import 'package:sortle/model/reminder.dart';
import 'package:sortle/model/tree_ops.dart';
import 'package:sortle/model/voice_note.dart';
import 'package:sortle/reminders/timing.dart';
import 'package:sortle/settings/app_settings.dart';
import 'package:sortle/state/board_editor.dart';
import 'package:sortle/state/providers.dart';
import 'package:sortle/storage/board_repository.dart';

void main() {
  late Directory tmp;
  late ProviderContainer c;
  late String boardId;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sortle_editor_');
    final repo = BoardRepository(root: tmp, historyCap: () => 200);
    boardId = (await repo.createBoard('Plan', rootType: NodeType.task)).id;
    c = ProviderContainer(
      overrides: [
        appDirProvider.overrideWithValue(tmp),
        initialSettingsProvider.overrideWithValue(
          AppSettings.defaults.copyWith(undoHistoryDepth: 3),
        ),
      ],
    );
    await c.read(boardEditorProvider(boardId).future);
  });

  tearDown(() async {
    c.dispose();
    await tmp.delete(recursive: true);
  });

  BoardEditor editor() => c.read(boardEditorProvider(boardId).notifier);
  EditorState state() => c.read(boardEditorProvider(boardId)).requireValue;

  test('edits save to disk', () async {
    final rootId = state().board.root.id;
    final id = editor().addChild(rootId, 'Step one');
    await editor().flush();
    final repo = c.read(boardRepositoryProvider);
    final saved = await repo.loadBoard(boardId);
    expect(TreeOps.find(saved.root, id)!.title, 'Step one');
    final history = await repo.listHistory(boardId);
    expect(history.first.label, 'Add');
  });

  test('undo and redo walk back and forward', () async {
    final rootId = state().board.root.id;
    final id = editor().addChild(rootId, 'A');
    editor().setStatus(id, NodeStatus.done);
    expect(TreeOps.find(state().board.root, id)!.status, NodeStatus.done);

    editor().undo();
    expect(TreeOps.find(state().board.root, id)!.status, NodeStatus.pending);
    editor().undo();
    expect(TreeOps.find(state().board.root, id), isNull);
    expect(state().canUndo, isFalse);

    editor().redo();
    expect(TreeOps.find(state().board.root, id), isNotNull);
    expect(state().canRedo, isTrue);

    // A new edit clears redo.
    editor().addChild(rootId, 'B');
    expect(state().canRedo, isFalse);
    await editor().flush();
  });

  test('undo depth follows the setting', () async {
    final rootId = state().board.root.id;
    for (var i = 0; i < 5; i++) {
      editor().addChild(rootId, 'N$i');
    }
    expect(state().undo, hasLength(3));
    await editor().flush();
  });

  test('an edit that changes nothing is not an undo step', () async {
    final root = state().board.root;
    editor().editNode(
      root.id,
      title: root.title,
      notes: root.notes,
      status: root.status,
      color: root.color,
      tags: root.tags,
    );
    expect(state().canUndo, isFalse);
  });

  test('new children use the default node type', () async {
    c.read(settingsProvider.notifier).state = c
        .read(settingsProvider)
        .copyWith(defaultNodeType: NodeType.decision);
    final id = editor().addChild(state().board.root.id, 'Choice');
    expect(TreeOps.find(state().board.root, id)!.type, NodeType.decision);
    await editor().flush();
  });

  group('prompt answers', () {
    late String id;
    setUp(() {
      id = editor().addChild(state().board.root.id, 'Walk');
    });

    Node node() => TreeOps.find(state().board.root, id)!;

    test('done on a one-off ticks it done', () async {
      editor().editNode(
        id,
        title: 'Walk',
        notes: '',
        status: NodeStatus.pending,
        color: null,
        tags: const [],
        setWhen: true,
        date: DateTime(2026, 11, 10),
        time: DateTime(2026, 11, 10, 7),
        reminder: const Reminder(),
      );
      editor().answerDone(id);
      expect(node().status, NodeStatus.done);
      await editor().flush();
    });

    test('done on a daily repeat rolls it to the next day', () async {
      final now = DateTime.now();
      final today7 = DateTime(now.year, now.month, now.day, 7);
      editor().editNode(
        id,
        title: 'Walk',
        notes: '',
        status: NodeStatus.pending,
        color: null,
        tags: const [],
        setWhen: true,
        date: today7,
        time: today7,
        reminder: const Reminder(repeat: RepeatKind.daily),
      );
      editor().answerDone(id);
      expect(node().status, NodeStatus.pending);
      final due = Timing.dueAt(node())!;
      expect(due.isAfter(now), isTrue);
      expect(due.hour, 7);
      await editor().flush();
    });

    test('not yet moves the time and marks it not yet', () async {
      editor().snooze(id, DateTime(2026, 12, 1, 18, 5));
      expect(node().status, NodeStatus.notYet);
      expect((node().date, node().time), ('2026-12-01', '18:05'));
      await editor().flush();
    });

    test('a reminder is dropped when the time is cleared', () async {
      editor().editNode(
        id,
        title: 'Walk',
        notes: '',
        status: NodeStatus.pending,
        color: null,
        tags: const [],
        setWhen: true,
        date: DateTime(2026, 11, 10),
        time: null,
        reminder: const Reminder(),
      );
      expect(node().date, '2026-11-10');
      expect(node().time, isNull);
      expect(node().reminder, isNull);
      await editor().flush();
    });
  });
  test('voice notes add, re-record, delete and undo', () async {
    final rootId = state().board.root.id;
    VoiceNote v(String id) => VoiceNote(
      id: id,
      path: 'audio/$id.m4a',
      createdAt: DateTime.utc(2026, 11, 10),
    );
    List<String> ids() => [
      for (final n in TreeOps.find(state().board.root, rootId)!.voiceNotes)
        n.id,
    ];
    final target = editor().newVoicePath('m4a');
    expect(target.path, 'audio/${target.id}.m4a');
    editor().addVoiceNote(rootId, v('a'));
    editor().addVoiceNote(rootId, v('b'));
    editor().replaceVoiceNote(rootId, 'a', v('c'));
    expect(ids(), ['c', 'b']);
    editor().removeVoiceNote(rootId, 'c');
    expect(ids(), ['b']);
    editor().undo();
    expect(ids(), ['c', 'b']);
    await editor().flush();
  });
}
