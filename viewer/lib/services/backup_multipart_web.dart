import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Web: apenas bytes (FilePicker com withData).
Future<void> attachRestoreZip(
  http.MultipartRequest request, {
  List<int>? bytes,
  String? path,
  required String filename,
}) async {
  if (bytes == null) {
    throw ArgumentError('Na web, selecione o arquivo novamente (bytes necessários).');
  }
  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType('application', 'zip'),
    ),
  );
}
