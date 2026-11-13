import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/board.dart';
import '../model/templates.dart';
import '../reminders/today.dart';
import '../settings/app_settings.dart';
import '../state/providers.dart';
import '../storage/board_repository.dart';
import 'board/board_preview.dart';
import 'board/node_style.dart';
import 'dialogs.dart';
import 'export_import.dart';
import 'format.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'shell/shell_scope.dart';
import 'theme.dart';
import 'today_screen.dart';
import 'widgets.dart';

enum _BoardAction { rename, duplicate, export, history, trash }

/// The home screen: what is due today, every board with a live preview, and
/// templates to start from.
class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key, this.embedded = false, this.onSeeToday});

  /// Shown in the desktop window's main pane.
  final bool embedded;

  /// Shows the full Today list.
  final VoidCallback? onSeeToday;

  /// How many due items the home screen shows before "See all".
  static const todayPreviewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(boardListProvider);
    final full = ref.watch(allBoardsProvider).value ?? const <Board>[];
    final settings = ref.watch(settingsProvider);
    final today = TodayList.build(full, settings, DateTime.now());
    final t = Tones.of(context);

    final actions = [
      IconButton(
        tooltip: 'Import a board',
        icon: const Icon(Icons.file_download_outlined, size: 20),
        color: t.secondary,
        onPressed: () => importBoard(context, ref),
      ),
      if (!embedded)
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.tune_rounded, size: 20),
          color: t.secondary,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      if (embedded)
        IconButton(
          tooltip: 'New board',
          icon: const Icon(Icons.add_rounded, size: 22),
          color: t.secondary,
          onPressed: () => createBoard(context, ref),
        ),
    ];

    return Scaffold(
      appBar: embedded
          ? AppBar(
              toolbarHeight: 52,
              titleSpacing: 20,
              automaticallyImplyLeading: false,
              title: const Text('All Boards'),
              actions: [...actions, const SizedBox(width: 8)],
            )
          : null,
      floatingActionButton: embedded
          ? null
          : FloatingActionButton(
              tooltip: 'New board',
              onPressed: () => createBoard(context, ref),
              child: const Icon(Icons.add_rounded, size: 26),
            ),
      body: listing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => QuietMessage(text: 'Could not read boards.\n$e'),
        data: (listing) {
          final byId = {for (final b in full) b.id: b};
          final pad = embedded ? 36.0 : 20.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              pad,
              embedded ? 24 : MediaQuery.paddingOf(context).top + 20,
              pad,
              96,
            ),
            children: [
              if (!embedded) ...[
                Row(
                  children: [
                    Expanded(child: Text('Boards', style: largeTitle(context))),
                    ...actions,
                  ],
                ),
                const SizedBox(height: 18),
              ],
              if (today.isNotEmpty) ...[
                Section(
                  title: 'Today',
                  action: today.length > todayPreviewCount ? 'See all' : null,
                  onAction: onSeeToday,
                  child: GroupedBox(
                    children: [
                      for (final item in today.take(todayPreviewCount))
                        TodayRow(item: item),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
              if (listing.boards.isEmpty && listing.broken.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: QuietMessage(
                    icon: Icons.account_tree_outlined,
                    text:
                        'No boards yet.\n'
                        'Start from a template below, or press + for a '
                        'blank board.',
                  ),
                )
              else
                Section(
                  title: 'Recent',
                  child: _BoardGrid(
                    boards: listing.boards,
                    full: byId,
                    direction: settings.layoutDirection,
                  ),
                ),
              for (final broken in listing.broken)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GroupedBox(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: const Text('A board could not be opened'),
                        subtitle: Text(broken.reason),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
              Section(
                title: 'Start from a template',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tpl in BoardTemplate.all)
                      _TemplateChip(
                        template: tpl,
                        onTap: () => _fromTemplate(context, ref, tpl),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _fromTemplate(
    BuildContext context,
    WidgetRef ref,
    BoardTemplate template,
  ) async {
    final title = await askForTitle(
      context,
      heading: template.title,
      action: 'Create',
      initial: template.title,
    );
    if (title == null || !context.mounted) return;
    final board = await ref
        .read(boardRepositoryProvider)
        .createFromTemplate(title, template);
    ref.invalidate(boardListProvider);
    if (context.mounted) openBoardAt(context, boardId: board.id);
  }
}

/// Asks for a title, makes a blank board and opens it.
Future<void> createBoard(BuildContext context, WidgetRef ref) async {
  final title = await askForTitle(
    context,
    heading: 'New board',
    action: 'Create',
  );
  if (title == null || !context.mounted) return;
  final board = await ref
      .read(boardRepositoryProvider)
      .createBoard(title, rootType: ref.read(settingsProvider).defaultNodeType);
  ref.invalidate(boardListProvider);
  if (context.mounted) openBoardAt(context, boardId: board.id);
}

class _BoardGrid extends StatelessWidget {
  const _BoardGrid({
    required this.boards,
    required this.full,
    required this.direction,
  });

  final List<BoardSummary> boards;
  final Map<String, Board> full;
  final LayoutDirection direction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = (c.maxWidth / (isDesktop ? 280 : 170)).floor().clamp(
          1,
          4,
        );
        const gap = 16.0;
        final width = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 20,
          children: [
            for (final b in boards)
              SizedBox(
                width: width,
                child: _BoardCard(
                  summary: b,
                  board: full[b.id],
                  direction: direction,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BoardCard extends ConsumerWidget {
  const _BoardCard({
    required this.summary,
    required this.board,
    required this.direction,
  });

  final BoardSummary summary;
  final Board? board;
  final LayoutDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Tones.of(context);
    final now = DateTime.now();
    final b = board;
    final detail = [
      if (b != null) NodeStyle.progress(b.root),
      timeAgo(summary.updatedAt, now),
    ].join(' · ');
    return GestureDetector(
      onSecondaryTapDown: (d) => _menu(context, ref, d.globalPosition),
      onLongPressStart: (d) => _menu(context, ref, d.globalPosition),
      child: InkWell(
        onTap: () => openBoardAt(context, boardId: summary.id),
        borderRadius: BorderRadius.circular(Look.of(context).radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: b == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.grouped,
                        borderRadius: BorderRadius.circular(
                          Look.of(context).radius,
                        ),
                      ),
                    )
                  : BoardPreview(board: b, direction: direction),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isApple ? 13.5 : 14.5,
                          fontWeight: FontWeight.w500,
                          color: t.text,
                        ),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.secondary),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (button) => IconButton(
                    tooltip: 'Board options',
                    icon: const Icon(Icons.more_horiz_rounded, size: 18),
                    color: t.secondary,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final box = button.findRenderObject()! as RenderBox;
                      _menu(
                        context,
                        ref,
                        box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, Offset at) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<_BoardAction>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: _BoardAction.rename, child: Text('Rename')),
        PopupMenuItem(value: _BoardAction.duplicate, child: Text('Duplicate')),
        PopupMenuItem(value: _BoardAction.export, child: Text('Export')),
        PopupMenuItem(value: _BoardAction.history, child: Text('History')),
        PopupMenuItem(value: _BoardAction.trash, child: Text('Move to trash')),
      ],
    );
    if (action != null && context.mounted) {
      await _onAction(context, ref, action);
    }
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _BoardAction action,
  ) async {
    final repo = ref.read(boardRepositoryProvider);
    final board = summary;
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

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.template, required this.onTap});

  final BoardTemplate template;
  final VoidCallback onTap;

  static IconData iconFor(String id) => switch (id) {
    'decision' => Icons.diamond_outlined,
    'trip' => Icons.flight_takeoff_rounded,
    'project' => Icons.flag_outlined,
    _ => Icons.check_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Tooltip(
      message: template.description,
      child: Material(
        color: t.grouped,
        borderRadius: BorderRadius.circular(isApple ? 8 : 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isApple ? 8 : 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconFor(template.id), size: 16, color: t.secondary),
                const SizedBox(width: 8),
                Text(
                  template.title,
                  style: TextStyle(fontSize: 13.5, color: t.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
