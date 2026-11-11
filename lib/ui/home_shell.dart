import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/incoming_files.dart';
import '../reminders/plan.dart';
import '../state/providers.dart';
import 'board_list_screen.dart';
import 'export_import.dart';
import 'prompt_sheet.dart';
import 'shell/desktop_shell.dart';
import 'theme.dart';
import 'today_screen.dart';

/// Wide windows below this use the phone layout.
const desktopBreakpoint = 900.0;

/// The home screen: a sidebar window on desktops and wide screens, and
/// Boards and Today tabs on phones. Also shows the prompt for a tapped
/// notification, and imports board files opened from outside.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _tab = 0;
  final _desktop = DesktopShellController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A notification tapped before the app was running.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(pendingPromptProvider);
      if (pending != null) _openPrompt(pending);
      _importIncoming();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _desktop.dispose();
    super.dispose();
  }

  /// Coming back to the app: refresh Today, and top up repeating reminders.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(allBoardsProvider);
    ref.read(allBoardsProvider.future).then((boards) {
      return ref.read(reminderSchedulerProvider).syncAll(boards);
    }).ignore();
  }

  Future<void> _openPrompt(AlertPayload p) async {
    ref.read(pendingPromptProvider.notifier).clear();
    await showPromptSheet(context, ref, boardId: p.boardId, nodeId: p.nodeId);
    ref.invalidate(allBoardsProvider);
  }

  bool _importing = false;

  /// Board files opened from outside the app, one after another.
  Future<void> _importIncoming() async {
    if (_importing) return;
    _importing = true;
    try {
      while (mounted) {
        final file = ref.read(incomingFilesProvider.notifier).take();
        if (file == null) break;
        setState(() => _tab = 0);
        _desktop.show(Pane.boards);
        await importBytes(context, ref, file.bytes);
      }
    } finally {
      _importing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingPromptProvider, (_, next) {
      if (next != null) _openPrompt(next);
    });
    ref.listen(incomingFilesProvider, (_, next) {
      if (next.isNotEmpty) _importIncoming();
    });
    final wide =
        isDesktop || MediaQuery.sizeOf(context).width >= desktopBreakpoint;
    if (wide) return DesktopShell(controller: _desktop);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          BoardListScreen(onSeeToday: () => setState(() => _tab = 1)),
          const TodayScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          if (i == 1) ref.invalidate(allBoardsProvider);
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Boards',
          ),
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Today',
          ),
        ],
      ),
    );
  }
}
