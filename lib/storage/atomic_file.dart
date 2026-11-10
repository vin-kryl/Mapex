import 'dart:io';

/// Writes [contents] to [file] via a temporary file and a rename, so a crash
/// mid-write never leaves a half-written board behind.
Future<void> writeAtomically(File file, String contents) async {
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(contents, flush: true);
  await tmp.rename(file.path);
}
