import 'package:flutter_test/flutter_test.dart';
import 'package:sortle/platform/file_association.dart';

void main() {
  test('Linux desktop entry quotes the path and claims the file type', () {
    final e = FileAssociation.linuxDesktopEntry('/opt/my apps/sortle');
    expect(e, contains('Exec="/opt/my apps/sortle" %f'));
    expect(e, contains('MimeType=application/x-sortle;'));
    expect(FileAssociation.linuxMimeXml, contains('*.sortle'));
  });
}
