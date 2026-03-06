import Flutter
import UIKit
import AutomaticAssessmentConfiguration

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    // AEAssessmentSession untuk AAC (iOS 13.4+)
    @available(iOS 13.4, *)
    private var assessmentSession: AEAssessmentSession? = nil

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        // ── MethodChannel: Kiosk / AAC / Guided Access ────────────────────
        let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KioskChannel")!
        let kioskChannel = FlutterMethodChannel(
            name: "com.bmsexam/kiosk",
            binaryMessenger: registrar.messenger()
        )

        kioskChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {

            case "startKiosk":
                if #available(iOS 13.4, *) {
                    // ── AAC: kunci iPad sepenuhnya tanpa perlu Guided Access manual ──
                    let config = AEAssessmentConfiguration()

                    // iOS 15+: opsi tambahan
                    if #available(iOS 15.0, *) {
                        config.allowsAccessibilitySettings = false
                    }

                    let session = AEAssessmentSession(configuration: config)
                    session.delegate = self
                    self.assessmentSession = session
                    session.begin()
                    result(true) // AAC dimulai (delegate akan handle error jika entitlement belum ada)
                } else {
                    // iOS < 13.4: cek Guided Access saja
                    result(UIAccessibility.isGuidedAccessEnabled)
                }

            case "stopKiosk":
                if #available(iOS 13.4, *) {
                    self.assessmentSession?.end()
                    self.assessmentSession = nil
                }
                result(nil)

            case "isAdminActive",
                 "isKioskActive",
                 "isGuidedAccessEnabled":
                if #available(iOS 13.4, *) {
                    // Active jika AAC session berjalan ATAU Guided Access aktif
                    let aacActive = self.assessmentSession != nil
                    result(aacActive || UIAccessibility.isGuidedAccessEnabled)
                } else {
                    result(UIAccessibility.isGuidedAccessEnabled)
                }

            case "isDeviceOwner":
                // iOS tidak mengenal Device Owner — AAC adalah ekuivalennya
                if #available(iOS 13.4, *) {
                    result(self.assessmentSession != nil)
                } else {
                    result(false)
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}

// ── AEAssessmentSessionDelegate ────────────────────────────────────────────
@available(iOS 13.4, *)
extension AppDelegate: AEAssessmentSessionDelegate {

    func assessmentSessionDidBegin(_ session: AEAssessmentSession) {
        // AAC berhasil dimulai — layar terkunci sepenuhnya
    }

    func assessmentSession(
        _ session: AEAssessmentSession,
        wasInterruptedWithError error: Error
    ) {
        // AAC gagal (biasanya karena belum ada entitlement Apple)
        // App otomatis fallback ke Guided Access check
        assessmentSession = nil
    }

    func assessmentSessionDidEnd(_ session: AEAssessmentSession) {
        assessmentSession = nil
    }
}
