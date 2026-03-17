import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show Platform, File;
// Web kiosk — conditional import: web pakai impl, lainnya pakai stub
import 'web_kiosk_stub.dart'
if (dart.library.html) 'web_kiosk_impl.dart';
// Web download — conditional import: web pakai impl, lainnya pakai stub
import 'web_download_stub.dart'
if (dart.library.html) 'web_download_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:archive/archive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' as xl;

// Platform-specific packages — hanya aktif di Android/iOS, di Web pakai stub
import 'package:camera/camera.dart' if (dart.library.html) 'stub_camera.dart';
import 'package:battery_plus/battery_plus.dart' if (dart.library.html) 'stub_battery.dart';
import 'package:webview_flutter/webview_flutter.dart' if (dart.library.html) 'stub_webview.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart' if (dart.library.html) 'stub_webview_android.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart' if (dart.library.html) 'stub_windowmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// PART FILES
// ============================================================

// Helpers
part 'helpers/platform_helpers.dart';
part 'helpers/logo_data.dart';
part 'helpers/windows_keyboard_blocker.dart';
part 'helpers/idle_timeout_mixin.dart';
part 'helpers/shared_widgets.dart';

// Theme
part 'theme/bm_theme.dart';

// Models
part 'models/data_models.dart';
part 'models/soal_model.dart';

// Services
part 'services/kiosk_service.dart';
part 'services/groq_ai_parser.dart';
part 'services/docx_parser.dart';

// Screens
part 'screens/splash_screen.dart';
part 'screens/login_screen.dart';
part 'screens/guru_dashboard.dart';
part 'screens/exam_creator_form.dart';
part 'screens/admin_subject_manager.dart';
part 'screens/guru_role_manager.dart';
part 'screens/exam_history_list.dart';
part 'screens/exam_edit_screen.dart';
part 'screens/exam_history_screen.dart';
part 'screens/admin1_dashboard.dart';
part 'screens/home_screen.dart';
part 'screens/exam_screen.dart';
part 'screens/lock_screen.dart';
part 'screens/rekaps_nilai_screen.dart';
part 'screens/native_exam_screen.dart';
part 'screens/password_reset_widget.dart';
part 'screens/profile_page.dart';
part 'screens/analytics_screen.dart';
part 'screens/jadwal_screen.dart';
part 'screens/broadcast_wa_screen.dart';
part 'screens/live_monitoring_screen.dart';


// ============================================================
// MAIN
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const firebaseOptions = FirebaseOptions(
    apiKey: "AIzaSyA5s6Tmpipn46IIzttpSNbeeVwTjo2jkp8",
    authDomain: "bm-exam.firebaseapp.com",
    projectId: "bm-exam",
    storageBucket: "bm-exam.firebasestorage.app",
    messagingSenderId: "671937779798",
    appId: "1:671937779798:web:e1fa8628d83839f2b643f7",
    measurementId: "G-6NQD3GXVXF",
  );
  try {
    // Web dan Windows pakai firebaseOptions eksplisit
    // Android pakai google-services.json (Firebase.initializeApp tanpa options)
    if (kIsWeb || isWindows) {
      await Firebase.initializeApp(options: firebaseOptions);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Firebase Error: $e");
  }

  if (isAndroid) {
    // WebView dan immersive mode hanya tersedia di Android
    WebViewPlatform.instance = AndroidWebViewPlatform();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const BMExamApp());
}

// ============================================================
// APP ROOT
// ============================================================
class BMExamApp extends StatelessWidget {
  const BMExamApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<BMTheme>(
    valueListenable: _themeNotifier,
    builder: (_, t, __) => MaterialApp(
      title: 'Budi Mulia Exam',
      debugShowCheckedModeBanner: false,
      theme: BMThemePresets.of(t),
      home: const SplashScreen(),
    ),
  );
}
