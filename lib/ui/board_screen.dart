import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/node.dart';
import '../state/providers.dart';
import 'format.dart';
import 'theme.dart';

/// Placeholder until the canvas and outline view arrive in phase 2.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider(boardId));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(board.value?.title ?? '')),
      body: board.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not open board.\n$e')),
        data: (board) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Metrics.gutter * 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  board.root.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Metrics.gap),
                Text(
                  '${board.root.type == NodeType.task ? 'Task' : 'Decision'}'
                  ' · ${plural(board.nodeCount, 'node', 'nodes')}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: Metrics.gutter * 2),
                Text(
                  'The tree view is coming next.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
