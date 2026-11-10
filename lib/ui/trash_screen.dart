import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../storage/board_repository.dart';
import 'dialogs.dart';
import 'format.dart';
import 'theme.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(trashListProvider);
    final hasItems = trash.value?.boards.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (hasItems)
            TextButton(
              onPressed: () => _empty(context, ref),
              child: const Text('Empty trash'),
            ),
          const SizedBox(width: Metrics.gutter / 2),
        ],
      ),
      body: trash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not read the trash.\n$e')),
        data: (listing) {
          if (listing.boards.isEmpty) {
            return Center(
              child: Text(
                'The trash is empty.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final now = DateTime.now();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Metrics.maxContentWidth,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(Metrics.gutter),
                itemCount: listing.boards.length,
                separatorBuilder: (_, _) => const SizedBox(height: Metrics.gap),
                itemBuilder: (_, i) {
                  final board = listing.boards[i];
                  return Card(
                    child: ListTile(
                      title: Text(
                        board.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Trashed ${timeAgo(board.trashedAt!, now)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Restore',
                            icon: const Icon(Icons.restore),
                            onPressed: () => _restore(context, ref, board),
                          ),
                          IconButton(
                            tooltip: 'Delete forever',
                            icon: const Icon(Icons.delete_forever_outlined),
                            onPressed: () => _delete(context, ref, board),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(trashListProvider);
    ref.invalidate(boardListProvider);
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    BoardSummary board,
  ) async {
    try {
      await ref.read(boardRepositoryProvider).restoreFromTrash(board.id);
      if (context.mounted) showMessage(context, 'Board restored');
    } on Exception catch (e) {
      if (context.mounted) showMessage(context, 'Could not restore: $e');
    }
    _refresh(ref);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BoardSummary board,
  ) async {
    final ok = await confirm(
      context,
      heading: 'Delete forever?',
      message: '"${board.title}" and its voice notes will be gone for good.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(boardRepositoryProvider).deleteForever(board.id);
    _refresh(ref);
  }

  Future<void> _empty(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      heading: 'Empty trash?',
      message: 'Every board in the trash will be gone for good.',
      action: 'Empty trash',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(boardRepositoryProvider).emptyTrash();
    _refresh(ref);
  }
}
