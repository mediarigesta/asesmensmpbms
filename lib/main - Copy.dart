import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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
    if (kIsWeb) {
      await Firebase.initializeApp(options: firebaseOptions);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Firebase Error: $e");
  }

  if (!kIsWeb) {
    WebViewPlatform.instance = AndroidWebViewPlatform();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const BMExamApp());
}

// ============================================================
// DATA MODELS
// ============================================================
class UserAccount {
  final String id, kode, nama, username, password, role, ruang,
      statusMengerjakan, statusAktif, photo, liveFrame;
  final int battery;

  UserAccount({
    required this.id,
    required this.kode,
    required this.nama,
    required this.username,
    required this.password,
    required this.role,
    required this.ruang,
    required this.statusMengerjakan,
    required this.statusAktif,
    required this.battery,
    required this.photo,
    required this.liveFrame,
  });

  factory UserAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAccount(
      id: doc.id,
      kode: data['kode']?.toString() ?? "",
      nama: data['nama'] ?? "",
      username: data['username'] ?? "",
      password: data['password']?.toString() ?? "",
      role: (data['role'] ?? "siswa").toString().toLowerCase(),
      ruang: data['ruang']?.toString() ?? "",
      statusMengerjakan: data['status_mengerjakan'] ?? "belum mulai",
      statusAktif: data['status_aktif'] ?? "aktif",
      battery: data['battery'] ?? 100,
      photo: data['photo'] ?? "",
      liveFrame: data['liveFrame'] ?? "",
    );
  }

  String get classFolder {
    final match = RegExp(r'^\d+[A-Za-z]+').stringMatch(kode);
    if (match != null) return match;
    final angka = RegExp(r'^\d+').stringMatch(kode);
    return angka ?? kode;
  }

  // Angka kelas saja: "7A01" -> "7"
  String get gradeNumber {
    final angka = RegExp(r'^\d+').stringMatch(kode);
    return angka ?? "";
  }

  // Cek apakah jenjang ujian cocok: "Kelas 7" cocok dengan kode "7A01", "07A", dll
  bool matchJenjang(String jenjang) {
    if (jenjang.isEmpty || kode.isEmpty) return false;
    // Ambil semua angka di depan kode siswa
    final g = gradeNumber;
    if (g.isEmpty) return false;
    // Normalisasi: hapus leading zero "07" -> "7"
    final gNorm = int.tryParse(g)?.toString() ?? g;
    // Cek apakah jenjang mengandung angka kelas siswa
    // "Kelas 7".contains("7") = true, tapi harus word-boundary
    // Gunakan regex agar "Kelas 7" tidak cocok dengan "Kelas 17"
    final pattern = RegExp(r'\b' + gNorm + r'\b');
    return pattern.hasMatch(jenjang) || jenjang.contains(gNorm);
  }

  String get initials {
    final parts = nama.trim().split(' ');
    if (parts.length >= 2) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : "?";
  }
}

class ExamData {
  final String id, judul, mapel, jenjang, link, instruksi;
  final DateTime waktuMulai, waktuSelesai;
  final bool antiCurang, kameraAktif, autoSubmit;
  final int maxCurang;

  ExamData({
    required this.id,
    required this.judul,
    required this.mapel,
    required this.jenjang,
    required this.link,
    required this.instruksi,
    required this.waktuMulai,
    required this.waktuSelesai,
    required this.antiCurang,
    required this.kameraAktif,
    required this.autoSubmit,
    required this.maxCurang,
  });

  factory ExamData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamData(
      id: doc.id,
      judul: data['judul'] ?? "",
      mapel: data['mapel'] ?? "",
      jenjang: data['jenjang'] ?? "",
      link: data['link'] ?? "",
      instruksi: data['instruksi'] ?? "",
      waktuMulai: (data['waktuMulai'] as Timestamp?)?.toDate() ?? DateTime.now(),
      waktuSelesai: (data['waktuSelesai'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 2)),
      antiCurang: data['antiCurang'] ?? true,
      kameraAktif: data['kameraAktif'] ?? true,
      autoSubmit: data['autoSubmit'] ?? true,
      maxCurang: data['maxCurang'] ?? 3,
    );
  }

  bool get isOngoing =>
      DateTime.now().isAfter(waktuMulai) && DateTime.now().isBefore(waktuSelesai);
  bool get sudahSelesai => DateTime.now().isAfter(waktuSelesai);
  bool get belumMulai => DateTime.now().isBefore(waktuMulai);

  Duration get sisaWaktu => waktuSelesai.difference(DateTime.now());
}

// ============================================================
// APP ROOT
// ============================================================
class BMExamApp extends StatelessWidget {
  const BMExamApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BM-Exam Pro',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A)),
    ),
    home: const SplashScreen(),
  );
}

// ============================================================
// SPLASH SCREEN
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0F172A),
    body: FadeTransition(
      opacity: _fade,
      child: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.school, size: 80, color: Colors.white),
          SizedBox(height: 16),
          Text("BM-Exam Pro",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          SizedBox(height: 6),
          Text("SMP Budi Mulia Jakarta",
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          SizedBox(height: 40),
          CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
        ]),
      ),
    ),
  );
}

// ============================================================
// LOGIN SCREEN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0F172A),
    body: Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo area
            const Icon(Icons.school, size: 70, color: Colors.white),
            const SizedBox(height: 10),
            const Text("BM-Exam Pro",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            const Text("SMP Budi Mulia Jakarta",
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 40),

            // Card Login
            Container(
              width: 360,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(children: [
                const Text("Masuk ke Akun",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text("Silakan masukkan kredensial Anda",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 24),
                TextField(
                  controller: _u,
                  decoration: InputDecoration(
                    labelText: "Username",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _p,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Text("MASUK",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    ),
  );

  void _login() async {
    if (_u.text.trim().isEmpty || _p.text.trim().isEmpty) {
      _snack("Username dan password tidak boleh kosong!", Colors.orange);
      return;
    }
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _u.text.trim())
          .where('password', isEqualTo: _p.text.trim())
          .get();
      if (!mounted) return;
      setState(() => _loading = false);

      if (snap.docs.isEmpty) {
        _snack("Username atau password salah!", Colors.red);
        return;
      }

      final u = UserAccount.fromFirestore(snap.docs.first);
      if (u.statusAktif == 'terblokir') {
        _snack("Akun Anda terblokir. Hubungi administrator.", Colors.red);
        return;
      }

      // Auto-reset status siswa jika "mengerjakan" tapi tidak ada ujian aktif
      if (u.role == 'siswa' && u.statusMengerjakan == 'mengerjakan') {
        final examSnap = await FirebaseFirestore.instance.collection('exam').get();
        final adaUjianAktif = examSnap.docs
            .map((d) => ExamData.fromFirestore(d))
            .any((e) => e.isOngoing && u.matchJenjang(e.jenjang));
        if (!adaUjianAktif) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(u.id)
              .update({'status_mengerjakan': 'belum mulai'});
        }
      }

      if (u.role == 'admin1') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => Admin1Dashboard(admin: u)));
      } else if (u.role == 'guru') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => GuruDashboard(guru: u)));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(user: u)));
      }
    } catch (e) {
      setState(() => _loading = false);
      _snack("Terjadi kesalahan. Coba lagi.", Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ============================================================
// GURU DASHBOARD — HANYA UPLOAD SOAL
// ============================================================
class GuruDashboard extends StatefulWidget {
  final UserAccount guru;
  const GuruDashboard({super.key, required this.guru});
  @override
  State<GuruDashboard> createState() => _GuruDashboardState();
}

class _GuruDashboardState extends State<GuruDashboard> {
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1F5F9),
    body: Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
        color: const Color(0xFF0F172A),
        child: Row(children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Portal Guru",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(widget.guru.nama,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
          // Badge ujian aktif
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('exam').snapshots(),
            builder: (c, snap) {
              if (!snap.hasData) return const SizedBox();
              final aktif = snap.data!.docs
                  .map((d) => ExamData.fromFirestore(d))
                  .where((e) => e.isOngoing)
                  .length;
              if (aktif == 0) return const SizedBox();
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.fiber_manual_record,
                      color: Colors.white, size: 8),
                  const SizedBox(width: 4),
                  Text("$aktif Aktif",
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11)),
                ]),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Keluar",
            onPressed: () => _confirmLogout(context),
          ),
        ]),
      ),

      // Body: ExamCreatorForm
      const Expanded(child: ExamCreatorForm()),
    ]),
  );

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Keluar?"),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text("Keluar"),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FORM BUAT PENILAIAN (dipakai Admin1 & Guru)
// ============================================================
class ExamCreatorForm extends StatefulWidget {
  const ExamCreatorForm({super.key});
  @override
  State<ExamCreatorForm> createState() => _ExamCreatorFormState();
}

class _ExamCreatorFormState extends State<ExamCreatorForm> {
  int _page = 1;
  final _judul = TextEditingController();
  final _instruksi = TextEditingController();
  final _link = TextEditingController();
  String? _selMapel, _selKelas;
  bool _anti = true, _cam = true, _auto = true;
  int _max = 3;
  DateTime _tgl = DateTime.now();
  TimeOfDay _jamStart = TimeOfDay.now();
  TimeOfDay _jamEnd = const TimeOfDay(hour: 10, minute: 0);
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Column(children: [
        // Progress indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: Colors.white,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Upload Soal Ujian",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Row(children: [
                  _stepDot(1, "Data Ujian"),
                  Expanded(
                      child: Divider(
                          color: _page >= 2 ? const Color(0xFF0F172A) : Colors.grey.shade300,
                          thickness: 2)),
                  _stepDot(2, "Pengaturan"),
                ]),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _page == 1 ? _halaman1() : _halaman2(),
          ),
        ),
      ]),
    );
  }

  Widget _stepDot(int step, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 14,
        backgroundColor:
        _page >= step ? const Color(0xFF0F172A) : Colors.grey.shade300,
        child: Text("$step",
            style: TextStyle(
                color: _page >= step ? Colors.white : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 10,
              color: _page >= step
                  ? const Color(0xFF0F172A)
                  : Colors.grey)),
    ],
  );

  Widget _halaman1() => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Data Ujian",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(height: 20),
          _field("Judul Ujian / Penilaian", _judul,
              icon: Icons.title),
          const SizedBox(height: 14),
          _buildMapelDrop(),
          const SizedBox(height: 14),
          _drop(
              "Pilih Jenjang / Kelas",
              _selKelas,
              ["Kelas 7", "Kelas 8", "Kelas 9"],
                  (v) => setState(() => _selKelas = v)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _judul.clear();
                  _instruksi.clear();
                  _link.clear();
                  setState(() {
                    _selMapel = null;
                    _selKelas = null;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text("RESET"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white),
                onPressed: () {
                  if (_judul.text.isEmpty ||
                      _selMapel == null ||
                      _selKelas == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Lengkapi semua data!")));
                    return;
                  }
                  setState(() => _page = 2);
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text("LANJUT"),
              ),
            ),
          ]),
        ],
      ),
    ),
  );

  Widget _halaman2() => Column(children: [
    // Pengaturan Keamanan
    Card(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pengaturan Keamanan",
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.security),
              title: const Text("Anti Curang"),
              subtitle: const Text(
                  "Kunci layar jika siswa keluar aplikasi"),
              value: _anti,
              onChanged: (v) => setState(() => _anti = v),
            ),
            if (_anti) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  const Icon(Icons.warning_amber,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text("Maks. Pelanggaran: $_max kali",
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ]),
              ),
              Slider(
                value: _max.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: "$_max",
                activeColor: Colors.orange,
                onChanged: (v) => setState(() => _max = v.toInt()),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.videocam),
              title: const Text("Kamera Monitor"),
              subtitle: const Text("Ambil foto siswa secara berkala"),
              value: _cam,
              onChanged: (v) => setState(() => _cam = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.send),
              title: const Text("Auto Submit"),
              subtitle:
              const Text("Submit otomatis saat waktu habis"),
              value: _auto,
              onChanged: (v) => setState(() => _auto = v),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),

    // Waktu
    Card(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Jadwal Ujian",
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month,
                  color: Color(0xFF0F172A)),
              title: const Text("Tanggal"),
              subtitle:
              Text(DateFormat('dd MMMM yyyy').format(_tgl)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                final p = await showDatePicker(
                    context: context,
                    initialDate: _tgl,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030));
                if (p != null) setState(() => _tgl = p);
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer, color: Colors.green),
              title: const Text("Waktu Mulai"),
              subtitle: Text(_jamStart.format(context)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                final p = await showTimePicker(
                    context: context, initialTime: _jamStart);
                if (p != null) setState(() => _jamStart = p);
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_off, color: Colors.red),
              title: const Text("Waktu Selesai"),
              subtitle: Text(_jamEnd.format(context)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                final p = await showTimePicker(
                    context: context, initialTime: _jamEnd);
                if (p != null) setState(() => _jamEnd = p);
              },
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),

    // Konten
    Card(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Konten Soal",
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 16),
            _field("Instruksi untuk Siswa", _instruksi,
                maxL: 4, icon: Icons.info_outline),
            const SizedBox(height: 12),
            _field("Link Soal (Google Form / URL)", _link,
                icon: Icons.link),
          ],
        ),
      ),
    ),
    const SizedBox(height: 20),

    Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _page = 1),
          icon: const Icon(Icons.arrow_back),
          label: const Text("KEMBALI"),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 50)),
          onPressed: _uploading ? null : _save,
          icon: _uploading
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.cloud_upload),
          label:
          Text(_uploading ? "MENGUPLOAD..." : "UPLOAD UJIAN"),
        ),
      ),
    ]),
    const SizedBox(height: 20),
  ]);

  Widget _field(String t, TextEditingController? c,
      {int? maxL, IconData? icon}) =>
      TextField(
        controller: c,
        maxLines: maxL,
        decoration: InputDecoration(
          labelText: t,
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          prefixIcon: icon != null ? Icon(icon) : null,
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      );

  Widget _buildMapelDrop() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('subjects')
        .snapshots(),
    builder: (context, snap) {
      if (!snap.hasData) return const LinearProgressIndicator();
      final items = snap.data!.docs
          .map((d) => (d.data() as Map)['name'].toString())
          .toList();
      return _drop("Mata Pelajaran", _selMapel, items,
              (v) => setState(() => _selMapel = v));
    },
  );

  Widget _drop(String t, String? v, List<String> items,
      Function(String?) onCh) =>
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: t,
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        value: v,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onCh,
      );

  void _save() async {
    if (_link.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Link soal wajib diisi!")));
      return;
    }
    setState(() => _uploading = true);
    try {
      final start = DateTime(
          _tgl.year, _tgl.month, _tgl.day, _jamStart.hour, _jamStart.minute);
      final end = DateTime(
          _tgl.year, _tgl.month, _tgl.day, _jamEnd.hour, _jamEnd.minute);

      if (end.isBefore(start)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Waktu selesai harus setelah waktu mulai!")));
        setState(() => _uploading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('exam').add({
        'judul': _judul.text,
        'mapel': _selMapel,
        'jenjang': _selKelas,
        'antiCurang': _anti,
        'maxCurang': _max,
        'kameraAktif': _cam,
        'autoSubmit': _auto,
        'waktuMulai': Timestamp.fromDate(start),
        'waktuSelesai': Timestamp.fromDate(end),
        'instruksi': _instruksi.text,
        'link': _link.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _uploading = false;
          _page = 1;
          _judul.clear();
          _instruksi.clear();
          _link.clear();
          _selMapel = null;
          _selKelas = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text("Ujian berhasil diupload!"),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal upload: $e")));
      }
    }
  }
}

// ============================================================
// ADMIN MATA PELAJARAN
// ============================================================
class AdminSubjectManager extends StatefulWidget {
  const AdminSubjectManager({super.key});
  @override
  State<AdminSubjectManager> createState() => _AdminSubjectManagerState();
}

class _AdminSubjectManagerState extends State<AdminSubjectManager> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                labelText: "Nama Mata Pelajaran",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.book),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white),
            onPressed: () {
              if (_ctrl.text.trim().isNotEmpty) {
                FirebaseFirestore.instance
                    .collection('subjects')
                    .add({'name': _ctrl.text.trim()});
                _ctrl.clear();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text("Tambah"),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('subjects')
              .orderBy('name')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_outlined,
                          size: 50, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("Belum ada mata pelajaran.",
                          style: TextStyle(color: Colors.grey)),
                    ]),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: snap.data!.docs.length,
              itemBuilder: (c, i) {
                final doc = snap.data!.docs[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF0F172A),
                      child: Icon(Icons.book, color: Colors.white, size: 18),
                    ),
                    title: Text((doc.data() as Map)['name'],
                        style:
                        const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Hapus Mapel?"),
                            content: Text(
                                "Hapus \"${(doc.data() as Map)['name']}\"?"),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Batal")),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white),
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text("Hapus"),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          FirebaseFirestore.instance
                              .collection('subjects')
                              .doc(doc.id)
                              .delete();
                        }
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ============================================================
// HISTORY UJIAN — LIST
// ============================================================
class ExamHistoryList extends StatefulWidget {
  const ExamHistoryList({super.key});
  @override
  State<ExamHistoryList> createState() => _ExamHistoryListState();
}

class _ExamHistoryListState extends State<ExamHistoryList> {
  String _filterStatus = "semua";
  String _search = "";

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Cari judul atau mapel...",
                prefixIcon: const Icon(Icons.search),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterStatus,
                items: const [
                  DropdownMenuItem(value: "semua", child: Text("Semua")),
                  DropdownMenuItem(
                      value: "ongoing", child: Text("Berlangsung")),
                  DropdownMenuItem(
                      value: "selesai", child: Text("Selesai")),
                  DropdownMenuItem(
                      value: "belum", child: Text("Belum Mulai")),
                ],
                onChanged: (v) => setState(() => _filterStatus = v!),
              ),
            ),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('exam')
              .orderBy('waktuMulai', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            var exams = snap.data!.docs
                .map((d) => ExamData.fromFirestore(d))
                .toList();

            if (_search.isNotEmpty) {
              exams = exams
                  .where((e) =>
              e.judul
                  .toLowerCase()
                  .contains(_search.toLowerCase()) ||
                  e.mapel
                      .toLowerCase()
                      .contains(_search.toLowerCase()))
                  .toList();
            }
            if (_filterStatus == "ongoing") {
              exams = exams.where((e) => e.isOngoing).toList();
            } else if (_filterStatus == "selesai") {
              exams = exams.where((e) => e.sudahSelesai).toList();
            } else if (_filterStatus == "belum") {
              exams = exams.where((e) => e.belumMulai).toList();
            }

            if (exams.isEmpty) {
              return const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_edu, size: 60, color: Colors.grey),
                      SizedBox(height: 12),
                      Text("Tidak ada data ujian.",
                          style: TextStyle(color: Colors.grey)),
                    ]),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: exams.length,
              itemBuilder: (c, i) {
                final e = exams[i];
                Color statusColor;
                String statusLabel;
                IconData statusIcon;

                if (e.isOngoing) {
                  statusColor = Colors.green;
                  statusLabel = "BERLANGSUNG";
                  statusIcon = Icons.play_circle;
                } else if (e.sudahSelesai) {
                  statusColor = Colors.grey;
                  statusLabel = "SELESAI";
                  statusIcon = Icons.check_circle;
                } else {
                  statusColor = Colors.orange;
                  statusLabel = "BELUM MULAI";
                  statusIcon = Icons.schedule;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: statusColor,
                      child: Icon(statusIcon, color: Colors.white, size: 20),
                    ),
                    title: Text(e.judul,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${e.mapel}  •  ${e.jenjang}"),
                        Text(
                          "${DateFormat('dd MMM yyyy, HH:mm').format(e.waktuMulai)} — ${DateFormat('HH:mm').format(e.waktuSelesai)}",
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(statusLabel,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9)),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      // Lihat Detail
                      IconButton(
                        icon: const Icon(Icons.bar_chart, color: Colors.blue),
                        tooltip: "Lihat Detail",
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ExamHistoryScreen(exam: e))),
                      ),
                      // Edit (untuk berlangsung & belum mulai)
                      // Gunakan Ulang (untuk selesai)
                      if (e.sudahSelesai)
                        IconButton(
                          icon: const Icon(Icons.replay, color: Colors.teal),
                          tooltip: "Gunakan Ulang",
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ExamEditScreen(exam: e, isReuse: true))),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          tooltip: "Edit Ujian",
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ExamEditScreen(exam: e, isReuse: false))),
                        ),
                      // Hapus
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: "Hapus",
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Hapus Ujian?"),
                              content: Text(
                                  "Yakin hapus \"${e.judul}\"?\nAksi tidak bisa dibatalkan."),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Batal")),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Hapus"),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await FirebaseFirestore.instance
                                .collection('exam')
                                .doc(e.id)
                                .delete();
                          }
                        },
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ============================================================
// HISTORY UJIAN — DETAIL
// ============================================================
// ============================================================
// EXAM EDIT SCREEN
// ============================================================
class ExamEditScreen extends StatefulWidget {
  final ExamData exam;
  final bool isReuse; // true = gunakan ulang, false = edit langsung
  const ExamEditScreen({super.key, required this.exam, required this.isReuse});
  @override
  State<ExamEditScreen> createState() => _ExamEditScreenState();
}

class _ExamEditScreenState extends State<ExamEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _judulCtrl;
  late TextEditingController _linkCtrl;
  late TextEditingController _instruksiCtrl;
  late String _mapel;
  late String _jenjang;
  late DateTime _waktuMulai;
  late DateTime _waktuSelesai;
  late bool _antiCurang;
  late int _maxCurang;
  late bool _kameraAktif;
  late bool _autoSubmit;
  bool _saving = false;
  List<String> _subjects = [];

  @override
  void initState() {
    super.initState();
    final e = widget.exam;
    _judulCtrl = TextEditingController(text: e.judul);
    _linkCtrl = TextEditingController(text: e.link);
    _instruksiCtrl = TextEditingController(text: e.instruksi);
    _mapel = e.mapel;
    _jenjang = e.jenjang;
    _antiCurang = e.antiCurang;
    _maxCurang = e.maxCurang;
    _kameraAktif = e.kameraAktif;
    _autoSubmit = e.autoSubmit;

    // Jika gunakan ulang, geser waktu ke hari ini
    if (widget.isReuse) {
      final now = DateTime.now();
      final durasi = e.waktuSelesai.difference(e.waktuMulai);
      _waktuMulai = DateTime(now.year, now.month, now.day,
          e.waktuMulai.hour, e.waktuMulai.minute);
      _waktuSelesai = _waktuMulai.add(durasi);
    } else {
      _waktuMulai = e.waktuMulai;
      _waktuSelesai = e.waktuSelesai;
    }
    _loadSubjects();
  }

  void _loadSubjects() async {
    final snap = await FirebaseFirestore.instance.collection('subjects').get();
    setState(() {
      _subjects = snap.docs.map((d) => d['name'].toString()).toList();
      if (!_subjects.contains(_mapel)) _subjects.insert(0, _mapel);
    });
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _linkCtrl.dispose();
    _instruksiCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickWaktuMulai() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _waktuMulai,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_waktuMulai),
    );
    if (t == null || !mounted) return;
    setState(() {
      _waktuMulai = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (_waktuSelesai.isBefore(_waktuMulai)) {
        _waktuSelesai = _waktuMulai.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickWaktuSelesai() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _waktuSelesai,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_waktuSelesai),
    );
    if (t == null || !mounted) return;
    final newSelesai = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (newSelesai.isBefore(_waktuMulai)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Waktu selesai harus setelah waktu mulai!"),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _waktuSelesai = newSelesai);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_waktuSelesai.isBefore(_waktuMulai)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Waktu selesai harus setelah waktu mulai!"),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'judul': _judulCtrl.text.trim(),
        'mapel': _mapel,
        'jenjang': _jenjang,
        'link': _linkCtrl.text.trim(),
        'instruksi': _instruksiCtrl.text.trim(),
        'waktuMulai': Timestamp.fromDate(_waktuMulai),
        'waktuSelesai': Timestamp.fromDate(_waktuSelesai),
        'antiCurang': _antiCurang,
        'maxCurang': _maxCurang,
        'kameraAktif': _kameraAktif,
        'autoSubmit': _autoSubmit,
      };

      if (widget.isReuse) {
        // Buat dokumen baru
        await FirebaseFirestore.instance.collection('exam').add(data);
      } else {
        // Update dokumen yang ada
        await FirebaseFirestore.instance
            .collection('exam')
            .doc(widget.exam.id)
            .update(data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isReuse
            ? "Ujian berhasil diduplikasi!"
            : "Ujian berhasil diperbarui!"),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Gagal menyimpan: $e"),
        backgroundColor: Colors.red,
      ));
    }
    setState(() => _saving = false);
  }

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 14),
    child: Text(label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(widget.isReuse ? "Gunakan Ulang Ujian" : "Edit Ujian"),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
              label: Text(widget.isReuse ? "Duplikasi" : "Simpan",
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.isReuse)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.teal, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Mode Gunakan Ulang: Ujian baru akan dibuat berdasarkan ujian ini. Ujian lama tidak berubah.",
                      style: TextStyle(color: Colors.teal, fontSize: 12),
                    ),
                  ),
                ]),
              ),

            // Judul
            _fieldLabel("Judul Ujian"),
            TextFormField(
              controller: _judulCtrl,
              decoration: InputDecoration(
                hintText: "Masukkan judul ujian",
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) => v!.trim().isEmpty ? "Judul tidak boleh kosong" : null,
            ),

            // Mata Pelajaran
            _fieldLabel("Mata Pelajaran"),
            DropdownButtonFormField<String>(
              value: _subjects.contains(_mapel) ? _mapel : null,
              decoration: InputDecoration(
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _mapel = v!),
            ),

            // Jenjang
            _fieldLabel("Jenjang / Kelas"),
            DropdownButtonFormField<String>(
              value: _jenjang,
              decoration: InputDecoration(
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: ["Kelas 7", "Kelas 8", "Kelas 9"]
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _jenjang = v!),
            ),

            // Link
            _fieldLabel("Link Google Form"),
            TextFormField(
              controller: _linkCtrl,
              decoration: InputDecoration(
                hintText: "https://docs.google.com/forms/...",
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Link tidak boleh kosong";
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) return "Link harus diawali https://";
                return null;
              },
            ),

            // Instruksi
            _fieldLabel("Instruksi (opsional)"),
            TextFormField(
              controller: _instruksiCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Tulis instruksi ujian...",
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            // Waktu Mulai
            _fieldLabel("Waktu Mulai"),
            GestureDetector(
              onTap: _pickWaktuMulai,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(children: [
                  const Icon(Icons.access_time, color: Colors.indigo, size: 18),
                  const SizedBox(width: 10),
                  Text(DateFormat("dd MMM yyyy, HH:mm").format(_waktuMulai),
                      style: const TextStyle(fontSize: 14)),
                ]),
              ),
            ),

            // Waktu Selesai
            _fieldLabel("Waktu Selesai"),
            GestureDetector(
              onTap: _pickWaktuSelesai,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(children: [
                  const Icon(Icons.access_time_filled, color: Colors.red, size: 18),
                  const SizedBox(width: 10),
                  Text(DateFormat("dd MMM yyyy, HH:mm").format(_waktuSelesai),
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Text(
                    "(${_waktuSelesai.difference(_waktuMulai).inMinutes} menit)",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ]),
              ),
            ),

            // Settings
            _fieldLabel("Pengaturan"),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                SwitchListTile(
                  title: const Text("Anti Curang"),
                  subtitle: const Text("Keluar app dihitung pelanggaran"),
                  value: _antiCurang,
                  onChanged: (v) => setState(() => _antiCurang = v),
                ),
                if (_antiCurang) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: const Text("Maksimal Pelanggaran"),
                    subtitle: Text("Saat ini: $_maxCurang kali"),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _maxCurang > 1
                            ? () => setState(() => _maxCurang--)
                            : null,
                      ),
                      Text("$_maxCurang",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => _maxCurang++),
                      ),
                    ]),
                  ),
                ],
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("Kamera Aktif"),
                  subtitle: const Text("Pantau siswa via kamera depan"),
                  value: _kameraAktif,
                  onChanged: (v) => setState(() => _kameraAktif = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("Auto Submit"),
                  subtitle: const Text("Form otomatis dikunci saat waktu habis"),
                  value: _autoSubmit,
                  onChanged: (v) => setState(() => _autoSubmit = v),
                ),
              ]),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isReuse ? Colors.teal : const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(widget.isReuse ? Icons.replay : Icons.save),
                label: Text(
                  widget.isReuse ? "Duplikasi sebagai Ujian Baru" : "Simpan Perubahan",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

class ExamHistoryScreen extends StatefulWidget {
  final ExamData exam;
  const ExamHistoryScreen({super.key, required this.exam});
  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  String _filterStatus = "semua";
  String _search = "";
  int _tabIndex = 0; // 0=Peserta, 1=Statistik

  ExamData get exam => widget.exam;

  Color _statusColor(String s) {
    switch (s) {
      case 'selesai': return Colors.green;
      case 'melanggar': return Colors.red;
      case 'mengerjakan': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'selesai': return Icons.check_circle;
      case 'melanggar': return Icons.warning;
      case 'mengerjakan': return Icons.edit;
      default: return Icons.schedule;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'selesai': return 'SELESAI';
      case 'melanggar': return 'MELANGGAR';
      case 'mengerjakan': return 'MENGERJAKAN';
      default: return 'BELUM MULAI';
    }
  }

  Widget _filterChip(String value, String label, Color color) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusBadge(ExamData e) {
    Color c;
    String label;
    if (e.isOngoing) {
      c = Colors.green;
      label = "BERLANGSUNG";
    } else if (e.sudahSelesai) {
      c = Colors.grey;
      label = "SELESAI";
    } else {
      c = Colors.orange;
      label = "BELUM MULAI";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.grey),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Expanded(child: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
      ]),
    );
  }

  Widget _statCard(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value.toString(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ── Export CSV ──
  void _exportCSV(List<UserAccount> peserta) {
    final buf = StringBuffer();
    buf.writeln("Nama,Kode,Kelas,Ruang,Status");
    for (final s in peserta) {
      buf.writeln("${s.nama},${s.kode},${s.classFolder},${s.ruang},${s.statusMengerjakan}");
    }
    final csv = buf.toString();
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("✅ Data CSV disalin ke clipboard! Paste ke Excel/Sheets."),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 4),
    ));
  }

  // ── Reset semua siswa ──
  Future<void> _resetSemua(List<UserAccount> peserta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text("Reset Semua Status?"),
        ]),
        content: Text(
          "Reset status ${peserta.length} siswa ke Belum Mulai?\n\nSiswa yang sudah selesai juga akan direset.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reset Semua"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final s in peserta) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(s.id),
        {'status_mengerjakan': 'belum mulai'},
      );
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Semua status berhasil direset!"),
        backgroundColor: Colors.green,
      ));
    }
  }

  // ── Extend waktu ujian ──
  Future<void> _extendWaktu() async {
    int menitTambah = 15;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.timer, color: Colors.blue),
            SizedBox(width: 8),
            Text("Tambah Waktu Ujian"),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Waktu selesai saat ini: ${DateFormat('HH:mm, dd MMM').format(exam.waktuSelesai)}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            const Text("Tambah waktu:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32),
                onPressed: menitTambah > 5 ? () => setSt(() => menitTambah -= 5) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("$menitTambah menit",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                onPressed: () => setSt(() => menitTambah += 5),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              "Waktu baru: ${DateFormat('HH:mm').format(exam.waktuSelesai.add(Duration(minutes: menitTambah)))}",
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Tambahkan"),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final newSelesai = exam.waktuSelesai.add(Duration(minutes: menitTambah));
    await FirebaseFirestore.instance
        .collection('exam')
        .doc(exam.id)
        .update({'waktuSelesai': Timestamp.fromDate(newSelesai)});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("✅ Waktu diperpanjang hingga ${DateFormat('HH:mm').format(newSelesai)}"),
        backgroundColor: Colors.blue,
      ));
    }
  }

  // ── Tab Statistik ──
  Widget _buildStatistikTab(List<UserAccount> peserta) {
    final selesai = peserta.where((s) => s.statusMengerjakan == 'selesai').length;
    final melanggar = peserta.where((s) => s.statusMengerjakan == 'melanggar').length;
    final mengerjakan = peserta.where((s) => s.statusMengerjakan == 'mengerjakan').length;
    final belum = peserta.where((s) => s.statusMengerjakan == 'belum mulai').length;

    // Grup per kelas untuk bar chart
    final Map<String, List<UserAccount>> grouped = {};
    for (var s in peserta) {
      grouped.putIfAbsent(s.classFolder, () => []).add(s);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Donut Chart
        const Text("Distribusi Status",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: Row(children: [
            Expanded(
              child: PieChart(PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 45,
                sections: [
                  if (selesai > 0) PieChartSectionData(
                    color: Colors.green,
                    value: selesai.toDouble(),
                    title: "$selesai",
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    radius: 55,
                  ),
                  if (mengerjakan > 0) PieChartSectionData(
                    color: Colors.indigo,
                    value: mengerjakan.toDouble(),
                    title: "$mengerjakan",
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    radius: 55,
                  ),
                  if (melanggar > 0) PieChartSectionData(
                    color: Colors.red,
                    value: melanggar.toDouble(),
                    title: "$melanggar",
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    radius: 55,
                  ),
                  if (belum > 0) PieChartSectionData(
                    color: Colors.grey,
                    value: belum.toDouble(),
                    title: "$belum",
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    radius: 55,
                  ),
                ],
              )),
            ),
            const SizedBox(width: 16),
            // Legend
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _legendItem(Colors.green, "Selesai", selesai),
              _legendItem(Colors.indigo, "Mengerjakan", mengerjakan),
              _legendItem(Colors.red, "Melanggar", melanggar),
              _legendItem(Colors.grey, "Belum Mulai", belum),
            ]),
          ]),
        ),

        // Progress overall
        const SizedBox(height: 20),
        const Text("Progress Keseluruhan",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        if (peserta.isNotEmpty) ...[
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: selesai / peserta.length,
                  minHeight: 14,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(Colors.green),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text("${(selesai / peserta.length * 100).toStringAsFixed(0)}%",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ]),
          const SizedBox(height: 4),
          Text("$selesai dari ${peserta.length} siswa selesai",
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],

        // Bar chart per kelas
        if (sortedKeys.length > 1) ...[
          const SizedBox(height: 24),
          const Text("Status per Kelas",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ...sortedKeys.map((kelas) {
            final list = grouped[kelas]!;
            final s = list.where((x) => x.statusMengerjakan == 'selesai').length;
            final m = list.where((x) => x.statusMengerjakan == 'mengerjakan').length;
            final l = list.where((x) => x.statusMengerjakan == 'melanggar').length;
            final b = list.where((x) => x.statusMengerjakan == 'belum mulai').length;
            final total = list.length;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF0F172A),
                      child: Text(kelas,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text("Kelas $kelas", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text("$total siswa", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                  const SizedBox(height: 10),
                  // Stacked bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 12,
                      child: Row(children: [
                        if (s > 0) Expanded(flex: s, child: Container(color: Colors.green)),
                        if (m > 0) Expanded(flex: m, child: Container(color: Colors.indigo)),
                        if (l > 0) Expanded(flex: l, child: Container(color: Colors.red)),
                        if (b > 0) Expanded(flex: b, child: Container(color: Colors.grey.shade300)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (s > 0) _miniChip("$s selesai", Colors.green),
                    if (s > 0) const SizedBox(width: 4),
                    if (m > 0) _miniChip("$m ujian", Colors.indigo),
                    if (m > 0) const SizedBox(width: 4),
                    if (l > 0) _miniChip("$l langgar", Colors.red),
                    if (l > 0) const SizedBox(width: 4),
                    if (b > 0) _miniChip("$b belum", Colors.grey),
                  ]),
                ]),
              ),
            );
          }),
        ],
      ]),
    );
  }

  Widget _legendItem(Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text("$label: $count", style: const TextStyle(fontSize: 12)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(exam.judul),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          if (exam.link.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: "Buka Soal",
              onPressed: () async {
                final uri = Uri.tryParse(exam.link.trim());
                if (uri != null && uri.hasScheme) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'siswa')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final all = snap.data!.docs.map((d) => UserAccount.fromFirestore(d)).toList();
          final peserta = all.where((s) => s.matchJenjang(exam.jenjang)).toList();
          final selesai = peserta.where((s) => s.statusMengerjakan == 'selesai').toList();
          final melanggar = peserta.where((s) => s.statusMengerjakan == 'melanggar').toList();
          final mengerjakan = peserta.where((s) => s.statusMengerjakan == 'mengerjakan').toList();
          final belum = peserta.where((s) => s.statusMengerjakan == 'belum mulai').toList();

          var filtered = peserta.where((s) {
            final matchSearch = _search.isEmpty ||
                s.nama.toLowerCase().contains(_search.toLowerCase()) ||
                s.kode.toLowerCase().contains(_search.toLowerCase());
            final matchStatus = _filterStatus == 'semua' ||
                (_filterStatus == 'belum' && s.statusMengerjakan == 'belum mulai') ||
                s.statusMengerjakan == _filterStatus;
            return matchSearch && matchStatus;
          }).toList();

          final Map<String, List<UserAccount>> grouped = {};
          for (var s in filtered) {
            grouped.putIfAbsent(s.classFolder, () => []).add(s);
          }
          final sortedKeys = grouped.keys.toList()..sort();

          return Column(children: [
            // Action bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                // Stat summary chips
                _miniChip("${peserta.length} total", Colors.blueGrey),
                const SizedBox(width: 4),
                _miniChip("${selesai.length} selesai", Colors.green),
                const SizedBox(width: 4),
                _miniChip("${mengerjakan.length} ujian", Colors.indigo),
                if (melanggar.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  _miniChip("${melanggar.length} langgar", Colors.red),
                ],
                const Spacer(),
                // Export button
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.teal),
                  tooltip: "Export CSV",
                  onPressed: () => _exportCSV(peserta),
                ),
                // Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) {
                    if (v == 'extend') _extendWaktu();
                    if (v == 'reset') _resetSemua(peserta);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'extend', child: Row(children: [
                      Icon(Icons.timer, color: Colors.blue), SizedBox(width: 8), Text("Tambah Waktu Ujian"),
                    ])),
                    const PopupMenuItem(value: 'reset', child: Row(children: [
                      Icon(Icons.refresh, color: Colors.orange), SizedBox(width: 8), Text("Reset Semua Status"),
                    ])),
                  ],
                ),
              ]),
            ),

            // Manual Tab Switcher
            Container(
              color: Colors.white,
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(
                          color: _tabIndex == 0 ? const Color(0xFF0F172A) : Colors.transparent,
                          width: 2,
                        )),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.groups,
                            color: _tabIndex == 0 ? const Color(0xFF0F172A) : Colors.grey,
                            size: 18),
                        const SizedBox(width: 6),
                        Text("Peserta",
                            style: TextStyle(
                                color: _tabIndex == 0 ? const Color(0xFF0F172A) : Colors.grey,
                                fontWeight: _tabIndex == 0 ? FontWeight.bold : FontWeight.normal)),
                      ]),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(
                          color: _tabIndex == 1 ? const Color(0xFF0F172A) : Colors.transparent,
                          width: 2,
                        )),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.bar_chart,
                            color: _tabIndex == 1 ? const Color(0xFF0F172A) : Colors.grey,
                            size: 18),
                        const SizedBox(width: 6),
                        Text("Statistik",
                            style: TextStyle(
                                color: _tabIndex == 1 ? const Color(0xFF0F172A) : Colors.grey,
                                fontWeight: _tabIndex == 1 ? FontWeight.bold : FontWeight.normal)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),

            // Tab content
            Expanded(
              child: _tabIndex == 1
                  ? _buildStatistikTab(peserta)
                  : Column(children: [
                // Filter bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Column(children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Cari nama atau kode siswa...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _filterChip("semua", "Semua (${peserta.length})", Colors.blueGrey),
                        const SizedBox(width: 6),
                        _filterChip("belum", "Belum (${belum.length})", Colors.grey),
                        const SizedBox(width: 6),
                        _filterChip("mengerjakan", "Ujian (${mengerjakan.length})", Colors.indigo),
                        const SizedBox(width: 6),
                        _filterChip("selesai", "Selesai (${selesai.length})", Colors.green),
                        const SizedBox(width: 6),
                        _filterChip("melanggar", "Langgar (${melanggar.length})", Colors.red),
                      ]),
                    ),
                  ]),
                ),

                // Peserta list
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      // Progress bar
                      if (peserta.isNotEmpty) ...[
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(children: [
                              Row(children: [
                                _statCard("Total", peserta.length, Colors.blue, Icons.groups),
                                const SizedBox(width: 8),
                                _statCard("Selesai", selesai.length, Colors.green, Icons.check_circle),
                                const SizedBox(width: 8),
                                _statCard("Ujian", mengerjakan.length, Colors.indigo, Icons.edit),
                                const SizedBox(width: 8),
                                _statCard("Langgar", melanggar.length, Colors.red, Icons.warning),
                              ]),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: selesai.length / peserta.length,
                                  minHeight: 10,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: const AlwaysStoppedAnimation(Colors.green),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${selesai.length} dari ${peserta.length} siswa selesai (${(selesai.length / peserta.length * 100).toStringAsFixed(0)}%)",
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Grouped by class
                      if (filtered.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(children: [
                              Icon(Icons.search_off, size: 50, color: Colors.grey),
                              SizedBox(height: 10),
                              Text("Tidak ada siswa ditemukan.",
                                  style: TextStyle(color: Colors.grey)),
                            ]),
                          ),
                        )
                      else
                        ...sortedKeys.map((kelas) {
                          final siswaKelas = grouped[kelas]!;
                          final sK = siswaKelas.where((s) => s.statusMengerjakan == 'selesai').length;
                          final lK = siswaKelas.where((s) => s.statusMengerjakan == 'melanggar').length;
                          final mK = siswaKelas.where((s) => s.statusMengerjakan == 'mengerjakan').length;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0F172A),
                                child: Text(kelas,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              title: Text("Kelas $kelas",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Wrap(spacing: 4, children: [
                                _miniChip("${siswaKelas.length} siswa", Colors.blueGrey),
                                if (mK > 0) _miniChip("$mK ujian", Colors.indigo),
                                if (sK > 0) _miniChip("$sK selesai", Colors.green),
                                if (lK > 0) _miniChip("$lK langgar", Colors.red),
                              ]),
                              children: siswaKelas.map((s) {
                                final sc = _statusColor(s.statusMengerjakan);
                                final si = _statusIcon(s.statusMengerjakan);
                                final sl = _statusLabel(s.statusMengerjakan);
                                return ListTile(
                                  dense: true,
                                  leading: s.photo.isEmpty
                                      ? CircleAvatar(
                                      backgroundColor: sc,
                                      child: const Icon(Icons.person, color: Colors.white, size: 16))
                                      : CircleAvatar(backgroundImage: MemoryImage(base64Decode(s.photo))),
                                  title: Text(s.nama, style: const TextStyle(fontSize: 13)),
                                  subtitle: Text("Kode: ${s.kode}  •  Ruang: ${s.ruang}",
                                      style: const TextStyle(fontSize: 11)),
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: sc, borderRadius: BorderRadius.circular(20)),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(si, color: Colors.white, size: 11),
                                        const SizedBox(width: 4),
                                        Text(sl,
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                      ]),
                                    ),
                                    if (s.statusMengerjakan != 'belum mulai')
                                      IconButton(
                                        icon: const Icon(Icons.refresh, size: 16, color: Colors.orange),
                                        tooltip: "Reset status",
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text("Reset Status?"),
                                              content: Text("Reset status \${s.nama} ke Belum Mulai?"),
                                              actions: [
                                                TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: const Text("Batal")),
                                                ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.orange,
                                                        foregroundColor: Colors.white),
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: const Text("Reset")),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(s.id)
                                                .update({'status_mengerjakan': 'belum mulai'});
                                          }
                                        },
                                      ),
                                  ]),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                    ]),
                  ),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class Admin1Dashboard extends StatefulWidget {
  final UserAccount admin;
  const Admin1Dashboard({super.key, required this.admin});
  @override
  State<Admin1Dashboard> createState() => _Admin1DashboardState();
}

class _Admin1DashboardState extends State<Admin1Dashboard> {
  int _tab = 0;
  String _search = "";
  String _filter = "semua";

  void _massUpdate(bool aktif) async {
    final s = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'siswa')
        .get();
    final b = FirebaseFirestore.instance.batch();
    for (var d in s.docs) {
      b.update(d.reference,
          {'status_aktif': aktif ? 'aktif' : 'terblokir'});
    }
    await b.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(aktif
            ? "Semua siswa berhasil diaktifkan."
            : "Semua siswa berhasil diblokir."),
        backgroundColor: aktif ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1F5F9),
    body: Row(children: [
      // Rail
      NavigationRail(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelType: NavigationRailLabelType.all,
        backgroundColor: const Color(0xFF0F172A),
        unselectedIconTheme:
        const IconThemeData(color: Colors.white60),
        selectedIconTheme:
        const IconThemeData(color: Colors.white),
        unselectedLabelTextStyle:
        const TextStyle(color: Colors.white60, fontSize: 10),
        selectedLabelTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold),
        destinations: const [
          NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: Text('Statistik')),
          NavigationRailDestination(
              icon: Icon(Icons.add_task_outlined),
              selectedIcon: Icon(Icons.add_task),
              label: Text('Upload')),
          NavigationRailDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: Text('Mapel')),
          NavigationRailDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: Text('Broadcast')),
          NavigationRailDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: Text('Siswa')),
          NavigationRailDestination(
              icon: Icon(Icons.history_edu_outlined),
              selectedIcon: Icon(Icons.history_edu),
              label: Text('History')),
          NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: Text('Setting')),
        ],
      ),

      // Content
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .snapshots(),
          builder: (c, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final u = snap.data!.docs
                .map((d) => UserAccount.fromFirestore(d))
                .toList();
            return Column(children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                color: Colors.white,
                child: Row(children: [
                  const Icon(Icons.admin_panel_settings,
                      color: Color(0xFF0F172A)),
                  const SizedBox(width: 10),
                  Text("Admin: ${widget.admin.nama}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // Badge ujian aktif
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('exam')
                        .snapshots(),
                    builder: (c, es) {
                      if (!es.hasData) return const SizedBox();
                      final n = es.data!.docs
                          .map((d) => ExamData.fromFirestore(d))
                          .where((e) => e.isOngoing)
                          .length;
                      if (n == 0) return const SizedBox();
                      return Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius:
                            BorderRadius.circular(20)),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                  Icons.fiber_manual_record,
                                  color: Colors.white,
                                  size: 8),
                              const SizedBox(width: 4),
                              Text("$n Ujian Aktif",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11)),
                            ]),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: "Keluar",
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Keluar?"),
                        content: const Text(
                            "Yakin ingin keluar dari sesi ini?"),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(context),
                              child: const Text("Batal")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const LoginScreen()));
                            },
                            child: const Text("Keluar"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
              Expanded(child: _buildTab(u)),
            ]);
          },
        ),
      ),
    ]),
  );

  Widget _buildTab(List<UserAccount> u) {
    switch (_tab) {
      case 0:
        return _stats(u);
      case 1:
        return const ExamCreatorForm();
      case 2:
        return const AdminSubjectManager();
      case 3:
        return _broadcast();
      case 4:
        return _students(u);
      case 5:
        return const ExamHistoryList();
      default:
        return _settings(u);
    }
  }

  // ── Tab: Statistik ──
  Widget _stats(List<UserAccount> u) {
    final s = u.where((x) => x.role == 'siswa').toList();
    final m = s.where((x) => x.statusMengerjakan == 'mengerjakan').length;
    final l = s.where((x) => x.statusMengerjakan == 'melanggar').length;
    final d = s.where((x) => x.statusMengerjakan == 'selesai').length;
    final bm = s.where((x) => x.statusMengerjakan == 'belum mulai').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Row(children: [
          _statBox("Total Siswa", s.length.toString(), Colors.blue,
              Icons.groups),
          const SizedBox(width: 12),
          _statBox("Sedang Ujian", m.toString(), Colors.indigo,
              Icons.edit_note),
          const SizedBox(width: 12),
          _statBox(
              "Melanggar", l.toString(), Colors.red, Icons.warning),
          const SizedBox(width: 12),
          _statBox(
              "Selesai", d.toString(), Colors.green, Icons.check_circle),
        ]),
        const SizedBox(height: 20),
        // Pie Chart + Token
        Column(children: [
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(
              sections: [
                PieChartSectionData(
                    color: Colors.indigo,
                    value: m.toDouble(),
                    title: "Ujian\n$m",
                    titleStyle: const TextStyle(
                        color: Colors.white, fontSize: 11)),
                PieChartSectionData(
                    color: Colors.red,
                    value: l.toDouble(),
                    title: "Langgar\n$l",
                    titleStyle: const TextStyle(
                        color: Colors.white, fontSize: 11)),
                PieChartSectionData(
                    color: Colors.green,
                    value: d.toDouble(),
                    title: "Selesai\n$d",
                    titleStyle: const TextStyle(
                        color: Colors.white, fontSize: 11)),
                PieChartSectionData(
                    color: Colors.grey,
                    value: bm.toDouble(),
                    title: "Belum\n$bm",
                    titleStyle: const TextStyle(
                        color: Colors.white, fontSize: 11)),
              ],
            )),
          ),
          const SizedBox(height: 16),
          _tokenWidget(),
        ]),
        const SizedBox(height: 20),
        // Ujian Aktif
        StreamBuilder<QuerySnapshot>(
          stream:
          FirebaseFirestore.instance.collection('exam').snapshots(),
          builder: (c, snap) {
            if (!snap.hasData) return const SizedBox();
            final aktif = snap.data!.docs
                .map((d) => ExamData.fromFirestore(d))
                .where((e) => e.isOngoing)
                .toList();
            if (aktif.isEmpty) return const SizedBox();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Ujian Berlangsung",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                ...aktif.map((e) => Card(
                  color: Colors.green.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.live_tv,
                        color: Colors.green),
                    title: Text(e.judul,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        "${e.mapel}  •  ${e.jenjang}  •  Selesai ${DateFormat('HH:mm').format(e.waktuSelesai)}"),
                  ),
                )),
              ],
            );
          },
        ),
      ]),
    );
  }

  Widget _statBox(String t, String v, Color c, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Icon(icon, color: c, size: 26),
            const SizedBox(height: 6),
            Text(v,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: c)),
            Text(t,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _tokenWidget() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20)),
    child: StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('exam_token')
          .snapshots(),
      builder: (c, snap) {
        String token = "------";
        if (snap.hasData && snap.data!.exists) {
          token = (snap.data!.data() as Map)['current_token']
              ?.toString() ??
              "------";
        }
        return Column(children: [
          const Text("TOKEN UJIAN",
              style:
              TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 8),
          Text(token,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => FirebaseFirestore.instance
                .collection('settings')
                .doc('exam_token')
                .set({
              'current_token':
              (Random().nextInt(900000) + 100000).toString()
            }),
            icon: const Icon(Icons.refresh),
            label: const Text("Generate Token"),
          ),
        ]);
      },
    ),
  );

  // ── Tab: Broadcast ──
  Widget _broadcast() {
    final msgCtrl = TextEditingController();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('broadcast')
          .snapshots(),
      builder: (c, snap) {
        String existing = "";
        if (snap.hasData && snap.data!.exists) {
          existing =
              (snap.data!.data() as Map)['message']?.toString() ?? "";
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(children: [
            const Icon(Icons.campaign,
                color: Color(0xFF0F172A), size: 60),
            const SizedBox(height: 14),
            const Text("Broadcast ke Semua Siswa",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
                "Pesan akan muncul sebagai notifikasi di layar ujian siswa.",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (existing.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Pesan Aktif Saat Ini:",
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(existing,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "Ketik Pesan Broadcast",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => FirebaseFirestore.instance
                      .collection('settings')
                      .doc('broadcast')
                      .set({
                    'message': '',
                    'timestamp': FieldValue.serverTimestamp()
                  }),
                  icon: const Icon(Icons.clear),
                  label: const Text("HAPUS PESAN"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50)),
                  onPressed: () {
                    if (msgCtrl.text.trim().isEmpty) return;
                    FirebaseFirestore.instance
                        .collection('settings')
                        .doc('broadcast')
                        .set({
                      'message': msgCtrl.text.trim(),
                      'timestamp': FieldValue.serverTimestamp()
                    });
                    msgCtrl.clear();
                  },
                  icon: const Icon(Icons.send),
                  label: const Text("KIRIM BROADCAST"),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }

  // ── Tab: Siswa ──
  Widget _students(List<UserAccount> u) {
    final s = u.where((x) => x.role == 'siswa').toList();
    final f = s.where((x) {
      final sc =
          x.nama.toLowerCase().contains(_search.toLowerCase()) ||
              x.kode.toLowerCase().contains(_search.toLowerCase());
      bool ft = true;
      if (_filter == "aktif") ft = x.statusAktif == 'aktif';
      else if (_filter == "terblokir") ft = x.statusAktif == 'terblokir';
      return sc && ft;
    }).toList();

    final Map<String, List<UserAccount>> g = {};
    for (var x in f) {
      g.putIfAbsent(x.classFolder, () => []).add(x);
    }
    final k = g.keys.toList()..sort();

    return Column(children: [
      // Search + Filter
      Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Cari nama atau kode...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filter,
                items: const [
                  DropdownMenuItem(
                      value: "semua", child: Text("Semua")),
                  DropdownMenuItem(
                      value: "aktif", child: Text("Aktif")),
                  DropdownMenuItem(
                      value: "terblokir", child: Text("Terblokir")),
                ],
                onChanged: (v) => setState(() => _filter = v!),
              ),
            ),
          ),
        ]),
      ),

      // Bulk Actions
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white),
              onPressed: () => _massUpdate(true),
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text("AKTIFKAN SEMUA"),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white),
              onPressed: () => _massUpdate(false),
              icon: const Icon(Icons.block, size: 16),
              label: const Text("BLOKIR SEMUA"),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),

      // List
      Expanded(
        child: k.isEmpty
            ? const Center(
            child: Text("Tidak ada siswa ditemukan.",
                style: TextStyle(color: Colors.grey)))
            : ListView.builder(
          itemCount: k.length,
          itemBuilder: (c, i) => Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF0F172A),
                child: Text(k[i],
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ),
              title: Text("Kelas ${k[i]}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold)),
              subtitle: Text(
                  "${g[k[i]]!.length} siswa • ${g[k[i]]!.where((s) => s.statusAktif == 'aktif').length} aktif"),
              children: g[k[i]]!.map((x) => ListTile(
                leading: x.photo.isEmpty
                    ? CircleAvatar(
                    backgroundColor:
                    x.statusAktif == 'aktif'
                        ? Colors.green
                        : Colors.red,
                    child: Text(x.initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12)))
                    : CircleAvatar(
                    backgroundImage: MemoryImage(
                        base64Decode(x.photo))),
                title: Text(x.nama),
                subtitle: Text(
                    "Ruang: ${x.ruang}  •  Battery: ${x.battery}%"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Battery indicator
                    Icon(
                      x.battery > 50
                          ? Icons.battery_full
                          : x.battery > 20
                          ? Icons.battery_3_bar
                          : Icons.battery_alert,
                      color: x.battery > 50
                          ? Colors.green
                          : x.battery > 20
                          ? Colors.orange
                          : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: x.statusAktif == 'aktif',
                      activeColor: Colors.green,
                      onChanged: (v) => FirebaseFirestore
                          .instance
                          .collection('users')
                          .doc(x.id)
                          .update({
                        'status_aktif':
                        v ? 'aktif' : 'terblokir'
                      }),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Tab: Settings ──
  Widget _settings(List<UserAccount> u) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      // Token & PIN
      Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PIN Proktor",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              const Text(
                  "PIN ini digunakan untuk membuka kunci layar siswa yang tertangkap melanggar.",
                  style:
                  TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 20),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('settings')
                    .doc('app_config')
                    .snapshots(),
                builder: (c, snap) {
                  final ctrl = TextEditingController();
                  if (snap.hasData && snap.data!.exists) {
                    ctrl.text = (snap.data!.data()
                    as Map)['proctor_password'] ??
                        "";
                  }
                  return Row(children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(10)),
                          hintText: "Masukkan PIN Proktor",
                          prefixIcon: const Icon(Icons.key),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white),
                      onPressed: () => FirebaseFirestore.instance
                          .collection('settings')
                          .doc('app_config')
                          .set({
                        'proctor_password': ctrl.text
                      }, SetOptions(merge: true)),
                      child: const Text("Simpan"),
                    ),
                  ]);
                },
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Reset Status
      Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Reset Status Ujian",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              const Text(
                  "Reset status semua siswa ke 'belum mulai'. Gunakan setelah ujian selesai.",
                  style:
                  TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Reset Status?"),
                        content: const Text(
                            "Status semua siswa akan direset ke 'belum mulai'. Lanjutkan?"),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text("Batal")),
                          ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: const Text("Reset")),
                        ],
                      ),
                    );
                    if (ok == true) {
                      final all = await FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'siswa')
                          .get();
                      final batch =
                      FirebaseFirestore.instance.batch();
                      for (var d in all.docs) {
                        batch.update(d.reference, {
                          'status_mengerjakan': 'belum mulai',
                          'liveFrame': '',
                        });
                      }
                      await batch.commit();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Status berhasil direset!"),
                                backgroundColor: Colors.green));
                      }
                    }
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text("RESET STATUS SISWA"),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Ganti Password
      Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Ganti Password Akun",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              const Text(
                  "Cari akun berdasarkan username atau nama, lalu ubah password-nya.",
                  style:
                  TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 20),
              const PasswordResetWidget(),
            ],
          ),
        ),
      ),
    ]),
  );
}

// ============================================================
// HOME SCREEN (SISWA)
// ============================================================
class HomeScreen extends StatefulWidget {
  final UserAccount user;
  const HomeScreen({super.key, required this.user});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tokenCtrl = TextEditingController();
  ExamData? _exam;
  bool _loading = true;
  CameraController? _cam;
  bool _camReady = false;
  Timer? _batteryTimer;
  final _battery = Battery();
  StreamSubscription? _broadcastSub;
  StreamSubscription? _examSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _loadExam();
    _initCamera();
    _startBatteryReporter();
    _listenBroadcast();
    _listenAccountStatus();
  }

  // Load ujian realtime pakai Stream agar selalu update
  void _loadExam() {
    _examSub = FirebaseFirestore.instance
        .collection('exam')
        .snapshots()
        .listen((snap) async {
      if (!mounted) return;
      final list = snap.docs.map((d) => ExamData.fromFirestore(d)).toList();
      ExamData? found;
      try {
        found = list.firstWhere((e) =>
        e.isOngoing && widget.user.matchJenjang(e.jenjang));
      } catch (_) {
        found = null;
      }

      // Auto-reset: jika tidak ada ujian aktif tapi status masih "mengerjakan"
      if (found == null && widget.user.statusMengerjakan == 'mengerjakan') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.id)
            .update({'status_mengerjakan': 'belum mulai'});
      }

      if (!mounted) return;
      setState(() {
        _exam = found;
        _loading = false;
      });
    });
  }

  // Inisialisasi kamera depan
  void _initCamera() async {
    if (kIsWeb) return;
    try {
      final cams = await availableCameras();
      if (cams.isNotEmpty) {
        _cam = CameraController(
          cams.firstWhere(
                  (x) => x.lensDirection == CameraLensDirection.front,
              orElse: () => cams.first),
          ResolutionPreset.low,
          enableAudio: false,
        );
        await _cam!.initialize();
        if (mounted) setState(() => _camReady = true);
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  // Kirim status baterai ke Firestore tiap 1 menit
  void _startBatteryReporter() {
    if (kIsWeb) return;
    _batteryTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      try {
        final level = await _battery.batteryLevel;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.id)
            .update({'battery': level});
      } catch (_) {}
    });
    // Kirim sekali langsung
    _battery.batteryLevel.then((level) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .update({'battery': level}).catchError((_) {});
    });
  }

  // Dengarkan pesan broadcast
  void _listenBroadcast() {
    _broadcastSub = FirebaseFirestore.instance
        .collection('settings')
        .doc('broadcast')
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final msg =
          (snap.data() as Map?)?['message']?.toString() ?? "";
      if (msg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });
  }

  // Monitor status akun siswa secara realtime
  // Jika admin memblokir, otomatis logout
  void _listenAccountStatus() {
    _statusSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.id)
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data?['status_aktif'] == 'terblokir') {
        // Batalkan semua subscription
        _statusSub?.cancel();
        _broadcastSub?.cancel();
        _examSub?.cancel();
        _batteryTimer?.cancel();
        // Tampilkan dialog lalu logout
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 8),
              Text("Akun Diblokir"),
            ]),
            content: const Text(
              "Akun kamu telah diblokir oleh administrator.\n\nHubungi guru atau admin untuk informasi lebih lanjut.",
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text("OK, Keluar"),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _cam?.dispose();
    _batteryTimer?.cancel();
    _examSub?.cancel();
    _broadcastSub?.cancel();
    _statusSub?.cancel();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Keluar?"),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text("Keluar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    IconData greetIcon;
    if (hour < 11) {
      greeting = "Selamat Pagi";
      greetIcon = Icons.wb_sunny;
    } else if (hour < 15) {
      greeting = "Selamat Siang";
      greetIcon = Icons.wb_sunny_outlined;
    } else if (hour < 18) {
      greeting = "Selamat Sore";
      greetIcon = Icons.wb_twilight;
    } else {
      greeting = "Selamat Malam";
      greetIcon = Icons.nightlight_round;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
        // Header gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 230,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),

        SafeArea(
          child: Column(children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(greetIcon,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 5),
                          Text(greeting,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12)),
                        ]),
                        const SizedBox(height: 3),
                        Text(widget.user.nama,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        Row(children: [
                          _chip(Icons.class_,
                              "Kelas ${widget.user.kode}"),
                          const SizedBox(width: 6),
                          _chip(Icons.meeting_room,
                              "Ruang ${widget.user.ruang}"),
                        ]),
                      ]),
                ),
                // Avatar + logout
                Column(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                          color: Colors.white30, width: 2),
                    ),
                    child: Center(
                      child: Text(widget.user.initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout,
                        color: Colors.white70, size: 18),
                    tooltip: "Keluar",
                    onPressed: () => _confirmLogout(context),
                  ),
                ]),
              ]),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                child: Column(children: [
                  // Info row
                  Row(children: [
                    _infoCard(Icons.school, "Sekolah",
                        "SMP Budi Mulia", Colors.indigo),
                    const SizedBox(width: 10),
                    _infoCard(
                        Icons.calendar_today,
                        "Hari ini",
                        DateFormat('dd MMM yyyy').format(now),
                        Colors.teal),
                  ]),
                  const SizedBox(height: 18),

                  // Cek status siswa secara realtime dari Firestore
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.user.id)
                        .snapshots(),
                    builder: (ctx, userSnap) {
                      final sudahSelesai = userSnap.hasData &&
                          userSnap.data!.exists &&
                          (userSnap.data!.data() as Map?)?['status_mengerjakan'] == 'selesai';

                      if (_exam != null && sudahSelesai) {
                        // Ujian ada tapi siswa sudah selesai
                        return _sudahSelesaiCard(_exam!);
                      }

                      return Column(children: [
                        if (_exam != null) ...[
                          // Label
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Ujian Tersedia",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                          const SizedBox(height: 10),

                          // Exam Card
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1565C0),
                                  Color(0xFF0D47A1)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.blue
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.2),
                                    borderRadius:
                                    BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fiber_manual_record,
                                          color: Colors.greenAccent,
                                          size: 9),
                                      SizedBox(width: 4),
                                      Text("SEDANG BERLANGSUNG",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight:
                                              FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(_exam!.judul,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(_exam!.mapel,
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.8),
                                        fontSize: 14)),
                                const SizedBox(height: 14),
                                Row(children: [
                                  const Icon(Icons.access_time,
                                      color: Colors.white70, size: 15),
                                  const SizedBox(width: 5),
                                  Text(
                                      "${DateFormat('HH:mm').format(_exam!.waktuMulai)} — ${DateFormat('HH:mm').format(_exam!.waktuSelesai)}",
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12)),
                                ]),
                                // Countdown
                                Builder(builder: (_) {
                                  final sisa = _exam!.waktuSelesai
                                      .difference(now);
                                  final jam = sisa.inHours;
                                  final mnt =
                                  sisa.inMinutes.remainder(60);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Row(children: [
                                      const Icon(Icons.timer_outlined,
                                          color: Colors.amber, size: 15),
                                      const SizedBox(width: 5),
                                      Text(
                                          jam > 0
                                              ? "Sisa $jam jam $mnt menit"
                                              : "Sisa $mnt menit lagi",
                                          style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 12,
                                              fontWeight:
                                              FontWeight.w600)),
                                    ]),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Instruksi
                          if (_exam!.instruksi.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.amber.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.orange, size: 17),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(_exam!.instruksi,
                                          style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 13))),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Input Token
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3)),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(children: [
                              const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.vpn_key,
                                      color: Color(0xFF0F172A),
                                      size: 17),
                                  SizedBox(width: 6),
                                  Text("Masukkan Token Ujian",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _tokenCtrl,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 8),
                                decoration: InputDecoration(
                                  counterText: "",
                                  hintText: "······",
                                  hintStyle: const TextStyle(
                                      letterSpacing: 8,
                                      color: Colors.grey),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(
                                      Icons.play_arrow_rounded),
                                  label: const Text("MULAI UJIAN",
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                                  onPressed: _startExam,
                                ),
                              ),
                            ]),
                          ),
                        ] else ...[
                          // Tidak ada ujian
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 50, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3)),
                              ],
                            ),
                            child: Column(children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.event_available,
                                    size: 40, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              const Text("Tidak Ada Ujian",
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF334155))),
                              const SizedBox(height: 8),
                              const Text(
                                "Belum ada jadwal ujian untukmu saat ini.\nTunggu informasi dari guru atau proktor.",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ]),
                          ),
                        ],
                      ]); // end Column in StreamBuilder
                    },
                  ), // end StreamBuilder
                ]),
              ),
            ),
          ]),
        ),

        // Kamera Pengawasan (pojok kanan bawah)
        if (!kIsWeb && _camReady && _cam != null)
          Positioned(
            bottom: 16,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(8)),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record,
                            color: Colors.white, size: 8),
                        SizedBox(width: 4),
                        Text("LIVE",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ]),
                ),
                Container(
                  width: 110,
                  height: 138,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                      topLeft: Radius.circular(10),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.red.withValues(alpha: 0.25),
                          blurRadius: 10,
                          spreadRadius: 1),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                      topLeft: Radius.circular(8),
                    ),
                    child: CameraPreview(_cam!),
                  ),
                ),
                const SizedBox(height: 4),
                const Text("Kamu sedang diawasi",
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.red,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ]),
    );
  }

  // Card tampilan ketika siswa sudah selesai mengerjakan
  Widget _sudahSelesaiCard(ExamData exam) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 3)),
      ],
    ),
    child: Column(children: [
      Container(
        width: 70, height: 70,
        decoration: const BoxDecoration(
          color: Color(0xFFDCFCE7),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle, color: Colors.green, size: 40),
      ),
      const SizedBox(height: 16),
      const Text("Ujian Sudah Dilaksanakan",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
              color: Color(0xFF15803D))),
      const SizedBox(height: 8),
      Text("${exam.judul} • ${exam.mapel}",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(
        "${DateFormat('dd MMM yyyy, HH:mm').format(exam.waktuMulai)} — ${DateFormat('HH:mm').format(exam.waktuSelesai)}",
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Kamu sudah mengumpulkan jawaban. Hubungi admin jika perlu mengulang.",
              style: TextStyle(color: Colors.blue, fontSize: 12),
            ),
          ),
        ]),
      ),
    ]),
  );

  void _startExam() async {
    final tokenInput = _tokenCtrl.text.trim();
    if (tokenInput.isEmpty) {
      _snack("Masukkan token ujian terlebih dahulu!", Colors.orange);
      return;
    }
    try {
      final ts = await FirebaseFirestore.instance
          .collection('settings')
          .doc('exam_token')
          .get();
      if (!ts.exists) {
        _snack("Token belum dikonfigurasi. Hubungi admin.", Colors.red);
        return;
      }
      final serverToken =
          (ts.data() as Map)['current_token']?.toString() ?? "";
      if (tokenInput == serverToken) {
        // Ambil foto jika kamera aktif
        if (!kIsWeb && _cam != null && _exam!.kameraAktif) {
          try {
            final img = await _cam!.takePicture();
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.user.id)
                .update(
                {'photo': base64Encode(await img.readAsBytes())});
          } catch (_) {}
        }
        if (mounted) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ExamScreen(
                      exam: _exam!, user: widget.user, cam: _cam)));
        }
      } else {
        _snack("Token salah! Minta token dari proktor.", Colors.red);
      }
    } catch (e) {
      _snack("Terjadi kesalahan. Coba lagi.", Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _chip(IconData icon, String label) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white70, size: 11),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ]),
  );

  Widget _infoCard(
      IconData icon, String label, String value, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 10)),
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
        ),
      );
}

// ============================================================
// EXAM SCREEN
// ============================================================
class ExamScreen extends StatefulWidget {
  final ExamData exam;
  final UserAccount user;
  final CameraController? cam;
  const ExamScreen(
      {super.key, required this.exam, required this.user, this.cam});
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen>
    with WidgetsBindingObserver {
  late final WebViewController _webCtrl;
  bool _submitted = false;
  int _curang = 0;
  Timer? _liveTimer;
  Timer? _autoSubmitTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initExam();

    // Inisialisasi WebView (non-web only)
    if (!kIsWeb) {
      _webCtrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(widget.exam.link))
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (url) {
            // Auto submit saat Google Form selesai
            if (widget.exam.autoSubmit &&
                url.contains("formResponse")) {
              _doSubmit(reason: "form_completed");
            }
          },
        ));
    }

    // Live frame kirim setiap 5 detik
    if (!kIsWeb &&
        widget.cam != null &&
        widget.exam.kameraAktif) {
      _liveTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _sendFrame());
    }

    // Auto submit by timer saat waktu habis
    if (widget.exam.autoSubmit) {
      final remaining = widget.exam.waktuSelesai.difference(DateTime.now());
      if (remaining > Duration.zero) {
        _autoSubmitTimer = Timer(remaining, () {
          _doSubmit(reason: "time_up");
        });
      }
    }

    // Broadcast listener
    FirebaseFirestore.instance
        .collection('settings')
        .doc('broadcast')
        .snapshots()
        .listen((s) {
      if (!mounted || !s.exists) return;
      final msg = (s.data() as Map?)?['message']?.toString() ?? "";
      if (msg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
        ));
      }
    });
  }

  void _initExam() async {
    if (!kIsWeb) await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.id)
        .update({'status_mengerjakan': 'mengerjakan'});
  }

  void _sendFrame() async {
    if (widget.cam == null || !widget.cam!.value.isInitialized) return;
    try {
      final img = await widget.cam!.takePicture();
      final bytes = await img.readAsBytes();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .update({'liveFrame': base64Encode(bytes)});
    } catch (_) {}
  }

  void _doSubmit({String reason = "manual"}) async {
    if (_submitted) return;
    _submitted = true;
    _liveTimer?.cancel();
    _autoSubmitTimer?.cancel();

    if (!kIsWeb) await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.id)
        .update({'status_mengerjakan': 'selesai', 'liveFrame': ''});

    if (mounted) {
      if (reason == "time_up") {
        // Tampilkan notifikasi waktu habis
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Waktu Habis!"),
            content: const Text(
                "Waktu ujian telah berakhir. Jawaban Anda telah otomatis dikumpulkan."),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_submitted || !widget.exam.antiCurang) return;
    if (state == AppLifecycleState.paused) {
      _curang++;
      if (_curang >= widget.exam.maxCurang) {
        // Kunci aplikasi
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.id)
            .update({'status_mengerjakan': 'melanggar'});
        if (mounted) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => LockScreen(user: widget.user)));
        }
      } else {
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "⚠️ Peringatan $_curang dari ${widget.exam.maxCurang} — Jangan keluar aplikasi!"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveTimer?.cancel();
    _autoSubmitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: Stack(children: [
        // WebView atau tombol buka link (web)
        kIsWeb
            ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.quiz, size: 60, color: Colors.grey),
                const SizedBox(height: 14),
                const Text("Silakan buka soal melalui link berikut:"),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white),
                  onPressed: () =>
                      launchUrl(Uri.parse(widget.exam.link)),
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text("Buka Soal"),
                ),
              ],
            ))
            : WebViewWidget(controller: _webCtrl),

        // Kamera preview
        if (widget.exam.kameraAktif && widget.cam != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              width: 95,
              height: 122,
              decoration: BoxDecoration(
                border:
                Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CameraPreview(widget.cam!),
              ),
            ),
          ),

        // Pelanggaran counter
        if (widget.exam.antiCurang && _curang > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning,
                    color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Text(
                    "Pelanggaran: $_curang/${widget.exam.maxCurang}",
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11)),
              ]),
            ),
          ),

        // Timer sisa waktu (pojok kiri atas)
        Positioned(
          top: 8,
          left: 8,
          child: _CountdownBadge(waktuSelesai: widget.exam.waktuSelesai),
        ),
      ]),
    ),
  );
}

// ── Countdown Badge ──
class _CountdownBadge extends StatefulWidget {
  final DateTime waktuSelesai;
  const _CountdownBadge({required this.waktuSelesai});
  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge> {
  late Timer _t;
  Duration _sisa = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sisa = widget.waktuSelesai.difference(DateTime.now());
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _sisa = widget.waktuSelesai.difference(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sisa <= Duration.zero) return const SizedBox();
    final jam = _sisa.inHours;
    final mnt = _sisa.inMinutes.remainder(60);
    final dtk = _sisa.inSeconds.remainder(60);
    final isUrgent = _sisa.inMinutes < 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red : Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer,
            color: isUrgent ? Colors.white : Colors.greenAccent,
            size: 13),
        const SizedBox(width: 5),
        Text(
            jam > 0
                ? "${jam.toString().padLeft(2, '0')}:${mnt.toString().padLeft(2, '0')}:${dtk.toString().padLeft(2, '0')}"
                : "${mnt.toString().padLeft(2, '0')}:${dtk.toString().padLeft(2, '0')}",
            style: TextStyle(
                color: isUrgent ? Colors.white : Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
      ]),
    );
  }
}

// ============================================================
// LOCK SCREEN
// ============================================================
class LockScreen extends StatefulWidget {
  final UserAccount user;
  const LockScreen({super.key, required this.user});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _p = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, size: 55, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text("AKSES TERKUNCI",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    letterSpacing: 2)),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Kamu telah melampaui batas pelanggaran.\nHubungi proktor untuk membuka kunci perangkat ini.",
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _p,
                obscureText: _obscure,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, letterSpacing: 4),
                decoration: InputDecoration(
                  labelText: "PIN Proktor",
                  labelStyle:
                  const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 280,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade900,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _unlock,
                icon: _loading
                    ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.red.shade900,
                        strokeWidth: 2))
                    : const Icon(Icons.lock_open),
                label: Text(_loading ? "Memeriksa..." : "BUKA KUNCI"),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _unlock() async {
    if (_p.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final d = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_config')
          .get();
      if (d.exists &&
          _p.text.trim() ==
              (d.data() as Map)['proctor_password']?.toString()) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.id)
            .update({'status_mengerjakan': 'mengerjakan'});
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("PIN salah! Coba lagi."),
            backgroundColor: Colors.orange,
          ));
        }
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }
}

// ============================================================
// PASSWORD RESET WIDGET
// ============================================================
class PasswordResetWidget extends StatefulWidget {
  const PasswordResetWidget({super.key});
  @override
  State<PasswordResetWidget> createState() => _PasswordResetWidgetState();
}

class _PasswordResetWidgetState extends State<PasswordResetWidget> {
  final _searchCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _searching = false;
  bool _saving = false;
  bool _obscure = true;
  UserAccount? _found;
  String? _notFound;

  void _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _found = null;
      _notFound = null;
    });
    try {
      // Cari by username
      var snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: q)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        setState(() {
          _found = UserAccount.fromFirestore(snap.docs.first);
          _searching = false;
        });
        return;
      }
      // Cari by nama
      snap = await FirebaseFirestore.instance
          .collection('users')
          .where('nama', isEqualTo: q)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        setState(() {
          _found = UserAccount.fromFirestore(snap.docs.first);
          _searching = false;
        });
      } else {
        setState(() {
          _notFound = "Akun \"$q\" tidak ditemukan.";
          _searching = false;
        });
      }
    } catch (e) {
      setState(() {
        _notFound = "Terjadi kesalahan pencarian.";
        _searching = false;
      });
    }
  }

  void _save() async {
    if (_found == null || _newPassCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_found!.id)
        .update({'password': _newPassCtrl.text.trim()});
    setState(() {
      _saving = false;
      _found = null;
      _newPassCtrl.clear();
      _searchCtrl.clear();
      _notFound = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Password berhasil diubah!"),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: "Username atau Nama",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white),
            onPressed: _searching ? null : _search,
            child: _searching
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text("CARI"),
          ),
        ]),
        if (_notFound != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 16),
            const SizedBox(width: 6),
            Text(_notFound!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ]),
        ],
        if (_found != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(_found!.nama,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                const SizedBox(height: 2),
                Text(
                    "Username: ${_found!.username}  •  Role: ${_found!.role}  •  Kelas: ${_found!.kode}",
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _newPassCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: "Password Baru",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: const Text("SIMPAN"),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ]);
}