import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../storage/board_repository.dart';
import 'board/board_screen.dart';
import 'dialogs.dart';
import 'export_import.dart';
import 'format.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'trash_screen.dart';

enum _BoardAction { rename, duplicate, export, history, trash }

class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(boardListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boards'),
        actions: [
          IconButton(
            tooltip: 'Import a board',
            icon: const Icon(Icons.file_open_outlined),
            onPressed: () => importBoard(context, ref),
          ),
          IconButton(
            tooltip: 'Trash',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TrashScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: Metrics.gutter / 2),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New board'),
      ),
      body: listing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Centered(text: 'Could not read boards.\n$e'),
        data: (listing) {
          if (listing.boards.isEmpty && listing.broken.isEmpty) {
            return const _Centered(
              text: 'No boards yet.\nTap "New board" to start one.',
            );
          }
          return _BoardList(listing: listing);
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final title = await askForTitle(
      context,
      heading: 'New board',
      action: 'Create',
    );
    if (title == null || !context.mounted) return;
    final repo = ref.read(boardRepositoryProvider);
    final board = await repo.createBoard(
      title,
      rootType: ref.read(settingsProvider).defaultNodeType,
    );
    ref.invalidate(boardListProvider);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => BoardScreen(boardId: board.id)),
    );
  }
}

class _BoardList extends ConsumerWidget {
  const _BoardList({required this.listing});

  final BoardListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final items = <Widget>[
      for (final board in listing.boards)
        _BoardTile(
          board: board,
          subtitle:
              '${plural(board.nodeCount, 'node', 'nodes')} · '
              'edited ${timeAgo(board.updatedAt, now)}',
        ),
      for (final broken in listing.broken)
        Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('A board could not be opened'),
            subtitle: Text(broken.reason),
          ),
        ),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Metrics.maxContentWidth),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            Metrics.gutter,
            Metrics.gutter / 2,
            Metrics.gutter,
            Metrics.gutter * 6,
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: Metrics.gap),
          itemBuilder: (_, i) => items[i],
        ),
      ),
    );
  }
}

class _BoardTile extends ConsumerWidget {
  const _BoardTile({required this.board, required this.subtitle});

  final BoardSummary board;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Look.of(context).nodeColors;
    final accent = colors[board.id.hashCode.abs() % colors.length];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Metrics.gutter,
          vertical: Metrics.gap / 2,
        ),
        leading: CircleAvatar(
          backgroundColor: accent,
          foregroundColor: onColor(accent),
          child: Text(board.title.characters.first.toUpperCase()),
        ),
        title: Text(
          board.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => _open(context),
        trailing: PopupMenuButton<_BoardAction>(
          tooltip: 'Board options',
          onSelected: (action) => _onAction(context, ref, action),
          itemBuilder: (_) => const [
            PopupMenuItem(value: _BoardAction.rename, child: Text('Rename')),
            PopupMenuItem(
              value: _BoardAction.duplicate,
              child: Text('Duplicate'),
            ),
            PopupMenuItem(value: _BoardAction.export, child: Text('Export')),
            PopupMenuItem(value: _BoardAction.history, child: Text('History')),
            PopupMenuItem(
              value: _BoardAction.trash,
              child: Text('Move to trash'),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => BoardScreen(boardId: board.id)),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _BoardAction action,
  ) async {
    final repo = ref.read(boardRepositoryProvider);
    void refresh() {
      ref.invalidate(boardListProvider);
      ref.invalidate(boardProvider(board.id));
      ref.invalidate(historyProvider(board.id));
    }

    switch (action) {
      case _BoardAction.rename:
        final title = await askForTitle(
          context,
          heading: 'Rename board',
          action: 'Rename',
          initial: board.title,
        );
        if (title == null || title == board.title) return;
        await repo.renameBoard(board.id, title);
        refresh();
      case _BoardAction.duplicate:
        await repo.duplicateBoard(board.id, title: '${board.title} copy');
        refresh();
        if (context.mounted) showMessage(context, 'Board duplicated');
      case _BoardAction.export:
        await exportBoard(context, ref, boardId: board.id);
      case _BoardAction.history:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HistoryScreen(boardId: board.id),
          ),
        );
      case _BoardAction.trash:
        final ok = await confirm(
          context,
          heading: 'Move to trash?',
          message:
              '"${board.title}" will move to the trash. '
              'You can restore it from there.',
          action: 'Move to trash',
          destructive: true,
        );
        if (!ok) return;
        await repo.moveToTrash(board.id);
        refresh();
        ref.invalidate(trashListProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Moved to trash'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await repo.restoreFromTrash(board.id);
                  refresh();
                  ref.invalidate(trashListProvider);
                },
              ),
            ),
          );
    }
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Metrics.gutter * 2),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
