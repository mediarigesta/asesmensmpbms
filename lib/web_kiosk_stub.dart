// web_kiosk_stub.dart
// Stub untuk platform non-web (Android, Windows, Desktop)
// Tidak melakukan apa-apa — semua fungsi kosong

void webKioskStart(int maxCurang, String examTitle) {}
void webKioskStop() {}
void webKioskRegisterCallbacks({
  void Function(int count, int max, String reason)? onViolation,
  void Function(String reason)? onAutoSubmit,
}) {}
