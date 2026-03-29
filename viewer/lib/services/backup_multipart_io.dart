import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Anexa o ZIP ao multipart POST /admin/backup/restore (IO: path ou bytes).
Future<void> attachRestoreZip(
  http.MultipartRequest request, {
  List<int>? bytes,
  String? path,
  required String filename,
}) async {
  if (path != null) {
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        path,
        contentType: MediaType('application', 'zip'),
      ),
    );
    return;
  }
  if (bytes != null) {
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('application', 'zip'),
      ),
    );
    return;
  }
  throw ArgumentError('Informe path ou bytes.');
}
