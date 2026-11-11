import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/board.dart';
import '../../reminders/today.dart';
import '../../state/providers.dart';
import '../../storage/board_repository.dart';
import '../board/board_screen.dart';
import '../board/node_style.dart';
import '../board_list_screen.dart';
import '../settings_screen.dart';
import '../theme.dart';
import '../today_screen.dart';
import '../trash_screen.dart';
import 'shell_scope.dart';

/// What the main pane of the desktop window shows.
enum Pane { today, boards, board, trash, settings }

/// The desktop window: a sidebar of places and boards, and the selected one
/// beside it.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key, required this.controller});

  final DesktopShellController controller;

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

/// Lets the app move the desktop window to a pane, for example to show a
/// board opened from a notification.
class DesktopShellController extends ChangeNotifier {
  Pane pane = Pane.boards;
  String? boardId;
  String? nodeId;

  void show(Pane p) {
    pane = p;
    nodeId = null;
    notifyListeners();
  }

  void openBoard(String id, [String? node]) {
    pane = Pane.board;
    boardId = id;
    nodeId = node;
    notifyListeners();
  }
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  DesktopShellController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final Widget pane = switch (_c.pane) {
      Pane.today => const TodayScreen(embedded: true),
      Pane.boards => BoardListScreen(
        embedded: true,
        onSeeToday: () => _c.show(Pane.today),
      ),
      Pane.board => BoardScreen(
        key: ValueKey('${_c.boardId}/${_c.nodeId}'),
        boardId: _c.boardId!,
        initialNodeId: _c.nodeId,
        embedded: true,
      ),
      Pane.trash => const TrashScreen(),
      Pane.settings => const SettingsScreen(),
    };
    return ShellScope(
      onOpenBoard: _c.openBoard,
      child: Scaffold(
        backgroundColor: isMacFrosted ? Colors.transparent : t.window,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Sidebar(controller: _c),
            Expanded(
              child: ColoredBox(
                color: t.window,
                child: ClipRect(child: pane),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Places, then every board, then the trash and settings.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, required this.controller});

  final DesktopShellController controller;

  /// Room for the window's close, minimise and zoom buttons on a Mac, where
  /// the sidebar runs up under the title bar.
  static double get topInset =>
      defaultTargetPlatform == TargetPlatform.macOS ? 52 : 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Tones.of(context);
    final listing = ref.watch(boardListProvider).value;
    final full = ref.watch(allBoardsProvider).value ?? const <Board>[];
    final settings = ref.watch(settingsProvider);
    final todayCount = TodayList.build(full, settings, DateTime.now()).length;
    final byId = {for (final b in full) b.id: b};
    final look = Look.of(context);
    final c = controller;

    Color dotFor(String id) {
      final hex = byId[id]?.root.color;
      final parsed = NodeStyle.parseColor(hex);
      return parsed ??
          look.nodeColors[id.hashCode.abs() % look.nodeColors.length];
    }

    return Container(
      width: Metrics.sidebarWidth,
      decoration: BoxDecoration(
        color: isMacFrosted ? Colors.transparent : t.sidebar,
        border: Border(right: BorderSide(color: t.hairline, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topInset),
          _Item(
            icon: Icons.wb_sunny_outlined,
            label: 'Today',
            count: todayCount,
            selected: c.pane == Pane.today,
            onTap: () => c.show(Pane.today),
          ),
          _Item(
            icon: Icons.grid_view_rounded,
            label: 'All Boards',
            count: listing?.boards.length,
            selected: c.pane == Pane.boards,
            onTap: () => c.show(Pane.boards),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
            child: Text(
              'Boards',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: t.secondary,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final b in listing?.boards ?? const <BoardSummary>[])
                  _Item(
                    dot: dotFor(b.id),
                    label: b.title,
                    selected: c.pane == Pane.board && c.boardId == b.id,
                    onTap: () => c.openBoard(b.id),
                  ),
              ],
            ),
          ),
          _Item(
            icon: Icons.delete_outline_rounded,
            label: 'Trash',
            selected: c.pane == Pane.trash,
            onTap: () => c.show(Pane.trash),
          ),
          _Item(
            icon: Icons.tune_rounded,
            label: 'Settings',
            selected: c.pane == Pane.settings,
            onTap: () => c.show(Pane.settings),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dot,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dot;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0.5),
      child: Material(
        color: selected ? t.hairline : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: t.hairline.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: dot != null
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: t.text),
                  ),
                ),
                if (count != null && count! > 0)
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      color: t.secondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
