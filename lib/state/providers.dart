import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    state = settings;
    await ref.read(settingsStoreProvider).save(settings);
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
