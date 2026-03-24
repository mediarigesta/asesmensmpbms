part of '../main.dart';

// ============================================================
// GURU DASHBOARD — Portal Guru dengan filter mapelRoles
// ============================================================
class GuruDashboard extends StatefulWidget {
  final UserAccount guru;
  const GuruDashboard({super.key, required this.guru});
  @override
  State<GuruDashboard> createState() => _GuruDashboardState();
}

class _GuruDashboardState extends State<GuruDashboard> with IdleTimeoutMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _guruTab = 0;
  Set<String> _mapelRoles = {};
  bool _isAdmin = false;
  bool _loadingRoles = true;
  Set<int> _guruQuickActions = {1, 2, 3, 4, 5};
  // 3-col wide layout state
  int _sidebarIdx = 0;   // 0=Dashboard,1=Ujian,2=Rekap,3=Analitik,4=Jadwal
  String _subPage = '';  // 'penilaian','tambah','banksoal'
  String? _panelKelas;   // null=all, 'Kelas 7','Kelas 8','Kelas 9'
  int _flyoutIdx = -1;   // -1=none, 1=Ujian flyout
  int _ujianTab = 0;     // 0=saat ini,1=terjadwal,2=selesai,3=draft
  StreamSubscription? _rolesSub;

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _loadGuruQuickActions();
    startIdleWatcher();
  }

  @override
  void dispose() {
    _rolesSub?.cancel();
    stopIdleWatcher();
    super.dispose();
  }

  // Load roles & mapelRoles dari Firestore (real-time)
  void _loadRoles() async {
    _rolesSub = FirebaseFirestore.instance.collection('users').doc(widget.guru.id)
        .snapshots().listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final rawRoles = data['roles'];
      final rawMapel = data['mapelRoles'];
      setState(() {
        _isAdmin = rawRoles is List
            ? rawRoles.contains('admin1')
            : widget.guru.role == 'admin1';
        _mapelRoles = rawMapel is List
            ? Set<String>.from(rawMapel.map((e) => e.toString()))
            : {};
        _loadingRoles = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) => _buildNarrowLayout(context);

  Widget _buildNarrowLayout(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    backgroundColor: context.bm.surface,
    drawer: _buildGuruDrawer(),
    body: SafeArea(
      bottom: false,
      child: Column(children: [
      // PIN & Token bar (jika admin aktifkan)
      _buildGuruPinTokenBar(),
      // ── Header Besar ─────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [context.bm.primary, context.bm.gradient2],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          boxShadow: [BoxShadow(
            color: context.bm.primary.withValues(alpha: 0.25),
            blurRadius: 14, offset: const Offset(0, 6),
          )],
        ),
        child: Column(children: [
          // Baris atas: menu + nama sekolah + badge ujian + logout
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white70),
                onPressed: () => _scaffoldKey.currentState!.openDrawer(),
              ),
              const Icon(Icons.school_outlined, color: Colors.white38, size: 14),
              const SizedBox(width: 4),
              const Expanded(
                child: Text("SMP Budi Mulia",
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('EEE, dd MMM').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('exam').snapshots(),
                builder: (c, snap) {
                  if (!snap.hasData) return const SizedBox();
                  final all = snap.data!.docs.map((d) => ExamData.fromFirestore(d)).toList();
                  final aktif = (_isAdmin ? all : all.where((e) => _mapelRoles.contains(e.mapel)))
                      .where((e) => e.isOngoing).length;
                  if (aktif == 0) return const SizedBox();
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.white, size: 7),
                      const SizedBox(width: 3),
                      Text("$aktif Aktif", style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ]),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                tooltip: "Keluar",
                onPressed: () => _confirmLogout(context),
              ),
            ]),
          ),
          // Baris utama: greeting + nama besar + avatar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(_greetIcon(), color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text(_greetText(),
                      style: const TextStyle(color: Colors.white70, fontSize: 15)),
                ]),
                const SizedBox(height: 4),
                Text(widget.guru.nama,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24,
                        fontWeight: FontWeight.bold, height: 1.2),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                if (_loadingRoles)
                  const SizedBox(width: 80, height: 14,
                      child: LinearProgressIndicator(backgroundColor: Colors.white24))
                else
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    if (_isAdmin)
                      _headerBadge('Admin', Colors.purple, Icons.admin_panel_settings)
                    else if (_mapelRoles.isEmpty)
                      _headerBadge('Belum ada mapel', Colors.orange, Icons.warning)
                    else
                      ..._mapelRoles.map((m) => _headerBadge(m, Colors.teal, Icons.book)),
                  ]),
              ])),
              const SizedBox(width: 14),
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(widget.guru.initials,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 22)),
              ),
            ]),
          ),
        ]),
      ),

      // Notifikasi mengawas hari ini
      if (!_loadingRoles)
        _buildTodayMengawasNotif(),

      // Body
      if (_loadingRoles)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (!_isAdmin && _mapelRoles.isEmpty)
        Expanded(child: _noMapelWarning())
      else
        Expanded(child: GestureDetector(
          onTap: resetIdleTimer,
          onPanDown: (_) => resetIdleTimer(),
          behavior: HitTestBehavior.translucent,
          child: _buildTab(),
        )),
      ]),
      ),
  );

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

  /// Banner: jadwal mengawas guru hari ini
  Widget _buildTodayMengawasNotif() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('jadwal').doc('mengawas').get(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final rows = List<Map<String, dynamic>>.from(data['rows'] as List? ?? []);
        final guruNama = widget.guru.nama.toLowerCase();

        final List<Map<String, String>> duties = [];
        for (final row in rows) {
          final hari = row['hari']?.toString() ?? '';
          if (!_hariIsToday(hari)) continue;
          final pukul = row['pukul']?.toString() ?? '';
          row.forEach((key, value) {
            if (key.startsWith('ruang') &&
                value.toString().toLowerCase().contains(guruNama)) {
              duties.add({
                'ruang': 'Ruang ${key.replaceFirst('ruang', '')}',
                'pukul': pukul,
              });
            }
          });
        }
        if (duties.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.supervisor_account, color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Jadwal Mengawas Hari Ini',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.orange)),
                    const SizedBox(height: 4),
                    ...duties.map((d) => Text(
                          '• ${d['ruang']}  ·  Pukul ${d['pukul']}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF92400E)),
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

  /// Widget PIN + Token untuk guru (hanya jika admin mengaktifkan toggle)
  Widget _buildGuruPinTokenBar() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings').doc('app_config').snapshots(),
      builder: (c, settingSnap) {
        final data = settingSnap.hasData && settingSnap.data!.exists
            ? settingSnap.data!.data() as Map : <String, dynamic>{};
        final bolehLihat = data['guru_lihat_pin_token'] == true;
        if (!bolehLihat) return const SizedBox.shrink();

        final pin = data['proctor_password']?.toString() ?? '-';

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('settings').doc('exam_token').snapshots(),
          builder: (c2, tokenSnap) {
            String token = '------';
            if (tokenSnap.hasData && tokenSnap.data!.exists) {
              token = (tokenSnap.data!.data() as Map?)?['current_token']?.toString() ?? '------';
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.teal.shade700,
              child: Row(children: [
                const Icon(Icons.key, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text("PIN: $pin",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2)),
                const SizedBox(width: 24),
                const Icon(Icons.token, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text("Token: $token",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2)),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _headerBadge(String label, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24, width: 0.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: Colors.white),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _noMapelWarning() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.lock_outline, size: 60, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      const Text('Akses Dibatasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Akun Anda belum memiliki mata pelajaran yang ditentukan.\n'
              'Hubungi Admin untuk mendapatkan hak akses.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () => _confirmLogout(context),
        icon: const Icon(Icons.logout, size: 16),
        label: const Text('Keluar'),
      ),
    ],
  ));

  Widget _tabBtn(int idx, IconData icon, String label) => GestureDetector(
    onTap: () => setState(() => _guruTab = idx),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
          color: _guruTab == idx ? context.bm.primary : Colors.transparent,
          width: 2,
        )),
      ),
      child: Column(children: [
        Icon(icon, color: _guruTab == idx ? context.bm.primary : Colors.grey, size: 20),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
            fontSize: 10,
            color: _guruTab == idx ? context.bm.primary : Colors.grey,
            fontWeight: _guruTab == idx ? FontWeight.bold : FontWeight.normal)),
      ]),
    ),
  );

  Widget _buildTab() {
    switch (_guruTab) {
      case 1:  return ExamCreatorForm(allowedMapel: _isAdmin ? null : _mapelRoles);
      case 2:  return ExamHistoryList(filterMapel: _isAdmin ? null : _mapelRoles);
      case 3:  return RekapsNilaiScreen(filterMapel: _isAdmin ? null : _mapelRoles);
      case 4:  return AnalyticsScreen(filterMapel: _isAdmin ? null : _mapelRoles);
      case 5:  return JadwalScreen(role: _isAdmin ? 'admin1' : 'guru');
      case 6:  return BankSoalScreen(filterMapel: _isAdmin ? null : _mapelRoles);
      case 7:  return RemedialTrackingScreen(filterMapel: _isAdmin ? null : _mapelRoles);
      case 10: return LayoutBuilder(builder: (ctx, cst) {
        if (cst.maxWidth >= 600) {
          return Row(children: [_buildKelasPanel(), Expanded(child: _buildPenilaianView())]);
        }
        // Mobile: chip bar on top
        final kelasAll = [null,'7A','7B','7C','7D','8A','8B','8C','8D','9A','9B','9C','9D'];
        return Column(children: [
          Container(
            height: 44, color: context.bm.surface,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: kelasAll.map((c) {
                final isActive = _panelKelas == c;
                return GestureDetector(
                  onTap: () => setState(() => _panelKelas = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? context.bm.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(c ?? 'Semua', style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade700,
                      fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    )),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(child: _buildPenilaianView()),
        ]);
      });
      default: return _berandaGuru();
    }
  }

  // ── Greeting helpers ──────────────────────────────────────────
  String _greetText() {
    final h = DateTime.now().hour;
    if (h < 11) return "Selamat Pagi";
    if (h < 15) return "Selamat Siang";
    if (h < 18) return "Selamat Sore";
    return "Selamat Malam";
  }

  IconData _greetIcon() {
    final h = DateTime.now().hour;
    if (h < 11) return Icons.wb_sunny;
    if (h < 15) return Icons.wb_sunny_outlined;
    if (h < 18) return Icons.wb_twilight;
    return Icons.nightlight_round;
  }

  // ── Quick Actions SharedPreferences ───────────────────────────
  Future<void> _loadGuruQuickActions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('guru_quick_actions');
    if (saved != null && mounted) {
      setState(() => _guruQuickActions = saved.map(int.parse).toSet());
    }
  }

  Future<void> _saveGuruQuickActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('guru_quick_actions',
        _guruQuickActions.map((e) => e.toString()).toList());
  }

  List<Map<String, dynamic>> get _quickActionItems => [
    {'label': 'Buat Ujian',  'icon': Icons.add_circle_outline,    'tab': 1, 'color': const Color(0xFF1E88E5)},
    {'label': 'History',     'icon': Icons.history_edu,            'tab': 2, 'color': const Color(0xFF7B1FA2)},
    {'label': 'Bank Soal',   'icon': Icons.library_books_outlined, 'tab': 6, 'color': const Color(0xFF6D4C41)},
    {'label': 'Rekap Nilai', 'icon': Icons.grading,                'tab': 3, 'color': const Color(0xFF00897B)},
    {'label': 'Analitik',    'icon': Icons.bar_chart_outlined,     'tab': 4, 'color': const Color(0xFFF4511E)},
    {'label': 'Jadwal',      'icon': Icons.calendar_month_outlined,'tab': 5, 'color': const Color(0xFF039BE5)},
    {'label': 'Remedial',    'icon': Icons.healing_outlined,       'tab': 7, 'color': const Color(0xFFE65100)},
    {'label': 'Profil',      'icon': Icons.person_outline,         'tab': -1,'color': const Color(0xFF546E7A)},
  ];

  Future<void> _showGuruQuickActionsDialog() async {
    final tmp = Set<int>.from(_guruQuickActions);
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Pilih Akses Cepat"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ..._quickActionItems.map((qa) {
              final tab = qa['tab'] as int;
              return CheckboxListTile(
                value: tmp.contains(tab),
                onChanged: (v) => setLocal(() => v! ? tmp.add(tab) : tmp.remove(tab)),
                title: Row(children: [
                  Icon(qa['icon'] as IconData, color: qa['color'] as Color, size: 18),
                  const SizedBox(width: 8),
                  Text(qa['label'] as String),
                ]),
                dense: true,
                controlAffinity: ListTileControlAffinity.trailing,
              );
            }),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                setState(() => _guruQuickActions = tmp);
                _saveGuruQuickActions();
                Navigator.pop(ctx);
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final items = _quickActionItems
        .where((qa) => _guruQuickActions.contains(qa['tab'] as int))
        .toList();
    if (items.isEmpty) return const SizedBox();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((qa) {
        final color = qa['color'] as Color;
        return GestureDetector(
          onTap: () {
            final tab = qa['tab'] as int;
            if (tab == -1) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfilePage(user: widget.guru, canEdit: false)));
            } else {
              setState(() => _guruTab = tab);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(qa['icon'] as IconData, color: color, size: 16),
              const SizedBox(width: 6),
              Text(qa['label'] as String,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Kelas Selesai Notification ─────────────────────────────────
  Widget _buildKelasSelesaiNotif(List<UserAccount> allUsers) {
    final siswa = allUsers.where((u) => u.role == 'siswa').toList();
    if (siswa.isEmpty) return const SizedBox();
    final Map<String, List<UserAccount>> byKelas = {};
    for (final s in siswa) {
      final k = s.classFolder;
      if (k.isEmpty) continue;
      byKelas.putIfAbsent(k, () => []).add(s);
    }
    final List<Widget> cards = [];
    final sortedKelas = byKelas.keys.toList()..sort();
    for (final kelas in sortedKelas) {
      final students = byKelas[kelas]!;
      if (students.isEmpty) continue;
      final selesai = students.where((s) => s.statusMengerjakan == 'selesai').length;
      final mengerjakan = students.where((s) => s.statusMengerjakan == 'mengerjakan').length;
      if (selesai == students.length && selesai > 0) {
        cards.add(_kelasSelesaiCard(kelas, selesai, students.length));
      } else if (mengerjakan > 0 || selesai > 0) {
        cards.add(_kelasProgressCard(kelas, selesai, students.length));
      }
    }
    if (cards.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Status Per Kelas",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      ...cards,
      const SizedBox(height: 4),
    ]);
  }

  Widget _kelasSelesaiCard(String kelas, int count, int total) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      border: Border.all(color: Colors.green.shade300),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      const Icon(Icons.check_circle, color: Colors.green, size: 22),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Kelas $kelas — Semua Selesai!",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
        Text("$count/$total siswa telah submit",
            style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
        child: const Text("100%",
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    ]),
  );

  Widget _kelasProgressCard(String kelas, int selesai, int total) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      border: Border.all(color: Colors.blue.shade200),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.pending_outlined, color: Colors.blue, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text("Kelas $kelas",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Text("$selesai/$total",
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: selesai / total,
          minHeight: 6,
          backgroundColor: Colors.blue.shade100,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ),
    ]),
  );

  // ── Activity Feed ─────────────────────────────────────────────
  Widget _buildActivityFeed(List<UserAccount> siswa) {
    final selesai = siswa.where((s) => s.statusMengerjakan == 'selesai').toList();
    final melanggar = siswa.where((s) => s.statusMengerjakan == 'melanggar').toList();
    if (selesai.isEmpty && melanggar.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long_outlined, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text("Aktivitas Siswa",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          if (selesai.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
              child: Text("${selesai.length} submit",
                  style: TextStyle(color: Colors.green.shade700, fontSize: 11)),
            ),
        ]),
        const SizedBox(height: 10),
        if (melanggar.isNotEmpty) ...[
          ...melanggar.take(3).map((s) => _activityRow(s, Colors.red, Icons.warning_amber, "Melanggar")),
        ],
        if (selesai.isNotEmpty) ...[
          ...selesai.take(5).map((s) => _activityRow(s, Colors.green, Icons.check_circle_outline, "Submit")),
        ],
        if (selesai.length + melanggar.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text("+${selesai.length + melanggar.length - 8} lainnya",
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ),
      ]),
    );
  }

  Widget _activityRow(UserAccount s, Color c, IconData icon, String label) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: c.withValues(alpha: 0.1),
              child: Text(s.initials,
                  style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.nama,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
            Text("Kelas ${s.classFolder}",
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 10, color: c),
              const SizedBox(width: 3),
              Text(label, style: TextStyle(color: c, fontSize: 10)),
            ]),
          ),
        ]),
      );

  // ── Mini stat card untuk Beranda ─────────────────────────────
  Widget _miniStatCard(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 9, color: Colors.grey),
                textAlign: TextAlign.center),
          ]),
        ),
      );

  // ── Halaman Beranda Guru ──────────────────────────────────────
  Widget _berandaGuru() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (ctx, uSnap) {
        final allUsers = uSnap.hasData
            ? uSnap.data!.docs.map((d) => UserAccount.fromFirestore(d)).toList()
            : <UserAccount>[];
        final siswa = allUsers.where((u) => u.role == 'siswa').toList();
        final mengerjakan = siswa.where((s) => s.statusMengerjakan == 'mengerjakan').length;
        final selesaiCount = siswa.where((s) => s.statusMengerjakan == 'selesai').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ─ Akses Cepat ─────────────────────────────────────
            Row(children: [
              const Expanded(child: Text("Akses Cepat",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              GestureDetector(
                onTap: _showGuruQuickActionsDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.tune_outlined, size: 13, color: Colors.grey),
                    SizedBox(width: 4),
                    Text("Pilih", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _buildQuickActionsGrid(),
            const SizedBox(height: 20),

            // ─ Mini Stats ──────────────────────────────────────
            Row(children: [
              _miniStatCard("Total Siswa", siswa.length.toString(), Icons.groups, Colors.blue),
              const SizedBox(width: 8),
              _miniStatCard("Sedang Ujian", mengerjakan.toString(), Icons.edit_note, Colors.indigo),
              const SizedBox(width: 8),
              _miniStatCard("Selesai", selesaiCount.toString(), Icons.check_circle_outline, Colors.green),
            ]),
            const SizedBox(height: 20),

            // ─ Status Per Kelas ────────────────────────────────
            _buildKelasSelesaiNotif(allUsers),
            const SizedBox(height: 4),

            // ─ Ujian Berlangsung ───────────────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('exam').snapshots(),
              builder: (c, examSnap) {
                if (!examSnap.hasData) return const SizedBox();
                final aktif = examSnap.data!.docs
                    .map((d) => ExamData.fromFirestore(d))
                    .where((e) =>
                        (_isAdmin ? true : _mapelRoles.contains(e.mapel)) && e.isOngoing)
                    .toList();
                if (aktif.isEmpty) return const SizedBox();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Ujian Berlangsung",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ...aktif.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      const Icon(Icons.live_tv, color: Colors.white70, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.judul,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text("${e.mapel}  •  ${e.jenjang}  •  Selesai ${DateFormat('HH:mm').format(e.waktuSelesai)}",
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.fiber_manual_record, color: Colors.white, size: 7),
                          SizedBox(width: 3),
                          Text("LIVE",
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ]),
                  )),
                  const SizedBox(height: 12),
                ]);
              },
            ),

            // ─ Aktivitas ──────────────────────────────────────
            if (siswa.isNotEmpty) _buildActivityFeed(siswa),
          ]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WIDE LAYOUT (≥1024px): 3-column icon sidebar + panel + content
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWideLayout(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bm.surface,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            resetIdleTimer();
            if (_flyoutIdx >= 0) setState(() => _flyoutIdx = -1);
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(children: [
            Row(children: [
              _buildGuruIconSidebar(),
              if (_sidebarIdx == 1 && _subPage == 'penilaian')
                _buildKelasPanel(),
              Expanded(
                child: _loadingRoles
                    ? const Center(child: CircularProgressIndicator())
                    : _buildGuruWideContent(),
              ),
            ]),
            if (_flyoutIdx >= 0) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _flyoutIdx = -1),
                  child: Container(color: Colors.transparent),
                ),
              ),
              _buildGuruFlyout(),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildGuruIconSidebar() {
    final items = [
      {'idx': 0, 'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'flyout': false},
      {'idx': 1, 'icon': Icons.quiz_outlined, 'label': 'Ujian', 'flyout': true},
      {'idx': 2, 'icon': Icons.grading_outlined, 'label': 'Rekap', 'flyout': false},
      {'idx': 3, 'icon': Icons.bar_chart_outlined, 'label': 'Analitik', 'flyout': false},
      {'idx': 4, 'icon': Icons.calendar_month_outlined, 'label': 'Jadwal', 'flyout': false},
    ];
    return Container(
      width: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.bm.primary, context.bm.gradient2],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Image.asset('assets/logo.png', width: 34, height: 34),
        const SizedBox(height: 8),
        Container(height: 1, color: Colors.white12),
        const SizedBox(height: 6),
        ...items.map((item) {
          final idx = item['idx'] as int;
          final isActive = _sidebarIdx == idx;
          final hasFlyout = item['flyout'] as bool;
          return GestureDetector(
            onTap: () {
              if (hasFlyout) {
                setState(() => _flyoutIdx = _flyoutIdx == idx ? -1 : idx);
              } else {
                setState(() {
                  _sidebarIdx = idx;
                  _subPage = '';
                  _flyoutIdx = -1;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Stack(clipBehavior: Clip.none, children: [
                  Icon(item['icon'] as IconData,
                      color: isActive ? Colors.white : Colors.white60, size: 22),
                  if (hasFlyout)
                    Positioned(
                      right: -8, bottom: -2,
                      child: Icon(Icons.chevron_right,
                          color: Colors.white38, size: 11),
                    ),
                ]),
                const SizedBox(height: 3),
                Text(item['label'] as String,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white60,
                      fontSize: 9,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center),
              ]),
            ),
          );
        }),
        const Spacer(),
        // PIN/Token indicator
        _buildGuruPinTokenBar(),
        // Profil + Logout
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProfilePage(user: widget.guru, canEdit: false))),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Text(widget.guru.initials,
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white54, size: 18),
          onPressed: () => _confirmLogout(context),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildGuruFlyout() {
    final flyItems = [
      {'label': 'Penilaian', 'icon': Icons.list_alt_outlined, 'sub': 'penilaian'},
      {'label': 'Tambah Ujian', 'icon': Icons.add_circle_outline, 'sub': 'tambah'},
      {'label': 'Bank Soal', 'icon': Icons.library_books_outlined, 'sub': 'banksoal'},
    ];
    return Positioned(
      left: 72,
      top: 100,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 190,
          decoration: BoxDecoration(
            color: context.bm.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(4, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: flyItems.map((item) {
              final isActive = _subPage == item['sub'] as String;
              return ListTile(
                dense: true,
                leading: Icon(item['icon'] as IconData,
                    size: 18,
                    color: isActive ? context.bm.primary : Colors.grey.shade500),
                title: Text(item['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? context.bm.primary : Colors.grey.shade800,
                    )),
                tileColor: isActive
                    ? context.bm.primary.withValues(alpha: 0.08)
                    : null,
                onTap: () {
                  setState(() {
                    _sidebarIdx = 1;
                    _subPage = item['sub'] as String;
                    _flyoutIdx = -1;
                    if (_subPage == 'penilaian') _panelKelas = null;
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildKelasPanel() {
    final jenjangList = <Map<String, dynamic>>[
      {'label': 'Semua Kelas', 'value': null},
      {'label': '— Kelas 7 —', 'value': '__sep7__'},
      {'label': '7A', 'value': '7A'}, {'label': '7B', 'value': '7B'},
      {'label': '7C', 'value': '7C'}, {'label': '7D', 'value': '7D'},
      {'label': '— Kelas 8 —', 'value': '__sep8__'},
      {'label': '8A', 'value': '8A'}, {'label': '8B', 'value': '8B'},
      {'label': '8C', 'value': '8C'}, {'label': '8D', 'value': '8D'},
      {'label': '— Kelas 9 —', 'value': '__sep9__'},
      {'label': '9A', 'value': '9A'}, {'label': '9B', 'value': '9B'},
      {'label': '9C', 'value': '9C'}, {'label': '9D', 'value': '9D'},
    ];
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: context.bm.surface,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.quiz_outlined, size: 16, color: context.bm.primary),
            const SizedBox(width: 8),
            Text('Penilaian',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey.shade800)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: jenjangList.map((j) {
              final val = j['value'] as String?;
              final isSep = val != null && val.startsWith('__sep');
              if (isSep) return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Text(j['label'] as String,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              );
              final isSelected = _panelKelas == val;
              return InkWell(
                onTap: () => setState(() => _panelKelas = val),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.bm.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: isSelected
                        ? Border(
                            left: BorderSide(
                                color: context.bm.primary, width: 3))
                        : null,
                  ),
                  child: Text(j['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? context.bm.primary
                            : Colors.grey.shade800,
                      )),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildGuruWideContent() {
    switch (_sidebarIdx) {
      case 1:
        switch (_subPage) {
          case 'tambah':
            return ExamCreatorForm(
                allowedMapel: _isAdmin ? null : _mapelRoles);
          case 'banksoal':
            return BankSoalScreen(
                filterMapel: _isAdmin ? null : _mapelRoles);
          default:
            return _buildPenilaianView();
        }
      case 2:
        return RekapsNilaiScreen(
            filterMapel: _isAdmin ? null : _mapelRoles);
      case 3:
        return AnalyticsScreen(
            filterMapel: _isAdmin ? null : _mapelRoles);
      case 4:
        return JadwalScreen(role: _isAdmin ? 'admin1' : 'guru');
      default:
        return _berandaGuru();
    }
  }

  Widget _buildPenilaianView() {
    final tabLabels = ['Saat Ini', 'Terjadwal', 'Selesai', 'Draft'];
    final tabColors = [Colors.green, Colors.blue, Colors.grey, Colors.orange];
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        color: context.bm.surface,
        child: Row(children: [
          Expanded(
            child: Text(
              _panelKelas != null ? 'Penilaian — ' + _panelKelas! : 'Semua Penilaian',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.bm.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() => _guruTab = 1),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah Ujian',
                style: TextStyle(fontSize: 13)),
          ),
        ]),
      ),
      // Tab bar
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        color: context.bm.surface,
        child: Row(
          children: List.generate(tabLabels.length, (i) {
            final isActive = _ujianTab == i;
            return GestureDetector(
              onTap: () => setState(() => _ujianTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? tabColors[i].withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? tabColors[i]
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(tabLabels[i],
                    style: TextStyle(
                      color:
                          isActive ? tabColors[i] : Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    )),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 4),
      const Divider(height: 1),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('exam')
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data!.docs
                .map((d) => ExamData.fromFirestore(d))
                .toList();
            final filtered = all.where((e) {
              if (!_isAdmin && !_mapelRoles.contains(e.mapel)) {
                return false;
              }
              if (_panelKelas != null) {
                if (e.targetKelas.isNotEmpty) {
                  if (!e.targetKelas.contains(_panelKelas)) return false;
                } else {
                  if (!e.jenjang.contains(_panelKelas![0])) return false;
                }
              }
              switch (_ujianTab) {
                case 0:
                  return e.isOngoing && !e.isDraft;
                case 1:
                  return e.belumMulai && !e.isDraft;
                case 2:
                  return e.sudahSelesai && !e.isDraft;
                case 3:
                  return e.isDraft;
                default:
                  return !e.isDraft;
              }
            }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 56,
                          color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Tidak ada ujian',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14)),
                    ]),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => ExamHistoryScreen(exam: filtered[i]))),
                child: _examCardWide(filtered[i]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _examCardWide(ExamData e) {
    final isDraft = e.isDraft;
    final isOngoing = e.isOngoing && !isDraft;
    final isSelesai = e.sudahSelesai && !isDraft;
    final Color statusColor = isDraft
        ? Colors.orange
        : isOngoing ? Colors.green : isSelesai ? Colors.grey : Colors.blue;
    final String statusLabel = isDraft
        ? 'Draft'
        : isOngoing ? 'Berlangsung' : isSelesai ? 'Selesai' : 'Terjadwal';
    final bool isNativeMode = e.mode == 'native';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.quiz_outlined, color: statusColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(e.mapel + '  •  ' + e.jenjang, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ])),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          if (isDraft) ...[
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.publish_outlined, size: 18), tooltip: 'Terbitkan', onPressed: () async {
              await FirebaseFirestore.instance.collection('exam').doc(e.id).update({'status': 'published'});
            }),
          ],
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (e.spiType == 'remedial') _examBadge('Remedial', Colors.deepOrange.shade50, Colors.deepOrange),
          if (e.spiType == 'susulan') _examBadge('Susulan', Colors.indigo.shade50, Colors.indigo),
          if (e.kkm > 0) _examBadge('KKM ${e.kkm}', Colors.teal.shade50, Colors.teal),
          if (e.kategori.isNotEmpty) _examBadge(e.kategori, Colors.purple.shade100, Colors.purple.shade700),
          _examBadge(isNativeMode ? 'Via Aplikasi' : 'Via Google Form', Colors.blue.shade50, Colors.blue.shade600),
          if (!isDraft) _examBadge(DateFormat('dd MMM, HH:mm').format(e.waktuMulai) + ' — ' + DateFormat('HH:mm').format(e.waktuSelesai), Colors.grey.shade100, Colors.grey.shade600),
        ]),
        if (e.creatorName.isNotEmpty || e.createdAt != null) ...[
          const SizedBox(height: 6),
          DefaultTextStyle(
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
            child: Row(children: [
              if (e.creatorName.isNotEmpty) ...[
                const Icon(Icons.person_outline, size: 11, color: Colors.grey),
                const SizedBox(width: 3),
                Text(e.creatorName),
                const SizedBox(width: 10),
              ],
              if (e.createdAt != null) ...[
                const Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey),
                const SizedBox(width: 3),
                Text('Diterbitkan ' + DateFormat('dd MMM yyyy').format(e.createdAt!)),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _examBadge(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w600)),
  );

  Widget _drawerSub(IconData icon, String label, bool selected, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 52, right: 16),
      leading: Icon(icon, size: 18, color: selected ? context.bm.primary : Colors.grey.shade600),
      title: Text(label, style: TextStyle(
        fontSize: 13,
        color: selected ? context.bm.primary : Colors.grey.shade800,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      )),
      selected: selected,
      selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }

  Widget _buildGuruSideBar() {
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
              GestureDetector(
                onTap: () => setState(() => _guruTab = 0),
                child: Image.asset('assets/logo.png', width: 48, height: 48),
              ),
              const SizedBox(height: 10),
              Text(widget.guru.nama,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Text(_isAdmin ? 'Admin & Guru' : 'Guru',
                    style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              ListTile(
                leading: Image.asset('assets/logo.png', width: 20, height: 20),
                title: const Text('Dashboard', style: TextStyle(fontSize: 13)),
                selected: _guruTab == 0,
                selectedColor: context.bm.primary,
                selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
                onTap: () => setState(() => _guruTab = 0),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_outline, size: 20),
                title: const Text('Profil Saya', style: TextStyle(fontSize: 13)),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfilePage(user: widget.guru, canEdit: false),
                )),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add_circle_outline, size: 20),
                title: const Text('Buat Ujian', style: TextStyle(fontSize: 13)),
                selected: _guruTab == 1,
                selectedColor: context.bm.primary,
                selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
                onTap: () => setState(() => _guruTab = 1),
              ),
              ListTile(
                leading: const Icon(Icons.history_edu, size: 20),
                title: const Text('History Ujian', style: TextStyle(fontSize: 13)),
                selected: _guruTab == 2,
                selectedColor: context.bm.primary,
                selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
                onTap: () => setState(() => _guruTab = 2),
              ),
              ListTile(
                leading: const Icon(Icons.grading, size: 20),
                title: const Text('Rekap Nilai', style: TextStyle(fontSize: 13)),
                selected: _guruTab == 3,
                selectedColor: context.bm.primary,
                selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
                onTap: () => setState(() => _guruTab = 3),
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart_outlined, size: 20),
                title: const Text('Analitik', style: TextStyle(fontSize: 13)),
                selected: _guruTab == 4,
                selectedColor: context.bm.primary,
                selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
                onTap: () => setState(() => _guruTab = 4),
              ),
              ListTile(
                leading: const Icon(Icons.library_books_outlined, size: 20),
                title: const Text('Bank Soal', style: TextStyle(fontSize: 13)),
                selected: _guruTab == 6,
                selectedColor: context.bm.primary,
                selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
                onTap: () => setState(() => _guruTab = 6),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined, size: 20),
                title: const Text('Jadwal', style: TextStyle(fontSize: 13)),
                selected: _guruTab == 5,
                selectedColor: context.bm.primary,
                selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
                onTap: () => setState(() => _guruTab = 5),
              ),
              ListTile(
                leading: const Icon(Icons.healing_outlined, size: 20),
                title: const Text('Tracking Remedial', style: TextStyle(fontSize: 13)),
                selected: _guruTab == 7,
                selectedColor: context.bm.primary,
                selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
                onTap: () => setState(() => _guruTab = 7),
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

  Widget _buildGuruDrawer() {
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
              onTap: () {
                Navigator.pop(context);
                setState(() => _guruTab = 0);
              },
              child: Image.asset('assets/logo.png', width: 56, height: 56),
            ),
            const SizedBox(height: 12),
            Text(widget.guru.nama,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Text(_isAdmin ? 'Admin & Guru' : 'Guru',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ]),
        ),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            ListTile(
              leading: Image.asset('assets/logo.png', width: 22, height: 22),
              title: const Text('Dashboard'),
              selected: _guruTab == 0,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 0); },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil Saya'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfilePage(user: widget.guru, canEdit: false),
                ));
              },
            ),
            const Divider(height: 1),
            ExpansionTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Ujian'),
              initiallyExpanded: _guruTab == 1 || _guruTab == 2 || _guruTab == 10,
              iconColor: context.bm.primary,
              collapsedIconColor: Colors.grey,
              childrenPadding: EdgeInsets.zero,
              children: [
                _drawerSub(Icons.fact_check_outlined, 'Penilaian', _guruTab == 10,
                    () { Navigator.pop(context); setState(() => _guruTab = 10); }),
                _drawerSub(Icons.add_circle_outline, 'Buat Ujian', _guruTab == 1,
                    () { Navigator.pop(context); setState(() => _guruTab = 1); }),
                _drawerSub(Icons.history_edu, 'History Ujian', _guruTab == 2,
                    () { Navigator.pop(context); setState(() => _guruTab = 2); }),
                _drawerSub(Icons.library_books_outlined, 'Bank Soal', _guruTab == 6,
                    () { Navigator.pop(context); setState(() => _guruTab = 6); }),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.grading),
              title: const Text('Rekap Nilai'),
              selected: _guruTab == 3,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 3); },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Analitik'),
              selected: _guruTab == 4,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 4); },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Jadwal'),
              selected: _guruTab == 5,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 5); },
            ),
            ListTile(
              leading: const Icon(Icons.healing_outlined),
              title: const Text('Tracking Remedial'),
              selected: _guruTab == 7,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 7); },
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
}

