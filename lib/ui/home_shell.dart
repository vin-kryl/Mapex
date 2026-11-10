import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/incoming_files.dart';
import '../reminders/plan.dart';
import '../state/providers.dart';
import 'board_list_screen.dart';
import 'export_import.dart';
import 'prompt_sheet.dart';
import 'today_screen.dart';

/// Today and Boards, with the app opening on Today. Also shows the prompt
/// for a tapped notification, and imports board files opened from outside.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _tab = 0;

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
    setState(() => _tab = 0);
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
        setState(() => _tab = 1);
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
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [TodayScreen(), BoardListScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          if (i == 0) ref.invalidate(allBoardsProvider);
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Boards',
          ),
        ],
      ),
    );
  }
}
