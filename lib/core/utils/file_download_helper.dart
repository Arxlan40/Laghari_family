import 'dart:typed_data';
import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart'
    if (dart.library.io) 'file_download_helper_io.dart';

class FileDownloadHelper {
  /// Platform-adaptive file download or share
  /// On Web: downloads the file directly in browser memory via blob URL
  /// On Mobile/Desktop: writes to temp directory and opens native share sheet
  static Future<void> downloadOrShare({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? shareText,
  }) {
    return downloadOrShareFileImpl(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      shareText: shareText,
    );
  }
}
