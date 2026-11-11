import 'package:flutter/material.dart';

import '../board/board_screen.dart';

/// Lets any screen open a board the way the current layout wants: in the
/// desktop window's main pane, or as its own page on a phone.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.onOpenBoard,
    required super.child,
  });

  final void Function(String boardId, String? nodeId) onOpenBoard;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope old) => old.onOpenBoard != onOpenBoard;
}

/// Opens [boardId], with [nodeId] selected if given.
void openBoardAt(
  BuildContext context, {
  required String boardId,
  String? nodeId,
}) {
  final shell = ShellScope.maybeOf(context);
  if (shell != null) {
    shell.onOpenBoard(boardId, nodeId);
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BoardScreen(boardId: boardId, initialNodeId: nodeId),
    ),
  );
}
