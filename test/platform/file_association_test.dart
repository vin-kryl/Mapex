import 'package:flutter_test/flutter_test.dart';
import 'package:mapex/platform/file_association.dart';

void main() {
  test('Linux desktop entry quotes the path and claims the file type', () {
    final e = FileAssociation.linuxDesktopEntry('/opt/my apps/mapex');
    expect(e, contains('Exec="/opt/my apps/mapex" %f'));
    expect(e, contains('MimeType=application/x-mapex;'));
    expect(FileAssociation.linuxMimeXml, contains('*.mapex'));
  });
}
