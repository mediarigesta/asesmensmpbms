part of '../main.dart';

// ============================================================
// NATIVE EXAM SCREEN — Ujian tanpa Google Form
// ============================================================
class NativeExamScreen extends StatefulWidget {
  final ExamData exam;
  final UserAccount user;
  final CameraController? cam;
  const NativeExamScreen({super.key, required this.exam, required this.user, this.cam});
  @override
  State<NativeExamScreen> createState() => _NativeExamScreenState();
}

// ============================================================
// PATCH: NativeExamScreen — Anti-Curang yang diperkuat
// Ganti seluruh class _NativeExamScreenState dengan ini
// ============================================================

class _NativeExamScreenState extends State<NativeExamScreen> with WidgetsBindingObserver {
  List<SoalModel> _soals = [];
  List<SoalModel> _soalsOriginal = []; // before shuffle
  bool _loading = true;
  int _currentIndex = 0;
  final Map<String, String> _jawaban = {};
  bool _submitted = false;
  int _curang = 0;
  Timer? _autoSubmitTimer;
  Timer? _autoSaveTimer;
  DateTime? _serverStartTime;
  final Map<String, List<int>> _shuffledOptionIndices = {}; // soalId -> shuffled indices

  // Activity log per soal
  final Map<String, int> _timePerSoal = {}; // soalId -> seconds spent
  DateTime? _soalViewStart;

  // ── Kiosk overlay ──
  bool _showKioskLock = false;
  bool _mustUsePin = false; // true = batas terlampaui, wajib PIN proktor
  final _kioskPinCtrl = TextEditingController();
  bool _kioskPinObscure = true;
  bool _kioskPinLoading = false;
  String _kioskPinError = '';

  // ── Cooldown PIN ──
  DateTime? _pinCooldownUntil;
  Timer? _pinCooldownTimer;
  int _pinWrongCount = 0;

  // ── Timer tap proktor (tap 5x untuk akses darurat) ──
  int _timerTapCount = 0;
  Timer? _timerTapReset;

  // ── Proktor PIN dialog (tap timer 5x) ──
  bool _showProktorDialog = false;
  final _proktorPinCtrl = TextEditingController();
  bool _proktorPinObscure = true;
  bool _proktorPinLoading = false;
  String _proktorPinError = '';
  DateTime? _proktorCooldownUntil;
  Timer? _proktorCooldownTimer;

  // ── Mencegah trigger ganda lifecycle ──
  bool _lifecycleProcessing = false;
  DateTime? _lastLifecycleTrigger;

  // ── Polling timer — paksa kunci tetap aktif ──
  Timer? _kioskEnforceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initExam();
    _loadSoal();
    // Auto-save jawaban setiap 30 detik
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_submitted && _jawaban.isNotEmpty) _autoSaveDraft();
    });
    _soalViewStart = DateTime.now();
    // Paksa kunci layar setiap 1 detik (anti bypass Home button)
    if (isAndroid && widget.exam.antiCurang) {
      _kioskEnforceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _submitted) return;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      });
    }
    // Kamera hanya digunakan untuk preview di layar siswa
    if (widget.exam.autoSubmit) {
      final remaining = widget.exam.waktuSelesai.difference(DateTime.now());
      if (remaining > Duration.zero) {
        _autoSubmitTimer = Timer(remaining, () => _doSubmit(reason: "time_up"));
      }
    }

    // Broadcast listener
    FirebaseFirestore.instance
        .collection('settings')
        .doc('broadcast')
        .snapshots()
        .listen((s) {
      if (!mounted || !s.exists) return;
      final d = s.data() as Map?;
      final msg = d?['message']?.toString() ?? "";
      final target = d?['target']?.toString() ?? 'semua';
      if (msg.isNotEmpty && !_showKioskLock && (target == 'semua' || target == 'siswa')) {
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
    if (isAndroid) {
      try {
        await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

        // Cek apakah sudah jadi Device Admin
        final isAdmin = await KioskService.isAdminActive();
        if (!isAdmin) {
          // Panggil startKiosk → akan tampilkan dialog Device Admin
          await KioskService.start();
          // Tunggu user approve dialog (maks 10 detik)
          for (int i = 0; i < 20; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (await KioskService.isAdminActive()) break;
          }
        }
        // Sekarang startKiosk lagi — kali ini dengan Device Admin aktif
        await KioskService.start();
      } catch (e) {
        debugPrint('initExam lock error: \$e');
      }
    } else if (!kIsWeb && Platform.isIOS) {
      // iOS: Guided Access sudah aktif, hanya lock orientasi
      try {
        await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } catch (_) {}
    } else if (isWindows) {
      await KioskService.start();
    }
    await updateExamStatusForUser(
      exam: widget.exam,
      user: widget.user,
      status: 'mengerjakan',
    );
  }

  // Tap pada timer — 5x tap dalam 3 detik → muncul dialog proktor
  void _onTimerTap() {
    _timerTapCount++;
    _timerTapReset?.cancel();
    _timerTapReset = Timer(const Duration(seconds: 3), () {
      _timerTapCount = 0;
    });
    if (_timerTapCount >= 5) {
      _timerTapCount = 0;
      _timerTapReset?.cancel();
      setState(() {
        _showProktorDialog = true;
        _proktorPinCtrl.clear();
        _proktorPinError = '';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {

    // Cegah trigger ganda dalam 1 detik
    final now = DateTime.now();
    if (_lastLifecycleTrigger != null &&
        now.difference(_lastLifecycleTrigger!).inMilliseconds < 1000) return;

    final lostFocus = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (isWindows && state == AppLifecycleState.inactive);

    if (lostFocus) {
      _lastLifecycleTrigger = now;
      _curang++;
      final max = widget.exam.maxCurang;
      final terlampaui = _curang >= max;

      // Update Firestore: status khusus ujian ini + jumlah pelanggaran
      // Status ditandai "melanggar" sejak pelanggaran pertama.
      await updateExamStatusForUser(
        exam: widget.exam,
        user: widget.user,
        status: 'melanggar',
        violationCount: _curang,
        extraFields: {
          'jumlahPelanggaran': _curang,
          'exam_status.${widget.exam.id}.lastViolationReason': 'lost_focus',
        },
      );

      if (mounted) {
        setState(() {
          _showKioskLock = true;
          _mustUsePin = terlampaui;
          _kioskPinCtrl.clear();
          _kioskPinError = '';
          _pinWrongCount = 0;
          _pinCooldownUntil = null;
          _pinCooldownTimer?.cancel();
        });
      }

      // Re-enforce immersive mode di Android
      if (isAndroid) {
        try {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
        } catch (_) {}
      }
    }

    // Kembali ke foreground — paksa kunci ulang
    if (state == AppLifecycleState.resumed) {
      if (!kIsWeb && Platform.isIOS && widget.exam.antiCurang && !_submitted) {
        // Cek apakah Guided Access masih aktif
        final gaActive = await KioskService.isActive();
        if (!gaActive && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
              title: const Text("Guided Access Nonaktif",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: const Text(
                "Guided Access tidak aktif. Pelanggaran ini telah dicatat.\n\n"
                "Aktifkan kembali Guided Access (triple-click tombol samping) "
                "agar ujian dapat dilanjutkan.",
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 46),
                  ),
                  icon: const Icon(Icons.accessibility_new_rounded, size: 18),
                  label: const Text("Saya Mengerti"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
      if (isAndroid) {
        try {
          // Re-enforce semua layer kunci
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
          // Delay agar activity benar-benar foreground sebelum startLockTask
          await Future.delayed(const Duration(milliseconds: 500));
          await KioskService.start();
          // Tampilkan dialog paksa tap untuk re-lock
          if (mounted && widget.exam.antiCurang && !_submitted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                icon: const Icon(Icons.lock, color: Colors.red, size: 48),
                title: const Text("Kembali ke Mode Ujian",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold)),
                content: const Text(
                  "Kamu keluar dari mode ujian.\n\nTekan tombol di bawah untuk mengunci kembali perangkat dan melanjutkan ujian.\n\nPelanggaran ini telah dicatat.",
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 48),
                    ),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text("Kunci & Lanjutkan Ujian"),
                    onPressed: () async {
                      Navigator.pop(context);
                      await KioskService.start();
                    },
                  ),
                ],
              ),
            );
          }
        } catch (_) {}
      }
      // Pastikan overlay tetap tampil saat kembali ke app
      if (mounted && widget.exam.antiCurang && !_submitted) {
        // Delay singkat agar Flutter rebuild selesai dulu
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_submitted) {
            setState(() {
              // Jika sudah ada pelanggaran sebelumnya, overlay tetap tampil
              if (_curang > 0) _showKioskLock = true;
            });
          }
        });
      }
    }
  }

  Future<void> _verifyKioskPin() async {
    // Cek cooldown
    if (_pinCooldownUntil != null && DateTime.now().isBefore(_pinCooldownUntil!)) {
      final sisa = _pinCooldownUntil!.difference(DateTime.now()).inSeconds;
      setState(() => _kioskPinError = 'Tunggu $sisa detik sebelum mencoba lagi.');
      return;
    }
    if (_kioskPinCtrl.text.trim().isEmpty) {
      setState(() => _kioskPinError = 'Masukkan PIN proktor!');
      return;
    }
    setState(() { _kioskPinLoading = true; _kioskPinError = ''; });
    try {
      final d = await FirebaseFirestore.instance
          .collection('settings').doc('app_config').get();
      final correctPin = (d.data() as Map?)?['proctor_password']?.toString() ?? '';
      if (_kioskPinCtrl.text.trim() == correctPin) {
        // PIN benar — buka overlay & reset status ke mengerjakan, catat berapa kali proktor bantu
        await updateExamStatusForUser(
          exam: widget.exam,
          user: widget.user,
          status: 'mengerjakan',
          extraFields: {
            'exam_status.${widget.exam.id}.proktorUnlockCount': FieldValue.increment(1),
          },
        );
        _pinCooldownTimer?.cancel();
        if (mounted) {
          setState(() {
            _showKioskLock = false;
            _kioskPinLoading = false;
            _kioskPinError = '';
            _pinWrongCount = 0;
            _pinCooldownUntil = null;
          });
        }
      } else {
        // PIN salah → tambah hitungan, terapkan cooldown progresif
        _pinWrongCount++;
        final cooldownDetik = _pinWrongCount >= 3 ? 60
            : _pinWrongCount == 2 ? 30 : 10;
        final cooldownUntil = DateTime.now().add(Duration(seconds: cooldownDetik));

        _pinCooldownTimer?.cancel();
        _pinCooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) { t.cancel(); return; }
          final sisa = cooldownUntil.difference(DateTime.now()).inSeconds;
          if (sisa <= 0) {
            t.cancel();
            if (mounted) setState(() {
              _kioskPinError = 'PIN salah! Coba lagi.';
              _pinCooldownUntil = null;
            });
          } else {
            if (mounted) setState(() =>
            _kioskPinError = 'PIN salah! Tunggu $sisa detik (percobaan ke-$_pinWrongCount).');
          }
        });

        if (mounted) {
          setState(() {
            _kioskPinLoading = false;
            _kioskPinError = 'PIN salah! Tunggu $cooldownDetik detik.';
            _pinCooldownUntil = cooldownUntil;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        _kioskPinLoading = false;
        _kioskPinError = 'Gagal verifikasi. Coba lagi.';
      });
    }
  }

  Future<void> _verifyProktorPin() async {
    if (_proktorCooldownUntil != null && DateTime.now().isBefore(_proktorCooldownUntil!)) {
      final sisa = _proktorCooldownUntil!.difference(DateTime.now()).inSeconds;
      setState(() => _proktorPinError = 'Tunggu $sisa detik lagi.');
      return;
    }
    if (_proktorPinCtrl.text.trim().isEmpty) return;
    setState(() { _proktorPinLoading = true; _proktorPinError = ''; });
    try {
      final d = await FirebaseFirestore.instance
          .collection('settings').doc('app_config').get();
      final correctPin = (d.data() as Map?)?['proctor_password']?.toString() ?? '';
      if (_proktorPinCtrl.text.trim() == correctPin) {
        // Catat bahwa proktor telah menginput PIN untuk ujian ini
        await updateExamStatusForUser(
          exam: widget.exam,
          user: widget.user,
          status: 'mengerjakan',
          extraFields: {
            'exam_status.${widget.exam.id}.proktorUnlockCount': FieldValue.increment(1),
          },
        );
        setState(() { _showProktorDialog = false; _proktorPinLoading = false; });
        if (mounted) _showProktorActionDialog();
      } else {
        final cooldown = DateTime.now().add(const Duration(seconds: 30));
        setState(() {
          _proktorCooldownUntil = cooldown;
          _proktorPinLoading = false;
          _proktorPinError = 'PIN salah! Tunggu 30 detik.';
        });
        _proktorCooldownTimer?.cancel();
        _proktorCooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) { t.cancel(); return; }
          final sisa = cooldown.difference(DateTime.now()).inSeconds;
          if (sisa <= 0) {
            t.cancel();
            if (mounted) setState(() { _proktorPinError = ''; _proktorCooldownUntil = null; });
          } else {
            if (mounted) setState(() => _proktorPinError = 'PIN salah! Tunggu $sisa detik.');
          }
        });
      }
    } catch (e) {
      setState(() { _proktorPinLoading = false; _proktorPinError = 'Gagal verifikasi.'; });
    }
  }

  void _showProktorActionDialog() {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, color: Colors.teal),
          SizedBox(width: 8),
          Text('Akses Proktor'),
        ]),
        content: const Text('PIN proktor benar. Pilih tindakan:'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          // Lanjutkan ujian
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Lanjutkan Ujian'),
          ),
          const SizedBox(height: 8),
          // Keluar ke Home — tanpa submit
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            icon: const Icon(Icons.home),
            label: const Text('Keluar ke Home'),
            onPressed: () async {
              Navigator.pop(context); // tutup dialog
              await _exitToHome();
            },
          ),
          const SizedBox(height: 8),
          // Force submit
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Force Submit'),
            onPressed: () { Navigator.pop(context); _doSubmit(reason: 'proktor_force'); },
          ),
        ],
      ),
    );
  }

  // Keluar ke HomeScreen — matikan kiosk, reset status, kembali ke home
  Future<void> _exitToHome() async {
    try {
      // Stop semua timer
      _kioskEnforceTimer?.cancel();
      _autoSubmitTimer?.cancel();
      _pinCooldownTimer?.cancel();
      _proktorCooldownTimer?.cancel();

      // Matikan kiosk lock
      if (isAndroid) {
        await KioskService.stop();
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      } else if (!kIsWeb && Platform.isIOS) {
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        // Ingatkan siswa untuk nonaktifkan Guided Access
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.lock_open_rounded, color: Colors.green, size: 44),
              title: const Text("Nonaktifkan Guided Access",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: const Text(
                "Ujian selesai. Silakan nonaktifkan Guided Access:\n\n"
                "Ketuk tiga kali tombol samping (atau Home), "
                "lalu ketuk 'Akhiri'.",
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK, Mengerti"),
                ),
              ],
            ),
          );
        }
      } else if (isWindows) {
        await KioskService.stop();
      }

      // Reset status siswa untuk ujian ini di Firestore
      await updateExamStatusForUser(
        exam: widget.exam,
        user: widget.user,
        status: 'belum mulai',
        violationCount: 0,
      );

      if (!mounted) return;

      // Kembali ke HomeScreen — pop semua route sampai home
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('exitToHome error: \$e');
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _loadSoal() async {
    final snap = await FirebaseFirestore.instance
        .collection('exam').doc(widget.exam.id).collection('soal')
        .orderBy('nomor').get();
    final soals = snap.docs.map((d) => SoalModel.fromMap(d.data(), d.id)).toList();
    _soalsOriginal = List.from(soals);

    // Randomisasi soal berdasarkan user ID (konsisten per siswa)
    final seed = widget.user.id.hashCode;
    final rng = Random(seed);
    soals.shuffle(rng);

    // Randomisasi opsi PG per soal
    for (final s in soals) {
      if (s.tipe == TipeSoal.pilihanGanda && s.pilihan.length > 1) {
        final indices = List.generate(s.pilihan.length, (i) => i);
        indices.shuffle(Random(seed ^ s.id.hashCode));
        _shuffledOptionIndices[s.id] = indices;
      }
    }

    // Resume: load draft jawaban jika ada
    try {
      final draftDoc = await FirebaseFirestore.instance
          .collection('exam').doc(widget.exam.id)
          .collection('draft_jawaban').doc(widget.user.id).get();
      if (draftDoc.exists) {
        final data = draftDoc.data() as Map<String, dynamic>? ?? {};
        final saved = data['jawaban'] as Map<String, dynamic>? ?? {};
        saved.forEach((k, v) => _jawaban[k] = v.toString());
        _curang = (data['curangCount'] as int?) ?? 0;
        final lastIndex = (data['lastSoalIndex'] as int?) ?? 0;
        _currentIndex = lastIndex.clamp(0, soals.length - 1);
      }
    } catch (_) {}

    // Record server start time
    try {
      final serverDoc = await FirebaseFirestore.instance
          .collection('exam').doc(widget.exam.id)
          .collection('exam_sessions').doc(widget.user.id).get();
      if (serverDoc.exists) {
        _serverStartTime = (serverDoc.data()?['startedAt'] as Timestamp?)?.toDate();
      } else {
        await FirebaseFirestore.instance
            .collection('exam').doc(widget.exam.id)
            .collection('exam_sessions').doc(widget.user.id)
            .set({'startedAt': FieldValue.serverTimestamp(), 'userId': widget.user.id});
      }
    } catch (_) {}

    setState(() {
      _soals = soals;
      _loading = false;
    });
  }

  // Auto-save draft jawaban ke Firestore
  Future<void> _autoSaveDraft() async {
    if (_submitted) return;
    // Track time on current soal
    _recordSoalTime();
    _soalViewStart = DateTime.now();
    try {
      await FirebaseFirestore.instance
          .collection('exam').doc(widget.exam.id)
          .collection('draft_jawaban').doc(widget.user.id)
          .set({
        'jawaban': _jawaban,
        'lastSoalIndex': _currentIndex,
        'curangCount': _curang,
        'timePerSoal': _timePerSoal,
        'updatedAt': FieldValue.serverTimestamp(),
        'siswaId': widget.user.id,
        'namaSiswa': widget.user.nama,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // Record time spent on current soal
  void _recordSoalTime() {
    if (_soalViewStart != null && _soals.isNotEmpty) {
      final soalId = _soals[_currentIndex].id;
      final elapsed = DateTime.now().difference(_soalViewStart!).inSeconds;
      _timePerSoal[soalId] = (_timePerSoal[soalId] ?? 0) + elapsed;
    }
  }

  void _doSubmit({String reason = "manual"}) async {
    if (_submitted) return;
    _submitted = true;
    _autoSubmitTimer?.cancel();
    _autoSaveTimer?.cancel();
    _recordSoalTime(); // final time record
    if (isAndroid) {
      await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      } catch (_) {}
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (_) {}
    } else if (isWindows) {
      await KioskService.stop();
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final jwbRef = FirebaseFirestore.instance
          .collection('exam').doc(widget.exam.id).collection('jawaban');
      int totalNilai = 0;
      int totalBenar = 0;
      for (final soal in _soals) {
        final jawaban = _jawaban[soal.id] ?? '';
        final benar = soal.tipe != TipeSoal.uraian
            ? jawaban.toUpperCase() == soal.kunciJawaban.toUpperCase()
            : null;
        final nilaiDapat = (benar == true) ? soal.skor : 0;
        totalNilai += nilaiDapat;
        if (benar == true) totalBenar++;
        batch.set(jwbRef.doc('${widget.user.id}_${soal.id}'), {
          'siswaId': widget.user.id,
          'namaSiswa': widget.user.nama,
          'soalId': soal.id,
          'jawaban': jawaban,
          'benar': benar,
          'nilaiDapat': nilaiDapat,
          'timeSpent': _timePerSoal[soal.id] ?? 0,
          'submittedAt': FieldValue.serverTimestamp(),
        });
      }
      // Save activity log / summary
      final logRef = FirebaseFirestore.instance
          .collection('exam').doc(widget.exam.id)
          .collection('activity_log').doc(widget.user.id);
      batch.set(logRef, {
        'siswaId': widget.user.id,
        'namaSiswa': widget.user.nama,
        'kelas': widget.user.ruang,
        'totalNilai': totalNilai,
        'totalBenar': totalBenar,
        'totalSoal': _soals.length,
        'jumlahDijawab': _jawaban.values.where((v) => v.isNotEmpty).length,
        'jumlahPelanggaran': _curang,
        'timePerSoal': _timePerSoal,
        'submitReason': reason,
        'submittedAt': FieldValue.serverTimestamp(),
      });
      // Delete draft
      final draftRef = FirebaseFirestore.instance
          .collection('exam').doc(widget.exam.id)
          .collection('draft_jawaban').doc(widget.user.id);
      batch.delete(draftRef);
      await batch.commit();
    } catch (_) {}

    await updateExamStatusForUser(
      exam: widget.exam,
      user: widget.user,
      status: 'selesai',
    );

    if (mounted) {
      if (reason == "time_up") {
        showDialog(
          context: context, barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Waktu Habis!"),
            content: const Text(
                "Waktu ujian telah berakhir. Jawaban Anda telah otomatis dikumpulkan."),
            actions: [
              ElevatedButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSubmitTimer?.cancel();
    _autoSaveTimer?.cancel();
    _timerTapReset?.cancel();
    _pinCooldownTimer?.cancel();
    _proktorCooldownTimer?.cancel();
    _kioskEnforceTimer?.cancel();
    _kioskPinCtrl.dispose();
    _proktorPinCtrl.dispose();
    if (isAndroid) {
      try {
        KioskService.stop(); // stopLockTask()
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      } catch (_) {}
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (_) {}
    } else if (isWindows) {
      KioskService.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_soals.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Ujian")),
        body: const Center(child: Text("Soal tidak tersedia.")),
      );
    }

    final soal = _soals[_currentIndex];
    final jumlahDijawab = _jawaban.values.where((v) => v.isNotEmpty).length;
    final max = widget.exam.maxCurang;

    final examBody = PopScope(
      canPop: false,
      child: Stack(children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Column(children: [
              // ── Header bar ──
              Container(
                color: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  // Timer — tap 5x untuk akses proktor darurat
                  GestureDetector(
                    onTap: _onTimerTap,
                    child: _CountdownBadge(waktuSelesai: widget.exam.waktuSelesai),
                  ),
                  const Spacer(),
                  Text("${_currentIndex + 1}/${_soals.length}",
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 8),
                  // Badge pelanggaran — tampil hanya jika ada pelanggaran
                  if (_curang > 0 && widget.exam.antiCurang)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: _curang >= max ? Colors.red : Colors.orange,
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.warning, color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text("$_curang/$max",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                ]),
              ),

              // Progress bar soal
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _soals.length,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 4,
              ),

              // ── Konten soal ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      _tipeBadge(soal.tipe),
                      const Spacer(),
                      Text("Skor: ${soal.skor}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                    const SizedBox(height: 12),

                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("Soal ${soal.nomor}",
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          if (soal.pertanyaan.isNotEmpty)
                            _buildTextWithLatex(soal.pertanyaan, 16),
                          if (soal.gambar.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildZoomableImage(base64Decode(soal.gambar), context),
                          ],
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (soal.tipe == TipeSoal.pilihanGanda) ..._buildPG(soal),
                    if (soal.tipe == TipeSoal.benarSalah) ..._buildBS(soal),
                    if (soal.tipe == TipeSoal.uraian) ..._buildUraian(soal),

                    // Watermark nama siswa
                    const SizedBox(height: 20),
                    Center(
                      child: Opacity(
                        opacity: 0.08,
                        child: Transform.rotate(
                          angle: -0.4,
                          child: Text(
                            widget.user.nama.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold,
                              color: Colors.black, letterSpacing: 4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

              // ── Navigasi soal ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  // Dot navigator
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _soals.length,
                      itemBuilder: (c, i) {
                        final dijawab =
                            _jawaban[_soals[i].id]?.isNotEmpty ?? false;
                        final isActive = i == _currentIndex;
                        return GestureDetector(
                          onTap: () { _recordSoalTime(); setState(() => _currentIndex = i); _soalViewStart = DateTime.now(); },
                          child: Container(
                            width: 30, height: 30,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF0F172A)
                                  : dijawab ? Colors.green.shade100
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActive ? const Color(0xFF0F172A)
                                    : dijawab ? Colors.green
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text("${i + 1}",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isActive ? Colors.white
                                          : dijawab ? Colors.green.shade700
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    if (_currentIndex > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () { _recordSoalTime(); setState(() => _currentIndex--); _soalViewStart = DateTime.now(); },
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text("Sebelumnya"),
                        ),
                      ),
                    if (_currentIndex > 0) const SizedBox(width: 10),
                    if (_currentIndex < _soals.length - 1)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white),
                          onPressed: () { _recordSoalTime(); setState(() => _currentIndex++); _soalViewStart = DateTime.now(); },
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text("Selanjutnya"),
                        ),
                      ),
                    if (_currentIndex == _soals.length - 1)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white),
                          onPressed: () => _showSubmitDialog(jumlahDijawab),
                          icon: const Icon(Icons.check_circle),
                          label: Text(
                              "Kumpulkan ($jumlahDijawab/${_soals.length})"),
                        ),
                      ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),

        // ── Kamera preview (Android only, selalu tampil) ──
        if (hasMobileFeatures && widget.cam != null)
          Positioned(
            bottom: 80, right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 7),
                      SizedBox(width: 3),
                      Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80, height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CameraPreview(widget.cam!),
                  ),
                ),
                const SizedBox(height: 3),
                const Text("Kamu sedang diawasi",
                    style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

        // ── Kiosk Lock Overlay ──
        _buildKioskOverlay(),

        // ── Proktor dialog (tap timer 5x) ──
        _buildProktorDialog(),
      ]),
    );

    return isWindows ? _WindowsKeyboardBlocker(child: examBody) : examBody;
  }

  // ============================================================
  // KIOSK LOCK OVERLAY — Layar terkunci saat siswa keluar app
  // ============================================================
  Widget _buildKioskOverlay() {
    if (!_showKioskLock) return const SizedBox.shrink();

    final max = widget.exam.maxCurang;
    // Warna overlay berdasarkan level pelanggaran
    final Color topColor;
    final Color botColor;
    if (_mustUsePin) {
      // Batas terlampaui — merah keras
      topColor = const Color(0xFF7F0000);
      botColor = const Color(0xFFB71C1C);
    } else if (_curang >= max - 1) {
      // Peringatan terakhir sebelum blokir — oranye gelap
      topColor = const Color(0xFF5D1A00);
      botColor = const Color(0xFFE65100);
    } else {
      // Pelanggaran biasa — biru gelap
      topColor = const Color(0xFF0F172A);
      botColor = const Color(0xFF1E3A5F);
    }

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [topColor, botColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  // ── Ikon utama ──
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2)),
                    child: Icon(
                      _mustUsePin ? Icons.gpp_bad : Icons.lock_outline,
                      size: 46, color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Judul ──
                  Text(
                    _mustUsePin ? "UJIAN DIBLOKIR" : "UJIAN DIJEDA",
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 10),

                  // ── Sub-teks ──
                  Text(
                    _mustUsePin
                        ? "Kamu telah melampaui batas pelanggaran.\nHubungi proktor untuk membuka kunci."
                        : "Kamu meninggalkan layar ujian!\nKetuk Lanjutkan atau masukkan PIN proktor.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  // ── Counter pelanggaran (visual) ──
                  _buildViolationCounter(max),
                  const SizedBox(height: 28),

                  // ── Tombol Lanjutkan (hanya jika belum terlampaui) ──
                  if (!_mustUsePin) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => setState(() => _showKioskLock = false),
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text("Lanjutkan Ujian",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Expanded(child: Divider(color: Colors.white24)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text("atau masukkan PIN proktor",
                            style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ),
                      const Expanded(child: Divider(color: Colors.white24)),
                    ]),
                    const SizedBox(height: 16),
                  ],

                  // ── Input PIN Proktor ──
                  TextField(
                    controller: _kioskPinCtrl,
                    obscureText: _kioskPinObscure,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 22, letterSpacing: 8, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: "PIN Proktor",
                      hintStyle: const TextStyle(letterSpacing: 2, fontSize: 14),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      errorText: _kioskPinError.isNotEmpty ? _kioskPinError : null,
                      suffixIcon: IconButton(
                        icon: Icon(_kioskPinObscure
                            ? Icons.visibility : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _kioskPinObscure = !_kioskPinObscure),
                      ),
                    ),
                    onSubmitted: (_) => _verifyKioskPin(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _mustUsePin
                            ? Colors.red.shade900 : const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _kioskPinLoading ? null : _verifyKioskPin,
                      icon: _kioskPinLoading
                          ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: _mustUsePin
                                  ? Colors.red.shade900 : const Color(0xFF0F172A),
                              strokeWidth: 2))
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(
                        _kioskPinLoading ? "Memeriksa..." : "BUKA DENGAN PIN PROKTOR",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Info kontak proktor
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: Colors.white54, size: 15),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Hubungi guru / proktor di ruangan untuk mendapatkan PIN pembuka.",
                          style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Visual counter pelanggaran (lingkaran merah bertahap) ──
  Widget _buildViolationCounter(int max) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(max, (i) {
          final filled = i < _curang;
          final isCurrent = i == _curang - 1;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: isCurrent ? 38 : 32,
            height: isCurrent ? 38 : 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled
                  ? (i >= max - 1 ? Colors.red : Colors.orange)
                  : Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: filled ? Colors.transparent : Colors.white30,
                width: 2,
              ),
              boxShadow: filled && isCurrent ? [
                BoxShadow(
                  color: (i >= max - 1 ? Colors.red : Colors.orange)
                      .withValues(alpha: 0.5),
                  blurRadius: 12, spreadRadius: 2,
                ),
              ] : [],
            ),
            child: Center(
              child: Icon(
                filled ? Icons.warning_rounded : Icons.circle_outlined,
                color: filled ? Colors.white : Colors.white30,
                size: isCurrent ? 20 : 16,
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 10),
      Text(
        _mustUsePin
            ? "Batas pelanggaran ($max/$max) terlampaui!"
            : "Pelanggaran $_curang dari $max",
        style: TextStyle(
          color: _curang >= max ? Colors.red.shade200 : Colors.orange.shade200,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    ]);
  }

  // ── Proktor dialog (tap timer 5x) ──
  Widget _buildProktorDialog() {
    if (!_showProktorDialog) return const SizedBox.shrink();
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Row(children: [
                Icon(Icons.admin_panel_settings, color: Colors.teal),
                SizedBox(width: 8),
                Text("Akses Proktor",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const SizedBox(height: 6),
              const Text("Masukkan PIN proktor untuk akses darurat.",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: _proktorPinCtrl,
                obscureText: _proktorPinObscure,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "PIN Proktor",
                  filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  errorText:
                  _proktorPinError.isNotEmpty ? _proktorPinError : null,
                  suffixIcon: IconButton(
                    icon: Icon(_proktorPinObscure
                        ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(
                            () => _proktorPinObscure = !_proktorPinObscure),
                  ),
                ),
                onSubmitted: (_) => _verifyProktorPin(),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextButton(
                  onPressed: () => setState(() {
                    _showProktorDialog = false;
                    _proktorPinCtrl.clear();
                    _proktorPinError = '';
                  }),
                  child: const Text("Batal"),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white),
                  onPressed: _proktorPinLoading ? null : _verifyProktorPin,
                  child: _proktorPinLoading
                      ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text("Masuk"),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Builder: pilihan ganda (dengan randomisasi opsi) ──
  List<Widget> _buildPG(SoalModel soal) {
    final indices = _shuffledOptionIndices[soal.id]
        ?? List.generate(soal.pilihan.length, (i) => i);
    final labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    return indices.map((origIdx) {
      final p = soal.pilihan[origIdx];
      final origKey = p.split('.').first.trim(); // original key like "A", "B"
      final displayLabel = labels[indices.indexOf(origIdx)]; // new display label
      final isSelected = _jawaban[soal.id] == origKey;
      return GestureDetector(
        onTap: () => setState(() => _jawaban[soal.id] = origKey),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor:
              isSelected ? Colors.blue : Colors.grey.shade100,
              child: Text(displayLabel,
                  style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildTextWithLatex(
                p.substring(p.indexOf('.') + 1).trim(), 14)),
          ]),
        ),
      );
    }).toList();
  }

  // ── Builder: benar/salah ──
  List<Widget> _buildBS(SoalModel soal) => ['BENAR', 'SALAH'].map((opt) {
    final isSelected = _jawaban[soal.id] == opt;
    return GestureDetector(
      onTap: () => setState(() => _jawaban[soal.id] = opt),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? (opt == 'BENAR' ? Colors.green.shade50 : Colors.red.shade50)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (opt == 'BENAR' ? Colors.green : Colors.red)
                : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(
            isSelected
                ? (opt == 'BENAR' ? Icons.check_circle : Icons.cancel)
                : Icons.radio_button_unchecked,
            color: isSelected
                ? (opt == 'BENAR' ? Colors.green : Colors.red)
                : Colors.grey,
          ),
          const SizedBox(width: 12),
          Text(opt, style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? (opt == 'BENAR' ? Colors.green : Colors.red)
                  : Colors.black87)),
        ]),
      ),
    );
  }).toList();

  // ── Builder: uraian ──
  List<Widget> _buildUraian(SoalModel soal) => [
    TextField(
      maxLines: 5,
      decoration: InputDecoration(
        hintText: "Tuliskan jawaban Anda di sini...",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true, fillColor: Colors.white,
      ),
      onChanged: (v) => _jawaban[soal.id] = v,
      controller: TextEditingController(text: _jawaban[soal.id] ?? ''),
    ),
    const SizedBox(height: 8),
    const Text("* Jawaban uraian akan dikoreksi manual oleh guru",
        style: TextStyle(color: Colors.grey, fontSize: 11,
            fontStyle: FontStyle.italic)),
  ];

  Widget _tipeBadge(TipeSoal tipe) {
    final label = tipe == TipeSoal.pilihanGanda ? "Pilihan Ganda"
        : tipe == TipeSoal.benarSalah ? "Benar / Salah" : "Uraian";
    final color = tipe == TipeSoal.pilihanGanda ? Colors.blue
        : tipe == TipeSoal.benarSalah ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }

  void _showSubmitDialog(int dijawab) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.teal),
          SizedBox(width: 8),
          Text("Kumpulkan Jawaban?"),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Soal dijawab: $dijawab dari ${_soals.length}"),
              if (dijawab < _soals.length)
                Text("${_soals.length - dijawab} soal belum dijawab!",
                    style: const TextStyle(color: Colors.orange, fontSize: 13)),
              const SizedBox(height: 8),
              const Text(
                  "Setelah dikumpulkan, Anda tidak bisa mengubah jawaban lagi."),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cek Lagi")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(context); _doSubmit(); },
            child: const Text("Ya, Kumpulkan"),
          ),
        ],
      ),
    );
  }
}

