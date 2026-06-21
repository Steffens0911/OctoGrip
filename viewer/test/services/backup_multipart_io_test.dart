import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:viewer/services/backup_multipart_io.dart';

// Testes para attachRestoreZip: variantes com bytes e sem nenhum parâmetro.

void main() {
  group('attachRestoreZip', () {
    test('anexa arquivo a partir de bytes', () async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost/admin/backup/restore'),
      );
      final bytes = List<int>.filled(10, 0);

      await attachRestoreZip(request, bytes: bytes, filename: 'backup.zip');

      expect(request.files, hasLength(1));
      expect(request.files.first.filename, 'backup.zip');
      expect(request.files.first.contentType.mimeType, 'application/zip');
    });

    test('lança ArgumentError sem bytes nem path', () async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost/admin/backup/restore'),
      );

      await expectLater(
        attachRestoreZip(request, filename: 'backup.zip'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
