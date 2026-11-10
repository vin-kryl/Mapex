import 'dart:convert';
import 'dart:io';

import '../storage/atomic_file.dart';
import 'app_settings.dart';

/// Loads and saves `settings.json` in the app folder.
class SettingsStore {
  SettingsStore(this.root);

  final Directory root;

  static const fileName = 'settings.json';

  File get _file => File('${root.path}${Platform.pathSeparator}$fileName');

  Future<AppSettings> load() async {
    if (!await _file.exists()) return AppSettings.defaults;
    try {
      return AppSettings.fromJson(jsonDecode(await _file.readAsString()));
    } on FormatException {
      return AppSettings.defaults;
    }
  }

  Future<void> save(AppSettings settings) => writeAtomically(
    _file,
    const JsonEncoder.withIndent('  ').convert(settings.toJson()),
  );
}
