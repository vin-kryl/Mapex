import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
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
  runApp(
    ProviderScope(
      overrides: [
        appDirProvider.overrideWithValue(appDir),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const MapexApp(),
    ),
  );
}
