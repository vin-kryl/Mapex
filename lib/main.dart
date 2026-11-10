import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'platform/incoming_files.dart';
import 'reminders/alert_platform.dart';
import 'reminders/plan.dart';
import 'settings/settings_store.dart';
import 'state/providers.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // App-private folder: the app's files dir on Android, the sandboxed
  // Application Support folder on macOS, %APPDATA% on Windows and
  // ~/.local/share on Linux.
  final support = await getApplicationSupportDirectory();
  final appDir = Directory('${support.path}${Platform.pathSeparator}mapex');
  await appDir.create(recursive: true);
  final settings = await SettingsStore(appDir).load();

  late final ProviderContainer container;
  // If the system's notification service is not there (for example a Linux
  // desktop without one), the app still runs, just without reminders.
  AlertPlatform alerts = LocalAlertPlatform();
  AlertPayload? launched;
  try {
    await alerts.init(
      (payload) => container.read(pendingPromptProvider.notifier).show(payload),
    );
    launched = await alerts.launchPayload();
  } on Object catch (e) {
    debugPrint('Reminders are off: $e');
    alerts = NoAlertPlatform();
  }
  container = ProviderContainer(
    overrides: [
      appDirProvider.overrideWithValue(appDir),
      initialSettingsProvider.overrideWithValue(settings),
      alertPlatformProvider.overrideWithValue(alerts),
    ],
  );
  if (alerts is LocalAlertPlatform) {
    // Linux: reminders come from timers in the app, so book the next ones
    // each time one fires.
    alerts.inApp?.onFired = () async {
      final boards = await container
          .read(boardRepositoryProvider)
          .loadAllBoards();
      await container.read(reminderSchedulerProvider).syncAll(boards);
    };
  }
  if (launched != null) {
    container.read(pendingPromptProvider.notifier).show(launched);
  }

  // Board files opened from outside: Finder, Files, the share sheet, or a
  // path passed on Windows and Linux.
  unawaited(
    IncomingFileSource.listen(
      args,
      (file) => container.read(incomingFilesProvider.notifier).add(file),
    ),
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const MapexApp()),
  );

  // Top up repeating reminders and drop any for boards that are gone.
  final boards = await container.read(boardRepositoryProvider).loadAllBoards();
  await container.read(reminderSchedulerProvider).syncAll(boards);
}
