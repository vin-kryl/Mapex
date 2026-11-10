/// Thrown when a board file does not match the schema.
class SchemaException implements Exception {
  SchemaException(this.message);

  final String message;

  @override
  String toString() => 'SchemaException: $message';
}

Map<String, Object?> readMap(Object? value, String path) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw SchemaException('$path must be an object');
}

String readString(Map<String, Object?> map, String key, String path) {
  final value = map[key];
  if (value is String) return value;
  throw SchemaException('$path.$key must be text');
}

String? readOptionalString(Map<String, Object?> map, String key, String path) {
  final value = map[key];
  if (value == null || value is String) return value as String?;
  throw SchemaException('$path.$key must be text or null');
}

bool readBool(Map<String, Object?> map, String key, String path) {
  final value = map[key];
  if (value is bool) return value;
  throw SchemaException('$path.$key must be true or false');
}

int readInt(Map<String, Object?> map, String key, String path) {
  final value = map[key];
  if (value is int) return value;
  throw SchemaException('$path.$key must be a whole number');
}

int? readOptionalInt(Map<String, Object?> map, String key, String path) {
  final value = map[key];
  if (value == null || value is int) return value as int?;
  throw SchemaException('$path.$key must be a whole number or null');
}

List<Object?> readList(Map<String, Object?> map, String key, String path) {
  final value = map[key];
  if (value is List) return value;
  throw SchemaException('$path.$key must be a list');
}

List<String> readStringList(Map<String, Object?> map, String key, String path) {
  final list = readList(map, key, path);
  if (list.every((e) => e is String)) return list.cast<String>();
  throw SchemaException('$path.$key must be a list of text');
}

DateTime readDateTime(Map<String, Object?> map, String key, String path) {
  final value = readString(map, key, path);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw SchemaException('$path.$key must be an ISO 8601 date-time');
  }
  return parsed.toUtc();
}

T readEnum<T extends Enum>(List<T> values, Object? value, String path) {
  for (final v in values) {
    if (v.name == value) return v;
  }
  final allowed = values.map((v) => v.name).join(', ');
  throw SchemaException('$path must be one of: $allowed');
}
