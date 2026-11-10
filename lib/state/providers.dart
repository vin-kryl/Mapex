import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/board.dart';
import '../reminders/alert_platform.dart';
import '../reminders/plan.dart';
import '../reminders/scheduler.dart';
import '../settings/app_settings.dart';
import '../settings/settings_store.dart';
import '../storage/board_repository.dart';

/// The app-private folder that holds everything. Overridden in main() with
/// the platform folder, and in tests with a temporary one.
final appDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('appDirProvider must be overridden'),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(appDirProvider)),
);

/// Settings loaded at startup; overridden in main().
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => AppSettings.defaults,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  Future<void> update(AppSettings settings) async {
    final before = state;
    state = settings;
    await ref.read(settingsStoreProvider).save(settings);
    final remindersChanged =
        before.defaultReminderLeadMinutes !=
            settings.defaultReminderLeadMinutes ||
        before.decisionPromptDelayMinutes !=
            settings.decisionPromptDelayMinutes ||
        before.notificationSound != settings.notificationSound ||
        before.repeatsScheduledAhead != settings.repeatsScheduledAhead;
    if (remindersChanged) {
      final boards = await ref.read(boardRepositoryProvider).loadAllBoards();
      await ref.read(reminderSchedulerProvider).syncAll(boards);
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(
    root: ref.watch(appDirProvider),
    // Read on every save, so a changed cap applies straight away.
    historyCap: () => ref.read(settingsProvider).historyCap,
    onSaved: (board) => ref.read(reminderSchedulerProvider).syncBoard(board),
    onRemoved: (id) => ref.read(reminderSchedulerProvider).removeBoard(id),
  ),
);

final boardListProvider = FutureProvider<BoardListing>(
  (ref) => ref.watch(boardRepositoryProvider).listBoards(),
);

final trashListProvider = FutureProvider<BoardListing>(
  (ref) => ref.watch(boardRepositoryProvider).listTrash(),
);

final boardProvider = FutureProvider.family(
  (ref, String id) => ref.watch(boardRepositoryProvider).loadBoard(id),
);

final historyProvider = FutureProvider.family(
  (ref, String id) => ref.watch(boardRepositoryProvider).listHistory(id),
);

/// Every board in full, for the Today screen.
final allBoardsProvider = FutureProvider<List<Board>>((ref) async {
  ref.watch(boardListProvider);
  return ref.watch(boardRepositoryProvider).loadAllBoards();
});

/// The system notification service. Overridden in main() with the real one.
final alertPlatformProvider = Provider<AlertPlatform>(
  (ref) => NoAlertPlatform(),
);

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(
    platform: ref.watch(alertPlatformProvider),
    settings: () => ref.read(settingsProvider),
  ),
);

/// A tapped notification waiting to be shown as a prompt.
class PendingPrompt extends Notifier<AlertPayload?> {
  @override
  AlertPayload? build() => null;

  void show(AlertPayload payload) => state = payload;

  void clear() => state = null;
}

final pendingPromptProvider = NotifierProvider<PendingPrompt, AlertPayload?>(
  PendingPrompt.new,
);
