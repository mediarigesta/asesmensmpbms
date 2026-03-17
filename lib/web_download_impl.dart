// web_download_impl.dart
// Implementasi download untuk platform WEB
// File ini HANYA di-compile saat build web (dart.library.html tersedia)

// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:typed_data';

void webDownloadFile(String content, String fileName, String mimeType) {
  final bytes = Uint8List.fromList(content.codeUnits);
  final blob = Blob([bytes]);
  final url = Url.createObjectUrlFromBlob(blob);
  final anchor = AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  Url.revokeObjectUrl(url);
}

void webDownloadBytes(Uint8List bytes, String fileName, String mimeType) {
  final blob = Blob([bytes]);
  final url = Url.createObjectUrlFromBlob(blob);
  final anchor = AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  Url.revokeObjectUrl(url);
}
