import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sortle/model/board.dart';
import 'package:sortle/model/json_read.dart';
import 'package:sortle/model/node.dart';
import 'package:sortle/model/reminder.dart';
import 'package:sortle/model/schema.dart';
import 'package:sortle/model/voice_note.dart';

final t0 = DateTime.utc(2026, 11, 10, 9);

Node node(String id, {List<Node> children = const [], NodeType? type}) => Node(
  id: id,
  title: 'Node $id',
  type: type ?? NodeType.task,
  status: NodeStatus.pending,
  createdAt: t0,
  updatedAt: t0,
  children: children,
);

Board sampleBoard() => Board(
  id: 'b1',
  title: 'Career',
  createdAt: t0,
  updatedAt: t0,
  root: Node(
    id: 'root',
    title: 'Next move',
    type: NodeType.decision,
    status: NodeStatus.done,
    notes: 'Pick by spring',
    date: '2026-12-01',
    time: '09:30',
    reminder: const Reminder(leadMinutes: 60, repeat: RepeatKind.weekly),
    color: '#C9B8FF',
    tags: ['work'],
    chosenChildIds: ['a'],
    createdAt: t0,
    updatedAt: t0,
    children: [
      node('a', children: [node('a1'), node('a2')]),
      node('b').copyWith(status: NodeStatus.eliminated, collapsed: true),
      node('c').copyWith(
        voiceNotes: [
          VoiceNote(
            id: 'v1',
            path: 'audio/v1.m4a',
            createdAt: t0,
            durationMs: 1200,
          ),
        ],
      ),
    ],
  ),
);

Map<String, Object?> sampleJson() =>
    jsonDecode(BoardSchema.encode(sampleBoard())) as Map<String, Object?>;

void main() {
  test('a board survives a save and load unchanged', () {
    final text = BoardSchema.encode(sampleBoard());
    final again = BoardSchema.encode(BoardSchema.decode(text));
    expect(again, text);
  });

  test('the file carries the current schema version', () {
    expect(sampleJson()['schemaVersion'], BoardSchema.currentVersion);
  });

  test('node count includes every node', () {
    expect(sampleBoard().nodeCount, 6);
  });

  group('rejects bad files with a clear reason', () {
    void expectRejected(
      void Function(Map<String, Object?> json) edit,
      String hint,
    ) {
      final json = sampleJson();
      edit(json);
      expect(
        () => BoardSchema.decode(jsonEncode(json)),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.message,
            'message',
            contains(hint),
          ),
        ),
      );
    }

    Map<String, Object?> root(Map<String, Object?> j) =>
        j['root']! as Map<String, Object?>;

    test('not JSON', () {
      expect(
        () => BoardSchema.decode('{oops'),
        throwsA(isA<SchemaException>()),
      );
    });
    test(
      'missing title',
      () => expectRejected((j) => root(j).remove('title'), 'title'),
    );
    test(
      'empty title',
      () => expectRejected((j) => root(j)['title'] = '  ', 'title'),
    );
    test(
      'unknown status',
      () => expectRejected((j) => root(j)['status'] = 'maybe', 'status'),
    );
    test(
      'unknown type',
      () => expectRejected((j) => root(j)['type'] = 'note', 'type'),
    );
    test(
      'bad date',
      () => expectRejected((j) => root(j)['date'] = '1/12/2026', 'date'),
    );
    test(
      'bad time',
      () => expectRejected((j) => root(j)['time'] = '25:00', 'time'),
    );
    test(
      'bad colour',
      () => expectRejected((j) => root(j)['color'] = 'red', 'color'),
    );
    test(
      'chosen id that is not a child',
      () => expectRejected(
        (j) => root(j)['chosenChildIds'] = ['zzz'],
        'chosenChildIds',
      ),
    );
    test('duplicate node ids', () {
      expectRejected((j) {
        final kids = root(j)['children']! as List<Object?>;
        (kids[1]! as Map<String, Object?>)['id'] = 'a';
        root(j)['chosenChildIds'] = <String>[];
      }, 'more than once');
    });
    test(
      'board id that could escape its folder',
      () => expectRejected((j) => j['id'] = '../evil', 'board.id'),
    );
    test('voice note outside audio/', () {
      expectRejected((j) {
        final kids = root(j)['children']! as List<Object?>;
        final c = kids[2]! as Map<String, Object?>;
        ((c['voiceNotes']! as List<Object?>)[0]!
                as Map<String, Object?>)['path'] =
            '../../secret';
      }, 'audio/');
    });
    test('interval repeat without an interval', () {
      expectRejected((j) {
        root(j)['reminder'] = {
          'leadMinutes': 0,
          'repeat': 'interval',
          'intervalMinutes': null,
        };
      }, 'intervalMinutes');
    });
    test(
      'file from a newer app',
      () => expectRejected(
        (j) => j['schemaVersion'] = BoardSchema.currentVersion + 1,
        'newer',
      ),
    );
  });

  group('migration', () {
    test('runs each step in order up to the target version', () {
      final json = sampleJson();
      final migrated = BoardSchema.migrate(
        json,
        target: 3,
        migrations: {
          1: (m) => {...m, 'name': m['title']}..remove('title'),
          2: (m) => {...m, 'label': 'v3 ${m['name']}'},
        },
      );
      expect(migrated['schemaVersion'], 3);
      expect(migrated.containsKey('title'), isFalse);
      expect(migrated['label'], 'v3 Career');
    });

    test('a missing step is reported', () {
      expect(
        () => BoardSchema.migrate(sampleJson(), target: 2, migrations: {}),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.message,
            'message',
            contains('no migration'),
          ),
        ),
      );
    });

    test('version 0 or below is rejected', () {
      final json = sampleJson()..['schemaVersion'] = 0;
      expect(() => BoardSchema.migrate(json), throwsA(isA<SchemaException>()));
    });
  });
}
