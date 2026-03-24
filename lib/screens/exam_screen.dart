part of '../main.dart';

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
  Timer? _autoSubmitTimer;
  StreamSubscription? _broadcastSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initExam();

    // Inisialisasi WebView hanya di Android
    if (isAndroid) {
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

    // Kamera hanya digunakan untuk preview di layar siswa

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
    _broadcastSub = FirebaseFirestore.instance
        .collection('settings')
        .doc('broadcast')
        .snapshots()
        .listen((s) {
      if (!mounted || !s.exists) return;
      final d = s.data() as Map?;
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
        ));
      }
    });
  }

  void _initExam() async {
    if (widget.exam.antiCurang) {
      if (isAndroid) {
        try {
          await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          await KioskService.start();
        } catch (e) {
          debugPrint('Lock screen error: $e');
        }
      } else if (!kIsWeb && Platform.isIOS) {
        // iOS: Guided Access sudah aktif (dicek sebelum masuk)
        try {
          await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } catch (_) {}
      } else if (kIsWeb) {
        // Daftarkan callback pelanggaran dari kiosk.js
        KioskService.registerWebCallbacks(
          onViolation: (count, max, reason) {
            if (!mounted || _submitted) return;
            setState(() => _curang = count);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('⚠️ Peringatan $count dari $max — Jangan keluar halaman ujian!'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ));
            // Catat jumlah pelanggaran & alasan untuk ujian ini (status ditandai melanggar sejak pelanggaran pertama)
            updateExamStatusForUser(
              exam: widget.exam,
              user: widget.user,
              status: 'melanggar',
              violationCount: count,
              extraFields: {
                'exam_status.${widget.exam.id}.lastViolationReason': reason ?? 'web_violation',
              },
            );
          },
          onAutoSubmit: (reason) {
            if (_submitted) return;
            // Update status melanggar lalu submit (khusus ujian ini)
            updateExamStatusForUser(
              exam: widget.exam,
              user: widget.user,
              status: 'melanggar',
              violationCount: _curang,
              extraFields: {
                'exam_status.${widget.exam.id}.lastViolationReason': reason ?? 'web_max_violation',
              },
            );
            _doSubmit(reason: 'max_violation');
          },
        );
        // Aktifkan kiosk web
        await KioskService.start(
          maxCurang: widget.exam.maxCurang,
          examTitle: widget.exam.judul,
        );
      }
    }
    await updateExamStatusForUser(
      exam: widget.exam,
      user: widget.user,
      status: 'mengerjakan',
    );
  }

  void _doSubmit({String reason = "manual"}) async {
    if (_submitted) return;
    _submitted = true;
    _autoSubmitTimer?.cancel();

    if (isAndroid) {
      await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      try { SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); } catch (_) {}
      try { await KioskService.stop(); } catch (_) {}
    } else if (kIsWeb) {
      try { await KioskService.stop(); } catch (_) {}
    }
    await updateExamStatusForUser(
      exam: widget.exam,
      user: widget.user,
      status: 'selesai',
    );

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
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_submitted || !widget.exam.antiCurang) return;
    if (state == AppLifecycleState.paused) {
      _curang++;
      if (_curang >= widget.exam.maxCurang) {
        // Kunci aplikasi
        await updateExamStatusForUser(
          exam: widget.exam,
          user: widget.user,
          status: 'melanggar',
          violationCount: _curang,
        );
        if (mounted) {
              Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => LockScreen(user: widget.user, exam: widget.exam)));
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
    if (state == AppLifecycleState.resumed) {
      if (isAndroid) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          await KioskService.start();
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
                  "Kamu keluar dari mode ujian.\n\nTekan tombol di bawah untuk mengunci kembali perangkat.\n\nPelanggaran ini telah dicatat.",
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
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSubmitTimer?.cancel();
    _broadcastSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: Stack(children: [
        // WebView atau tombol buka link (web)
        // WebView hanya di Android; Web dan Windows buka link di browser
        (kIsWeb || isWindows)
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

        // Kamera preview (selalu tampil di Android jika kamera tersedia)
        if (hasMobileFeatures && widget.cam != null)
          Positioned(
            bottom: 16,
            right: 16,
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
                Container(
                  width: 95,
                  height: 122,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                      topLeft: Radius.circular(8),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                      topLeft: Radius.circular(6),
                    ),
                    child: CameraPreview(widget.cam!),
                  ),
                ),
                const SizedBox(height: 3),
                const Text("Kamu sedang diawasi",
                    style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.w600)),
              ],
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

