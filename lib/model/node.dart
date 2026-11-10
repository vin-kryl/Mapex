import 'json_read.dart';
import 'reminder.dart';
import 'voice_note.dart';

/// Task nodes hold steps that can all be done. Decision nodes hold
/// alternatives, of which one, several or none get picked.
enum NodeType {
  task,
  decision;

  static NodeType fromJson(Object? value, String path) =>
      readEnum(NodeType.values, value, path);
}

enum NodeStatus {
  pending,
  done,

  /// "Not yet / push it".
  notYet,

  /// An alternative that was not picked. Kept in the tree, never deleted.
  eliminated;

  static NodeStatus fromJson(Object? value, String path) =>
      readEnum(NodeStatus.values, value, path);
}

/// One node of a board's tree. Immutable; edits return a new node.
class Node {
  const Node({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.date,
    this.time,
    this.reminder,
    this.voiceNotes = const [],
    this.color,
    this.tags = const [],
    this.chosenChildIds = const [],
    this.collapsed = false,
    this.children = const [],
  });

  final String id;
  final String title;
  final NodeType type;
  final NodeStatus status;
  final String notes;

  /// Calendar date as `YYYY-MM-DD`, or null.
  final String? date;

  /// Local time as `HH:mm`, or null.
  final String? time;
  final Reminder? reminder;
  final List<VoiceNote> voiceNotes;

  /// Colour as `#RRGGBB`, or null for the theme default.
  final String? color;
  final List<String> tags;

  /// Decision nodes only: the children that were picked (the taken paths).
  final List<String> chosenChildIds;
  final bool collapsed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Node> children;

  /// This node plus every node below it.
  int get nodeCount =>
      1 + children.fold(0, (sum, child) => sum + child.nodeCount);

  Node copyWith({
    String? id,
    String? title,
    NodeType? type,
    NodeStatus? status,
    String? notes,
    String? Function()? date,
    String? Function()? time,
    Reminder? Function()? reminder,
    List<VoiceNote>? voiceNotes,
    String? Function()? color,
    List<String>? tags,
    List<String>? chosenChildIds,
    bool? collapsed,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Node>? children,
  }) {
    return Node(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      date: date != null ? date() : this.date,
      time: time != null ? time() : this.time,
      reminder: reminder != null ? reminder() : this.reminder,
      voiceNotes: voiceNotes ?? this.voiceNotes,
      color: color != null ? color() : this.color,
      tags: tags ?? this.tags,
      chosenChildIds: chosenChildIds ?? this.chosenChildIds,
      collapsed: collapsed ?? this.collapsed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      children: children ?? this.children,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    'status': status.name,
    'notes': notes,
    'date': date,
    'time': time,
    'reminder': reminder?.toJson(),
    'voiceNotes': [for (final v in voiceNotes) v.toJson()],
    'color': color,
    'tags': tags,
    'chosenChildIds': chosenChildIds,
    'collapsed': collapsed,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'children': [for (final c in children) c.toJson()],
  };

  static Node fromJson(Object? json, String path) {
    final map = readMap(json, path);
    final title = readString(map, 'title', path);
    if (title.trim().isEmpty) {
      throw SchemaException('$path.title must not be empty');
    }
    final date = readOptionalString(map, 'date', path);
    if (date != null && !_datePattern.hasMatch(date)) {
      throw SchemaException('$path.date must look like YYYY-MM-DD');
    }
    final time = readOptionalString(map, 'time', path);
    if (time != null && !_timePattern.hasMatch(time)) {
      throw SchemaException('$path.time must look like HH:mm');
    }
    final color = readOptionalString(map, 'color', path);
    if (color != null && !_colorPattern.hasMatch(color)) {
      throw SchemaException('$path.color must look like #RRGGBB');
    }
    final childrenJson = readList(map, 'children', path);
    final children = [
      for (var i = 0; i < childrenJson.length; i++)
        Node.fromJson(childrenJson[i], '$path.children[$i]'),
    ];
    final chosen = readStringList(map, 'chosenChildIds', path);
    final childIds = {for (final c in children) c.id};
    for (final id in chosen) {
      if (!childIds.contains(id)) {
        throw SchemaException(
          '$path.chosenChildIds has "$id", which is not a child',
        );
      }
    }
    final voiceJson = readList(map, 'voiceNotes', path);
    final reminderJson = map['reminder'];
    return Node(
      id: readString(map, 'id', path),
      title: title,
      type: NodeType.fromJson(map['type'], '$path.type'),
      status: NodeStatus.fromJson(map['status'], '$path.status'),
      notes: readString(map, 'notes', path),
      date: date,
      time: time,
      reminder: reminderJson == null
          ? null
          : Reminder.fromJson(reminderJson, '$path.reminder'),
      voiceNotes: [
        for (var i = 0; i < voiceJson.length; i++)
          VoiceNote.fromJson(voiceJson[i], '$path.voiceNotes[$i]'),
      ],
      color: color,
      tags: readStringList(map, 'tags', path),
      chosenChildIds: chosen,
      collapsed: readBool(map, 'collapsed', path),
      createdAt: readDateTime(map, 'createdAt', path),
      updatedAt: readDateTime(map, 'updatedAt', path),
      children: children,
    );
  }

  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  static final _colorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
}
