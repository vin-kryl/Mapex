import 'dart:io';

import 'package:flutter/foundation.dart';

/// Makes double-clicking a board file open Mapex on Windows and Linux. The
/// apps there are unzipped rather than installed, so nothing else would
/// tell the system about the file type. Only the current user's settings
/// are touched, and it is redone whenever the app has moved.
///
/// macOS and Android declare the file type in the app itself.
abstract final class FileAssociation {
  static const extension = 'mapex';
  static const _progId = 'Mapex.Board';
  static const _mime = 'application/x-mapex';

  static Future<void> ensure() async {
    try {
      if (Platform.isWindows) await _windows(Platform.resolvedExecutable);
      if (Platform.isLinux) await _linux(Platform.resolvedExecutable);
    } on Object catch (e) {
      // Opening files from inside the app still works.
      debugPrint('Could not register .$extension files: $e');
    }
  }

  static Future<void> _windows(String exe) async {
    const classes = r'HKCU\Software\Classes';
    final command = '"$exe" "%1"';
    final current = await Process.run('reg', [
      'query',
      '$classes\\$_progId\\shell\\open\\command',
      '/ve',
    ]);
    if (current.exitCode == 0 && '${current.stdout}'.contains(command)) return;
    Future<void> set(String key, String value) async {
      final r = await Process.run('reg', [
        'add',
        key,
        '/ve',
        '/d',
        value,
        '/f',
      ]);
      if (r.exitCode != 0) throw ProcessException('reg', [key], '${r.stderr}');
    }

    await set('$classes\\.$extension', _progId);
    await set('$classes\\$_progId', 'Mapex board');
    await set('$classes\\$_progId\\DefaultIcon', '"$exe",0');
    await set('$classes\\$_progId\\shell\\open\\command', command);
  }

  static Future<void> _linux(String exe) async {
    final home = Platform.environment['HOME'];
    if (home == null) return;
    final data = Platform.environment['XDG_DATA_HOME'] ?? '$home/.local/share';
    final desktop = File('$data/applications/com.apeaxis.mapex.desktop');
    final entry = linuxDesktopEntry(exe);
    if (await desktop.exists() && await desktop.readAsString() == entry) return;

    final mime = File('$data/mime/packages/com.apeaxis.mapex.xml');
    await mime.parent.create(recursive: true);
    await mime.writeAsString(linuxMimeXml);
    await desktop.parent.create(recursive: true);
    await desktop.writeAsString(entry);
    // Present on most desktops; harmless if missing.
    for (final (cmd, args) in [
      ('update-mime-database', ['$data/mime']),
      ('update-desktop-database', ['$data/applications']),
      ('xdg-mime', ['default', 'com.apeaxis.mapex.desktop', _mime]),
    ]) {
      try {
        await Process.run(cmd, args);
      } on ProcessException {
        continue;
      }
    }
  }

  @visibleForTesting
  static String linuxDesktopEntry(String exe) {
    final quoted = '"${exe.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
    final icon = '${File(exe).parent.path}/data/flutter_assets/assets/icon.png';
    return '[Desktop Entry]\n'
        'Type=Application\n'
        'Name=Mapex\n'
        'Comment=Untangle your thoughts into a plan\n'
        'Exec=$quoted %f\n'
        'Icon=$icon\n'
        'MimeType=$_mime;\n'
        'Categories=Office;\n'
        'Terminal=false\n';
  }

  static const linuxMimeXml =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">\n'
      '  <mime-type type="$_mime">\n'
      '    <comment>Mapex board</comment>\n'
      '    <glob pattern="*.$extension"/>\n'
      '  </mime-type>\n'
      '</mime-info>\n';
}
