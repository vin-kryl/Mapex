import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapex/model/node.dart';
import 'package:mapex/model/tree_ops.dart';
import 'package:mapex/settings/app_settings.dart';
import 'package:mapex/state/board_editor.dart';
import 'package:mapex/state/providers.dart';
import 'package:mapex/storage/board_repository.dart';

void main() {
  late Directory tmp;
  late ProviderContainer c;
  late String boardId;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mapex_editor_');
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
}
