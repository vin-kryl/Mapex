import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Asks for notification permission the first time a reminder is set, and
/// not again after that (the system settings are the place to change it).
Future<void> askForRemindersOnce(WidgetRef ref) async {
  final dir = ref.read(appDirProvider);
  final marker = File('${dir.path}${Platform.pathSeparator}.reminders-asked');
  if (await marker.exists()) return;
  await ref.read(alertPlatformProvider).requestPermissions();
  await marker.writeAsString(DateTime.now().toUtc().toIso8601String());
}
