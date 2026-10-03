import 'dart:typed_data';

Future<void> downloadOrShareFileImpl({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? shareText,
}) async {
  throw UnsupportedError('Platform not supported for file download/share');
}
