import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../storage/board_repository.dart';
import 'dialogs.dart';
import 'format.dart';
import 'theme.dart';

/// Saved versions of one board, newest first, each one revertible.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider(boardId));
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not read history.\n$e')),
        data: (entries) {
          final now = DateTime.now();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Metrics.maxContentWidth,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(Metrics.gutter),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: Metrics.gap),
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  return Card(
                    child: ListTile(
                      title: Text(entry.label),
                      subtitle: Text(timeAgo(entry.savedAt, now)),
                      trailing: i == 0
                          ? const Text('Current')
                          : TextButton(
                              onPressed: () => _revert(context, ref, entry),
                              child: const Text('Revert'),
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

  Future<void> _revert(
    BuildContext context,
    WidgetRef ref,
    HistoryEntry entry,
  ) async {
    final ok = await confirm(
      context,
      heading: 'Revert to this version?',
      message: 'The current version stays in history, so you can come back.',
      action: 'Revert',
    );
    if (!ok) return;
    await ref.read(boardRepositoryProvider).revertTo(boardId, entry.id);
    ref.invalidate(historyProvider(boardId));
    ref.invalidate(boardProvider(boardId));
    ref.invalidate(boardListProvider);
    if (context.mounted) showMessage(context, 'Reverted');
  }
}
