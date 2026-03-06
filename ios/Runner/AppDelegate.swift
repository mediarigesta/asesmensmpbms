import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // ── MethodChannel: Kiosk / Guided Access ──────────────────────────────
    // Digunakan Flutter untuk cek & informasi Guided Access di iOS.
    // Guided Access TIDAK bisa diaktifkan/dinonaktifkan secara programatik;
    // siswa harus melakukannya manual (triple-click tombol samping/Home).
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KioskChannel")!
    let kioskChannel = FlutterMethodChannel(
      name: "com.bmsexam/kiosk",
      binaryMessenger: registrar.messenger()
    )

    kioskChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAdminActive",    // Android: Device Admin aktif?
           "isKioskActive",    // Android: Screen Pinning aktif?
           "isGuidedAccessEnabled":
        // iOS: kembalikan status Guided Access saat ini
        result(UIAccessibility.isGuidedAccessEnabled)

      case "startKiosk",
           "stopKiosk":
        // iOS tidak bisa start/stop Guided Access secara programatik
        // Siswa harus triple-click tombol samping lalu pilih Mulai/Akhiri
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
