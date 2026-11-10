import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'reminders/alert_platform.dart';
import 'settings/settings_store.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // App-private folder: on Android the app's files dir, on macOS the
  // sandboxed Application Support folder.
  final support = await getApplicationSupportDirectory();
  final appDir = Directory('${support.path}${Platform.pathSeparator}mapex');
  await appDir.create(recursive: true);
  final settings = await SettingsStore(appDir).load();

  final alerts = LocalAlertPlatform();
  final container = ProviderContainer(
    overrides: [
      appDirProvider.overrideWithValue(appDir),
      initialSettingsProvider.overrideWithValue(settings),
      alertPlatformProvider.overrideWithValue(alerts),
    ],
  );
  await alerts.init(
    (payload) => container.read(pendingPromptProvider.notifier).show(payload),
  );
  final launched = await alerts.launchPayload();
  if (launched != null) {
    container.read(pendingPromptProvider.notifier).show(launched);
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const MapexApp()),
  );

  // Top up repeating reminders and drop any for boards that are gone.
  final boards = await container.read(boardRepositoryProvider).loadAllBoards();
  await container.read(reminderSchedulerProvider).syncAll(boards);
}
