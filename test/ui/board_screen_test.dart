import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapex/model/node.dart';
import 'package:mapex/model/tree_ops.dart';
import 'package:mapex/settings/app_settings.dart';
import 'package:mapex/state/board_editor.dart';
import 'package:mapex/state/providers.dart';
import 'package:mapex/storage/board_repository.dart';
import 'package:mapex/ui/board/board_screen.dart';
import 'package:mapex/ui/board/node_card.dart';
import 'package:mapex/ui/theme.dart';

void main() {
  late Directory tmp;
  late String boardId;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mapex_board_ui_');
  });

  // Synchronous on purpose: async file calls never finish inside a widget
  // test's fake clock once the test body has ended.
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // A save still in flight can recreate a file; the OS cleans temp.
    }
  });

  Future<ProviderContainer> open(
    WidgetTester tester, {
    NodeType rootType = NodeType.task,
  }) async {
    await tester.runAsync(() async {
      final repo = BoardRepository(root: tmp, historyCap: () => 200);
      boardId = (await repo.createBoard('Trip', rootType: rootType)).id;
    });
    final container = ProviderContainer(
      overrides: [appDirProvider.overrideWithValue(tmp)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Brightness.light, AppSettings.defaults),
          home: BoardScreen(boardId: boardId),
        ),
      ),
    );
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byTooltip('Outline view').evaluate().isNotEmpty) break;
    }
    return container;
  }

  Node root(ProviderContainer c) =>
      c.read(boardEditorProvider(boardId)).requireValue.board.root;

  /// Saves are file work started inside the test's fake clock, so they only
  /// finish if we alternate real time and pumps until they are done.
  Future<void> flush(WidgetTester tester, ProviderContainer c) async {
    var done = false;
    unawaited(
      c.read(boardEditorProvider(boardId).notifier).flush().then((_) {
        done = true;
      }),
    );
    for (var i = 0; i < 200 && !done; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(done, isTrue, reason: 'saves did not finish');
  }

  Future<void> addChild(WidgetTester tester, String title) async {
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), title);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
  }

  testWidgets('tap, plus, type, repeat builds a branch', (tester) async {
    final c = await open(tester);
    await tester.tap(find.widgetWithText(NodeCard, 'Trip'));
    await tester.pump();
    await tester.pumpAndSettle();
    await addChild(tester, 'Book flights');
    // The new child is selected, so the next add goes under it.
    await addChild(tester, 'Compare prices');
    final r = root(c);
    expect(r.children.single.title, 'Book flights');
    expect(r.children.single.children.single.title, 'Compare prices');
    expect(find.text('Compare prices'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo Add'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Compare prices'), findsNothing);
    await flush(tester, c);
  });

  testWidgets('deciding greys out the others', (tester) async {
    final c = await open(tester, rootType: NodeType.decision);
    final editor = c.read(boardEditorProvider(boardId).notifier);
    final rootId = root(c).id;
    editor.addChild(rootId, 'Train');
    editor.addChild(rootId, 'Plane');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NodeCard, 'Trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decide'));
    await tester.pumpAndSettle();
    expect(find.text('Which of these did you do?'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Plane'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final r = root(c);
    final train = r.children.firstWhere((n) => n.title == 'Train');
    expect(train.status, NodeStatus.eliminated);
    expect(r.chosenChildIds, [
      r.children.firstWhere((n) => n.title == 'Plane').id,
    ]);
    // Still on the board, faded.
    expect(
      find.ancestor(of: find.text('Train'), matching: find.byType(Opacity)),
      findsWidgets,
    );
    await flush(tester, c);
  });

  testWidgets('outline view shows the same tree', (tester) async {
    final c = await open(tester);
    final editor = c.read(boardEditorProvider(boardId).notifier);
    final a = editor.addChild(root(c).id, 'Pack');
    editor.addChild(a, 'Charger');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Outline view'));
    await tester.pumpAndSettle();
    expect(find.text('Charger'), findsOneWidget);
    await tester.tap(find.byTooltip('Collapse').first);
    await tester.pumpAndSettle();
    expect(find.text('Charger'), findsNothing);
    expect(TreeOps.find(root(c), root(c).id)!.collapsed, isTrue);
    await flush(tester, c);
  });
}
