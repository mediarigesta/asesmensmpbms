part of '../main.dart';

// ============================================================
// HOME SCREEN (SISWA)
// ============================================================
class HomeScreen extends StatefulWidget {
  final UserAccount user;
  const HomeScreen({super.key, required this.user});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with IdleTimeoutMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _tokenCtrl = TextEditingController();
  List<ExamData> _availableExams = [];
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
    startIdleWatcher();
  }

  // Load ujian realtime pakai Stream agar selalu update
  void _loadExam() {
    _examSub = FirebaseFirestore.instance
        .collection('exam')
        .snapshots()
        .listen((snap) async {
      if (!mounted) return;
      final list = snap.docs.map((d) => ExamData.fromFirestore(d)).toList();
      // Cari SEMUA ujian yang sedang berlangsung dan cocok dengan jenjang siswa
      final found = list.where((e) =>
        e.isOngoing && widget.user.matchJenjang(e.jenjang)).toList();

      // Auto-reset: jika tidak ada ujian aktif tapi status masih "mengerjakan"
      if (found.isEmpty && widget.user.statusMengerjakan == 'mengerjakan') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.id)
            .update({'status_mengerjakan': 'belum mulai'});
      }

      if (!mounted) return;
      setState(() {
        _availableExams = found;
        _loading = false;
      });
    });
  }

  // Inisialisasi kamera depan (Android only)
  void _initCamera() async {
    if (!hasMobileFeatures) return; // Tidak tersedia di Windows/Web
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

  // Kirim status baterai ke Firestore tiap 1 menit (Android only)
  void _startBatteryReporter() {
    if (!hasMobileFeatures) return; // Tidak tersedia di Windows/Web
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
      final d = snap.data() as Map?;
      final msg = d?['message']?.toString() ?? "";
      final target = d?['target']?.toString() ?? 'semua';
      if (msg.isNotEmpty && (target == 'semua' || target == 'siswa')) {
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
    stopIdleWatcher();
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
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('saved_user_id');
              await prefs.remove('saved_username');
              await prefs.remove('saved_password');
              if (context.mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
            child: const Text("Keluar"),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeSideBar() {
    return SafeArea(
      child: Container(
        color: context.bm.surface,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.bm.primary, context.bm.gradient2],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.asset('assets/logo.png', width: 48, height: 48),
              const SizedBox(height: 10),
              Text(widget.user.nama,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Text('Kelas ' + widget.user.kode + ' · Ruang ' + widget.user.ruang,
                    style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              ListTile(
                leading: Image.asset('assets/logo.png', width: 20, height: 20),
                title: const Text('Dashboard', style: TextStyle(fontSize: 13)),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined, size: 20),
                title: const Text('Jadwal Ujian', style: TextStyle(fontSize: 13)),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => JadwalScreen(role: 'siswa', userKode: widget.user.kode),
                )),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_outline, size: 20),
                title: const Text('Profil Saya', style: TextStyle(fontSize: 13)),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfilePage(user: widget.user, canEdit: false),
                )),
              ),
              const Divider(height: 1),
              _buildThemeSwitcher(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red, size: 20),
                title: const Text('Keluar', style: TextStyle(color: Colors.red, fontSize: 13)),
                onTap: () => _confirmLogout(context),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildHomeDrawer() {
    return Drawer(
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.bm.primary, context.bm.gradient2],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Image.asset('assets/logo.png', width: 56, height: 56),
            ),
            const SizedBox(height: 12),
            Text(widget.user.nama,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Text('Kelas ' + widget.user.kode + ' · Ruang ' + widget.user.ruang,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ]),
        ),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            ListTile(
              leading: Image.asset('assets/logo.png', width: 22, height: 22),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Jadwal Ujian'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => JadwalScreen(role: 'siswa', userKode: widget.user.kode),
                ));
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil Saya'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfilePage(user: widget.user, canEdit: false),
                ));
              },
            ),
            const Divider(height: 1),
            _buildThemeSwitcher(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); _confirmLogout(context); },
            ),
          ]),
        ),
      ]),
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
      key: _scaffoldKey,
      backgroundColor: context.bm.surface,
      drawer: MediaQuery.of(context).size.width >= 900 ? null : _buildHomeDrawer(),
      body: Row(children: [
        if (MediaQuery.of(context).size.width >= 900)
          SizedBox(width: 240, child: _buildHomeSideBar()),
        Expanded(child: GestureDetector(
          onTap: resetIdleTimer,
          onPanDown: (_) => resetIdleTimer(),
          behavior: HitTestBehavior.translucent,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
        // Header gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 270,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.bm.primary, context.bm.gradient2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [BoxShadow(
                color: context.bm.primary.withValues(alpha: 0.25),
                blurRadius: 16, offset: const Offset(0, 8),
              )],
            ),
          ),
        ),

        SafeArea(
          child: Column(children: [
            // ── Header bar siswa ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 8, 0),
              child: Column(children: [
                // Baris atas: menu + sekolah + logout
                Row(children: [
                  if (MediaQuery.of(context).size.width < 900)
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white70),
                      onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                    ),
                  const Icon(Icons.school_outlined, color: Colors.white38, size: 13),
                  const SizedBox(width: 4),
                  const Expanded(child: Text("SMP Budi Mulia",
                      style: TextStyle(color: Colors.white38, fontSize: 12))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(DateFormat('EEE, dd MMM').format(now),
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                    tooltip: "Keluar",
                    onPressed: () => _confirmLogout(context),
                  ),
                ]),
                // Baris utama: greeting + nama + avatar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(greetIcon, color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        Text(greeting,
                            style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      ]),
                      const SizedBox(height: 4),
                      Text(widget.user.nama,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 24,
                              fontWeight: FontWeight.bold, height: 1.2),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(children: [
                        _chip(Icons.class_, "Kelas ${widget.user.kode}"),
                        const SizedBox(width: 6),
                        _chip(Icons.meeting_room, "Ruang ${widget.user.ruang}"),
                      ]),
                    ])),
                    const SizedBox(width: 12),
                    Container(
                      width: 58, height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.white30, width: 2),
                      ),
                      child: Center(
                        child: Text(widget.user.initials,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
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
                  const SizedBox(height: 12),

                  // Notifikasi jadwal ujian hari ini
                  _buildTodayJadwalNotif(),

                  // Reminder ujian mendatang (1-3 hari ke depan)
                  _buildUpcomingExamsReminder(),

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

                      // Cek status per-ujian dari exam_status
                      final examStatusMap = (userSnap.data!.data() as Map?)?['exam_status'] as Map<String, dynamic>? ?? {};
                      
                      // Filter ujian yang belum selesai untuk siswa ini
                      final availableExams = _availableExams.where((e) {
                        final status = examStatusMap[e.id]?['status'] ?? 'belum mulai';
                        return status != 'selesai';
                      }).toList();
                      
                      // Filter ujian yang sudah selesai
                      final completedExams = _availableExams.where((e) {
                        final status = examStatusMap[e.id]?['status'] ?? 'belum mulai';
                        return status == 'selesai';
                      }).toList();

                      if (availableExams.isEmpty && completedExams.isNotEmpty) {
                        // Semua ujian sudah selesai - tampilkan card selesai untuk ujian terakhir
                        return _sudahSelesaiCard(completedExams.last);
                      }

                      return Column(children: [
                        if (availableExams.isNotEmpty) ...[
                          // Label
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Ujian Tersedia",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                          const SizedBox(height: 10),
                          
                          // List of available exams
                          ...availableExams.map((exam) => _buildExamCard(exam)),
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

        // Kamera Pengawasan (pojok kanan bawah) — Android only
        if (hasMobileFeatures && _camReady && _cam != null)
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
                if (hasMobileFeatures)
                  const Text("Kamu sedang diawasi",
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.red,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ]),
      )),
    ]),
    );
  }

  // Build individual exam card for student
  Widget _buildExamCard(ExamData exam) {
    final now = DateTime.now();
    final tokenCtrl = TextEditingController();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam info card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.greenAccent, size: 9),
                      SizedBox(width: 4),
                      Text("SEDANG BERLANGSUNG",
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(exam.judul,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(exam.mapel,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.access_time, color: Colors.white70, size: 15),
                  const SizedBox(width: 5),
                  Text("${DateFormat('HH:mm').format(exam.waktuMulai)} — ${DateFormat('HH:mm').format(exam.waktuSelesai)}",
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                Builder(builder: (_) {
                  final sisa = exam.waktuSelesai.difference(now);
                  final jam = sisa.inHours;
                  final mnt = sisa.inMinutes.remainder(60);
                  return Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(children: [
                      const Icon(Icons.timer_outlined, color: Colors.amber, size: 15),
                      const SizedBox(width: 5),
                      Text(jam > 0 ? "Sisa $jam jam $mnt menit" : "Sisa $mnt menit lagi",
                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Instruksi
          if (exam.instruksi.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(exam.instruksi,
                          style: const TextStyle(color: Colors.orange, fontSize: 13))),
                ],
              ),
            ),
          
          if (exam.instruksi.isNotEmpty) const SizedBox(height: 16),
          
          // Input Token
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.vpn_key, color: Color(0xFF0F172A), size: 17),
                  SizedBox(width: 6),
                  Text("Masukkan Token Ujian",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: tokenCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "······",
                  hintStyle: const TextStyle(letterSpacing: 8, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text("MULAI UJIAN", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () => _startExamFor(exam, tokenCtrl.text.trim()),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // Start specific exam with token
  void _startExamFor(ExamData exam, String tokenInput) async {
    if (tokenInput.isEmpty) {
      _snack("Masukkan token ujian terlebih dahulu!", Colors.orange);
      return;
    }
    
    // Debug: print input token
    print("DEBUG: Input token = '$tokenInput'");
    
    final ts = await FirebaseFirestore.instance
        .collection('settings').doc('exam_token').get();
    String serverToken = "";
    if (!ts.exists) {
      _snack("Token ujian tidak ditemukan! Silakan hubungi admin.", Colors.red);
      return;
    } else {
      serverToken = (ts.data() as Map)['current_token']?.toString() ?? "";
      print("DEBUG: Server token = '$serverToken'");
    }
    
    print("DEBUG: Comparing '$tokenInput' == '$serverToken'");
    if (tokenInput.trim() == serverToken.trim()) {
      if (mounted) {
        final examDoc = await FirebaseFirestore.instance.collection('exam').doc(exam.id).get();
        final isNative = (examDoc.data() as Map?)?['mode'] == 'native';

        if (kIsWeb && exam.antiCurang) {
          final confirmed = await _showWebGuidedAccessConfirmDialog();
          if (!confirmed) return;
        }

        if (isNative) {
          if ((isAndroid || (!kIsWeb && Platform.isIOS)) && exam.antiCurang) {
            final isAdmin = await KioskService.isAdminActive();
            if (!isAdmin) {
              if (!mounted) return;
              await _showKioskRequiredDialog();
              return;
            }
          }
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => NativeExamScreen(
                exam: exam, user: widget.user,
                cam: hasMobileFeatures ? _cam : null,
              )));
        } else {
          if ((isAndroid || (!kIsWeb && Platform.isIOS)) && exam.antiCurang) {
            final isAdmin = await KioskService.isAdminActive();
            if (!isAdmin) {
              if (!mounted) return;
              await _showKioskRequiredDialog();
              return;
            }
          }
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => ExamScreen(
                exam: exam, user: widget.user,
                cam: hasMobileFeatures ? _cam : null,
              )));
        }
      }
    } else {
      _snack("Token salah! Silakan coba lagi.", Colors.red);
    }
  }

  // Show kiosk required dialog
  Future<void> _showKioskRequiredDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.lock, color: Colors.orange),
          SizedBox(width: 8),
          Text("Mode Kiosk Diperlukan"),
        ]),
        content: const Text(
          "Ujian ini menggunakan mode anti-curang.\n\n"
          "Aplikasi membutuhkan izin Device Administrator untuk mengunci layar selama ujian berlangsung.\n\n"
          "Tanpa izin ini, Anda tidak dapat memulai ujian.",
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
          ),
        ],
      ),
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

  // Legacy _startExam - uses first available exam with main token controller
  void _startExam() async {
    if (_availableExams.isEmpty) {
      _snack("Tidak ada ujian tersedia!", Colors.orange);
      return;
    }
    _startExamFor(_availableExams.first, _tokenCtrl.text.trim());
  }

  // Removed old _startExam implementation - now using _startExamFor above

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

  // ── iOS: dialog wajib aktifkan Guided Access sebelum ujian ──
  Future<void> _showGuidedAccessRequiredDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          bool checking = false;
          String statusMsg = '';
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50, shape: BoxShape.circle),
              child: Icon(Icons.accessibility_new_rounded,
                  color: Colors.blue.shade700, size: 36),
            ),
            title: const Text('Aktifkan Guided Access',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ujian ini menggunakan mode anti-curang. '
                  'Anda harus mengaktifkan Guided Access agar layar terkunci selama ujian.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                _gaStep('1', 'Ketuk tiga kali tombol samping iPad (atau tombol Home)'),
                _gaStep('2', 'Pilih "Guided Access" dari menu yang muncul'),
                _gaStep('3', 'Ketuk "Mulai" di pojok kanan atas layar'),
                _gaStep('4', 'Kembali ke aplikasi ini, lalu ketuk "Coba Lagi"'),
                if (statusMsg.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(statusMsg,
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade700))),
                    ]),
                  ),
                ],
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white),
                onPressed: checking
                    ? null
                    : () async {
                        setDialogState(() { checking = true; statusMsg = ''; });
                        final active = await KioskService.isAdminActive();
                        if (active) {
                          Navigator.pop(ctx, true);
                          // Mulai ulang ujian — user harus klik Mulai Ujian lagi
                          _snack('Guided Access aktif! Silakan klik Mulai Ujian kembali.', Colors.green);
                        } else {
                          setDialogState(() {
                            checking = false;
                            statusMsg = 'Guided Access belum aktif. Ikuti langkah di atas.';
                          });
                        }
                      },
                icon: checking
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Coba Lagi'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _gaStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
              color: Colors.blue.shade700, shape: BoxShape.circle),
          child: Center(child: Text(num,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4))),
      ]),
    );
  }

  // ── Web (Safari iPad): dialog konfirmasi Guided Access ──────────────────
  Future<bool> _showWebGuidedAccessConfirmDialog() async {
    if (!mounted) return false;
    bool checked = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.accessibility_new_rounded, color: Colors.blue.shade700, size: 36),
          ),
          title: const Text('Aktifkan Guided Access',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ujian ini menggunakan mode anti-curang. '
                'Aktifkan Guided Access agar layar iPad terkunci selama ujian.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              _gaStep('1', 'Ketuk tiga kali tombol samping iPad (atau tombol Home)'),
              _gaStep('2', 'Pilih "Guided Access" dari menu yang muncul'),
              _gaStep('3', 'Ketuk "Mulai" di pojok kanan atas layar'),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: checked ? Colors.green.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: checked ? Colors.green.shade300 : Colors.grey.shade300),
                ),
                child: CheckboxListTile(
                  value: checked,
                  activeColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  title: const Text(
                    'Saya sudah mengaktifkan Guided Access',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (val) => setDialogState(() => checked = val ?? false),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  const Expanded(child: Text(
                    'Jika Anda berpindah tab atau keluar dari halaman ini, pelanggaran akan tercatat.',
                    style: TextStyle(fontSize: 11, height: 1.4),
                  )),
                ]),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: checked ? Colors.blue.shade700 : Colors.grey.shade400,
                foregroundColor: Colors.white,
              ),
              onPressed: checked ? () => Navigator.pop(ctx, true) : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Mulai Ujian'),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  // Cek apakah string hari mengandung tanggal hari ini
  bool _hariIsToday(String hari) {
    final today = DateTime.now();
    final d  = today.day.toString().padLeft(2, '0');
    final d2 = today.day.toString();
    final m  = today.month.toString().padLeft(2, '0');
    final y  = today.year.toString();
    final lo = hari.toLowerCase();
    if (lo.contains('$d/$m/$y') || lo.contains('$d-$m-$y')) return true;
    const months = [
      'januari','februari','maret','april','mei','juni',
      'juli','agustus','september','oktober','november','desember'
    ];
    final monthName = months[today.month - 1];
    return lo.contains('$d $monthName') || lo.contains('$d2 $monthName');
  }

  /// Banner: ujian terjadwal dalam 3 hari ke depan (dari collection exam)
  Widget _buildUpcomingExamsReminder() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('exam')
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final now = DateTime.now();
        final threeDaysLater = now.add(const Duration(days: 3));
        final upcoming = snap.data!.docs
            .map((d) => ExamData.fromFirestore(d))
            .where((e) =>
                e.waktuMulai.isAfter(now) &&
                e.waktuMulai.isBefore(threeDaysLater) &&
                !e.isDraft &&
                widget.user.matchJenjang(e.jenjang))
            .toList()
          ..sort((a, b) => a.waktuMulai.compareTo(b.waktuMulai));

        if (upcoming.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            border: Border.all(color: const Color(0xFFFBBF24)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notifications_active, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ujian Mendatang (${upcoming.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFFD97706))),
                    const SizedBox(height: 6),
                    ...upcoming.map((e) {
                      final diff = e.waktuMulai.difference(now);
                      String waktuLabel;
                      if (diff.inMinutes < 60) {
                        waktuLabel = '${diff.inMinutes} menit lagi';
                      } else if (diff.inHours < 24) {
                        waktuLabel = '${diff.inHours} jam lagi';
                      } else {
                        waktuLabel = '${diff.inDays} hari lagi';
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          Icon(
                            diff.inHours < 1 ? Icons.alarm : Icons.schedule,
                            size: 13,
                            color: diff.inHours < 1 ? Colors.red : const Color(0xFF92400E),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${e.judul} · ${e.mapel}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: diff.inHours < 1
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : const Color(0xFFFDE68A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(waktuLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: diff.inHours < 1 ? Colors.red : const Color(0xFF92400E))),
                          ),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Banner: jadwal ujian siswa hari ini (dari jadwal/ujian)
  Widget _buildTodayJadwalNotif() {
    final kelasNum = RegExp(r'(\d)').firstMatch(widget.user.kode)?.group(1) ?? '';
    if (kelasNum.isEmpty) return const SizedBox.shrink();
    final kelasKey = 'kelas$kelasNum';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('jadwal').doc('ujian').get(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final rows = List<Map<String, dynamic>>.from(data['rows'] as List? ?? []);

        final todayItems = rows.where((r) {
          final hari  = r['hari']?.toString() ?? '';
          final mapel = r[kelasKey]?.toString() ?? '';
          return _hariIsToday(hari) && mapel.isNotEmpty && mapel != '-';
        }).toList();

        if (todayItems.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            border: Border.all(color: const Color(0xFF93C5FD)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.event_note, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Jadwal Ujian Hari Ini',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF2563EB))),
                    const SizedBox(height: 4),
                    ...todayItems.map((r) => Text(
                          '• ${r[kelasKey]}  ·  Pukul ${r['pukul'] ?? '-'}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF1E3A8A)),
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24, width: 0.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 11),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
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

