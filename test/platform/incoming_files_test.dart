import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapex/platform/incoming_files.dart';

void main() {
  test('board files on the command line are read; others ignored', () async {
    final tmp = await Directory.systemTemp.createTemp('mapex_in_');
    addTearDown(() => tmp.delete(recursive: true));
    final board = File('${tmp.path}/Trip.mapex')..writeAsBytesSync([1, 2]);
    final other = File('${tmp.path}/notes.txt')..writeAsBytesSync([3]);
    final got = <IncomingFile>[];
    await IncomingFileSource.listen([
      board.path,
      other.path,
      '${tmp.path}/missing.json',
      '--some-flag',
    ], got.add);
    expect(got.single.name, 'Trip.mapex');
    expect(got.single.bytes, [1, 2]);
  });

  test('native messages are checked', () {
    expect(IncomingFileSource.fromMessage('junk'), isNull);
    expect(IncomingFileSource.fromMessage({'name': 'a'}), isNull);
    final f = IncomingFileSource.fromMessage({
      'name': 'a.mapex',
      'bytes': Uint8List.fromList([7]),
    })!;
    expect(f.name, 'a.mapex');
    expect(f.bytes, [7]);
  });
}
