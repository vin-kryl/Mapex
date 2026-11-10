import 'json_read.dart';

/// A recorded voice note. The audio itself lives in the board's `audio/`
/// folder; only its relative path is kept in the JSON.
class VoiceNote {
  const VoiceNote({
    required this.id,
    required this.path,
    required this.createdAt,
    this.durationMs,
  });

  final String id;

  /// Relative to the board folder, for example `audio/<id>.m4a`.
  final String path;
  final DateTime createdAt;
  final int? durationMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'path': path,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'durationMs': durationMs,
  };

  static VoiceNote fromJson(Object? json, String path) {
    final map = readMap(json, path);
    final file = readString(map, 'path', path);
    if (!file.startsWith('audio/') ||
        file.contains('..') ||
        file.contains('\\')) {
      throw SchemaException('$path.path must stay inside the audio/ folder');
    }
    return VoiceNote(
      id: readString(map, 'id', path),
      path: file,
      createdAt: readDateTime(map, 'createdAt', path),
      durationMs: readOptionalInt(map, 'durationMs', path),
    );
  }
}
