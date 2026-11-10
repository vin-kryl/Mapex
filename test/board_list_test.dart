import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapex/app.dart';
import 'package:mapex/model/node.dart';
import 'package:mapex/state/providers.dart';
import 'package:mapex/storage/board_repository.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mapex_ui_');
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

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDirProvider.overrideWithValue(tmp)],
        child: const MapexApp(),
      ),
    );
  }

  /// File work needs the real event loop, which widget tests only run
  /// inside runAsync. Keep yielding to it until loading spinners are gone.
  /// Pass [until] to wait for a specific result.
  Future<void> settle(WidgetTester tester, {Finder? until}) async {
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final idle = find.byType(CircularProgressIndicator).evaluate().isEmpty;
      final done = until == null ? i > 3 : until.evaluate().isNotEmpty;
      if (idle && done) break;
    }
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows an empty state with no boards', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    expect(find.textContaining('No boards yet'), findsOneWidget);
  });

  testWidgets('lists existing boards', (tester) async {
    await tester.runAsync(() async {
      final repo = BoardRepository(root: tmp, historyCap: () => 200);
      await repo.createBoard('Career', rootType: NodeType.task);
      await repo.createBoard('Health', rootType: NodeType.decision);
    });
    await pumpApp(tester);
    await settle(tester);
    expect(find.text('Career'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
  });

  testWidgets('creating a board opens it', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('New board'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Side project');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await settle(tester, until: find.byTooltip('Outline view'));
    // Title in the app bar and on the root node.
    expect(find.text('Side project'), findsNWidgets(2));
  });

  testWidgets('moving to trash asks first', (tester) async {
    await tester.runAsync(() async {
      final repo = BoardRepository(root: tmp, historyCap: () => 200);
      await repo.createBoard('Career', rootType: NodeType.task);
    });
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.byTooltip('Board options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to trash'));
    await tester.pumpAndSettle();
    expect(find.text('Move to trash?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Career'), findsOneWidget);

    await tester.tap(find.byTooltip('Board options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move to trash'));
    await settle(tester, until: find.textContaining('No boards yet'));
    expect(find.text('Career'), findsNothing);
    expect(find.text('Moved to trash'), findsOneWidget);
  });
}
