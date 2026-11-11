import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A board file opened from outside the app: Finder, Files, Explorer, the
/// share sheet, or a path on the command line.
class IncomingFile {
  const IncomingFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Files waiting to be imported. The home screen takes them one at a time.
class IncomingFiles extends Notifier<List<IncomingFile>> {
  @override
  List<IncomingFile> build() => const [];

  void add(IncomingFile file) => state = [...state, file];

  IncomingFile? take() {
    if (state.isEmpty) return null;
    final first = state.first;
    state = state.sublist(1);
    return first;
  }
}

final incomingFilesProvider =
    NotifierProvider<IncomingFiles, List<IncomingFile>>(IncomingFiles.new);

/// Connects the platform side to [IncomingFiles].
///
/// Android, iOS and macOS hand files over on the `sortle/files` channel:
/// the app asks for any that arrived before it was ready, then is told about
/// new ones. Windows and Linux pass the file path as a command-line argument.
abstract final class IncomingFileSource {
  static const channel = MethodChannel('sortle/files');

  /// Largest file accepted, the same cap as import itself.
  static const _maxBytes = 1024 * 1024 * 1024;

  static Future<void> listen(
    List<String> args,
    void Function(IncomingFile file) onFile,
  ) async {
    for (final path in args) {
      final file = await _readPath(path);
      if (file != null) onFile(file);
    }
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'opened') {
        final file = fromMessage(call.arguments);
        if (file != null) onFile(file);
      }
      return null;
    });
    try {
      final queued = await channel.invokeListMethod<Object?>('takeQueued');
      for (final m in queued ?? const <Object?>[]) {
        final file = fromMessage(m);
        if (file != null) onFile(file);
      }
    } on MissingPluginException {
      // An older build of the native side: nothing to take.
    }
  }

  /// `{name: String, bytes: Uint8List}` from the native side.
  static IncomingFile? fromMessage(Object? message) {
    if (message is! Map) return null;
    final name = message['name'];
    final bytes = message['bytes'];
    if (name is! String || bytes is! Uint8List) return null;
    return IncomingFile(name: name, bytes: bytes);
  }

  static Future<IncomingFile?> _readPath(String path) async {
    final lower = path.toLowerCase();
    if (!const ['.sortle', '.mapex', '.json'].any(lower.endsWith)) return null;
    final file = File(path);
    try {
      if (!await file.exists() || await file.length() > _maxBytes) return null;
      return IncomingFile(
        name: file.uri.pathSegments.last,
        bytes: await file.readAsBytes(),
      );
    } on FileSystemException {
      return null;
    }
  }
}
