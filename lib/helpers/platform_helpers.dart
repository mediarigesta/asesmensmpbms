part of '../main.dart';

// ============================================================
// PLATFORM HELPERS
// ============================================================
/// true jika berjalan di Windows desktop
bool get isWindows => !kIsWeb && Platform.isWindows;

/// true jika berjalan di Android
bool get isAndroid => !kIsWeb && Platform.isAndroid;

/// Fitur kamera, battery — tersedia di Android & iOS
bool get hasMobileFeatures => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

// ============================================================
// WEB DOWNLOAD HELPER
// ============================================================
/// Download file for web platform
void _downloadFileForWeb(String content, String fileName, String mimeType) {
  if (kIsWeb) {
    webDownloadFile(content, fileName, mimeType);
  }
}

/// Download bytes file for web platform  
void _downloadBytesForWeb(Uint8List bytes, String fileName, String mimeType) {
  if (kIsWeb) {
    webDownloadBytes(bytes, fileName, mimeType);
  }
}
