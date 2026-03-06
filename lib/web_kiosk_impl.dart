// web_kiosk_impl.dart
// Implementasi kiosk untuk platform WEB
// File ini HANYA di-compile saat build web (dart.library.html tersedia)

// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void webKioskStart(int maxCurang, String examTitle) {
  try {
    js.context.callMethod('eval', [
      'if(window.BMKiosk) window.BMKiosk.start({maxCurang: $maxCurang, examTitle: "$examTitle"})'
    ]);
  } catch (e) {
    // ignore error jika kiosk.js belum load
  }
}

void webKioskStop() {
  try {
    js.context.callMethod('eval', [
      'if(window.BMKiosk) window.BMKiosk.stop()'
    ]);
  } catch (e) {
    // ignore
  }
}

void webKioskRegisterCallbacks({
  void Function(int count, int max, String reason)? onViolation,
  void Function(String reason)? onAutoSubmit,
}) {
  try {
    if (onViolation != null) {
      window.addEventListener('bm-kiosk-violation', (Event e) {
        final detail = (e as CustomEvent).detail;
        if (detail != null) {
          final count  = (js.JsObject.fromBrowserObject(detail)['count']  as num?)?.toInt() ?? 0;
          final max    = (js.JsObject.fromBrowserObject(detail)['max']    as num?)?.toInt() ?? 3;
          final reason = js.JsObject.fromBrowserObject(detail)['reason']?.toString() ?? '';
          onViolation(count, max, reason);
        }
      });
    }

    if (onAutoSubmit != null) {
      window.addEventListener('bm-kiosk-autosubmit', (Event e) {
        final detail = (e as CustomEvent).detail;
        String reason = 'max_violation';
        try {
          reason = js.JsObject.fromBrowserObject(detail)['reason']?.toString() ?? 'max_violation';
        } catch (_) {}
        onAutoSubmit(reason);
      });
    }
  } catch (e) {
    // ignore
  }
}