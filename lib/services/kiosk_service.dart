part of '../main.dart';

// ============================================================
// KIOSK SERVICE — Cross-platform (Android + Windows)
// Android  : Screen Pinning via MethodChannel native
// Windows  : Keyboard blocker Flutter-level + MethodChannel Win32
// ============================================================
class KioskService {
  static const _channel    = MethodChannel('com.bmsexam/kiosk');
  static const _winChannel = MethodChannel('com.bmsexam/windows_security');

  /// True jika Device Admin (Android) atau Guided Access/AAC aktif (iOS)
  static Future<bool> isAdminActive() async {
    if (kIsWeb || isWindows) return false;
    try { return await _channel.invokeMethod('isAdminActive') ?? false; }
    catch (_) { return false; }
  }

  /// True jika Device Owner (Android Lock Task penuh) atau AAC session aktif (iOS)
  static Future<bool> isDeviceOwner() async {
    if (kIsWeb || isWindows) return false;
    try { return await _channel.invokeMethod('isDeviceOwner') ?? false; }
    catch (_) { return false; }
  }

  static Future<void> start({int maxCurang = 3, String examTitle = 'Ujian'}) async {
    if (kIsWeb) {
      webKioskStart(maxCurang, examTitle);
      return;
    }
    if (isAndroid || (!kIsWeb && Platform.isIOS)) {
      try { await _channel.invokeMethod('startKiosk'); }
      catch (e) { debugPrint('KioskService.start error: $e'); }
    } else if (isWindows) {
      try { await _winChannel.invokeMethod('enableKiosk'); }
      catch (e) { debugPrint('KioskService.start (Windows) error: $e'); }
    }
  }

  static Future<void> stop() async {
    if (kIsWeb) {
      webKioskStop();
      return;
    }
    if (isAndroid || (!kIsWeb && Platform.isIOS)) {
      try { await _channel.invokeMethod('stopKiosk'); }
      catch (e) { debugPrint('KioskService.stop error: $e'); }
    } else if (isWindows) {
      try { await _winChannel.invokeMethod('disableKiosk'); }
      catch (e) { debugPrint('KioskService.stop (Windows) error: $e'); }
    }
  }

  static void registerWebCallbacks({
    void Function(int count, int max, String reason)? onViolation,
    void Function(String reason)? onAutoSubmit,
  }) {
    if (!kIsWeb) return;
    webKioskRegisterCallbacks(
      onViolation: onViolation,
      onAutoSubmit: onAutoSubmit,
    );
  }

  static Future<bool> isActive() async {
    if (kIsWeb || isWindows) return false;
    try { return await _channel.invokeMethod('isKioskActive') ?? false; }
    catch (_) { return false; }
  }
}
