// patch_dashboard_v1.js — Dashboard Enhancement
// Changes:
// 1. GuruDashboard: bigger header + Beranda tab + quick actions + class completion + activity feed
// 2. Admin1Dashboard: bigger header + quick actions in stats + class completion + activity feed
// 3. HomeScreen: bigger greeting header

const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, 'lib', 'main.dart');
let src = fs.readFileSync(FILE, 'utf8');

function replace(oldStr, newStr, label) {
  if (!src.includes(oldStr)) {
    console.error('❌ NOT FOUND: ' + label);
    process.exit(1);
  }
  src = src.replace(oldStr, newStr);
  console.log('✅ ' + label);
}

// ══════════════════════════════════════════════════════════════════
// 1. GuruDashboard state: tambah _guruQuickActions + greeting methods
// ══════════════════════════════════════════════════════════════════
replace(
  `  int _guruTab = 0;
  Set<String> _mapelRoles = {};
  bool _isAdmin = false;
  bool _loadingRoles = true;`,
  `  int _guruTab = 0;
  Set<String> _mapelRoles = {};
  bool _isAdmin = false;
  bool _loadingRoles = true;
  Set<int> _guruQuickActions = {1, 2, 3, 4, 5};`,
  'GuruDashboard: tambah state _guruQuickActions'
);

// ══════════════════════════════════════════════════════════════════
// 2. GuruDashboard initState: load quick actions
// ══════════════════════════════════════════════════════════════════
replace(
  `    super.initState();
    _loadRoles();
    startIdleWatcher();
  }

  @override
  void dispose() {
    stopIdleWatcher();
    super.dispose();
  }

  // Load roles & mapelRoles dari Firestore (real-time)`,
  `    super.initState();
    _loadRoles();
    _loadGuruQuickActions();
    startIdleWatcher();
  }

  @override
  void dispose() {
    stopIdleWatcher();
    super.dispose();
  }

  // Load roles & mapelRoles dari Firestore (real-time)`,
  'GuruDashboard: tambah _loadGuruQuickActions di initState'
);

// ══════════════════════════════════════════════════════════════════
// 3. GuruDashboard: Replace header + tab bar
// ══════════════════════════════════════════════════════════════════
replace(
  `      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(4, 12, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [context.bm.primary, context.bm.gradient2],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF60A5FA)),
            tooltip: "Menu",
            onPressed: () => _scaffoldKey.currentState!.openDrawer(),
          ),
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white24,
            child: Text(widget.guru.initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isAdmin ? "Portal Admin & Guru" : "Portal Guru",
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              Text(widget.guru.nama,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              // Mapel badges
              if (_loadingRoles)
                const SizedBox(width: 60, height: 14,
                    child: LinearProgressIndicator(backgroundColor: Colors.white24))
              else
                Wrap(spacing: 5, children: [
                  if (_isAdmin)
                    _headerBadge('Admin', Colors.purple, Icons.admin_panel_settings)
                  else if (_mapelRoles.isEmpty)
                    _headerBadge('Belum ada mapel — hubungi Admin', Colors.orange, Icons.warning)
                  else
                    ..._mapelRoles.map((m) => _headerBadge(m, Colors.teal, Icons.book)),
                ]),
            ]),
          ),
          // Badge ujian aktif
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('exam').snapshots(),
            builder: (c, snap) {
              if (!snap.hasData) return const SizedBox();
              final all = snap.data!.docs.map((d) => ExamData.fromFirestore(d)).toList();
              final aktif = (_isAdmin ? all : all.where(
                      (e) => _mapelRoles.contains(e.mapel)))
                  .where((e) => e.isOngoing).length;
              if (aktif == 0) return const SizedBox();
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                  const SizedBox(width: 4),
                  Text("\\$aktif Aktif", style: const TextStyle(color: Colors.white, fontSize: 11)),
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

      // Tab bar
      Container(
        color: Colors.white,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            _tabBtn(0, Icons.add_circle_outline, "Buat Ujian"),
            _tabBtn(1, Icons.history_edu, "History"),
            _tabBtn(2, Icons.grading, "Rekap Nilai"),
            _tabBtn(3, Icons.bar_chart_outlined, "Analitik"),
            _tabBtn(4, Icons.calendar_month_outlined, "Jadwal"),
          ]),
        ),
      ),`,
  `      // ── Header Besar ─────────────────────────────────────
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
                      Text("\$aktif Aktif", style: const TextStyle(color: Colors.white, fontSize: 10)),
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

      // Tab bar
      Container(
        color: context.bm.surface,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            _tabBtn(0, Icons.home_outlined, "Beranda"),
            _tabBtn(1, Icons.add_circle_outline, "Buat Ujian"),
            _tabBtn(2, Icons.history_edu, "History"),
            _tabBtn(3, Icons.grading, "Rekap Nilai"),
            _tabBtn(4, Icons.bar_chart_outlined, "Analitik"),
            _tabBtn(5, Icons.calendar_month_outlined, "Jadwal"),
          ]),
        ),
      ),`,
  'GuruDashboard: header besar + tab Beranda'
);

// ══════════════════════════════════════════════════════════════════
// 4. GuruDashboard drawer: fix tab indices
// ══════════════════════════════════════════════════════════════════
replace(
  `            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Buat Ujian'),
              selected: _guruTab == 0,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 0); },
            ),
            ListTile(
              leading: const Icon(Icons.history_edu),
              title: const Text('History Ujian'),
              selected: _guruTab == 1,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 1); },
            ),
            ListTile(
              leading: const Icon(Icons.grading),
              title: const Text('Rekap Nilai'),
              selected: _guruTab == 2,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 2); },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Analitik'),
              selected: _guruTab == 3,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 3); },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Jadwal'),
              selected: _guruTab == 4,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 4); },
            ),`,
  `            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Buat Ujian'),
              selected: _guruTab == 1,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 1); },
            ),
            ListTile(
              leading: const Icon(Icons.history_edu),
              title: const Text('History Ujian'),
              selected: _guruTab == 2,
              selectedColor: context.bm.primary,
              onTap: () { Navigator.pop(context); setState(() => _guruTab = 2); },
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
            ),`,
  'GuruDashboard drawer: fix tab indices'
);

// ══════════════════════════════════════════════════════════════════
// 5. GuruDashboard _buildTab: tambah case 0 Beranda
// ══════════════════════════════════════════════════════════════════
replace(
  `  Widget _buildTab() {
    switch (_guruTab) {
      case 1: return ExamHistoryList(filterMapel: _isAdmin ? null : _mapelRoles);
      case 2: return RekapsNilaiScreen(filterMapel: _isAdmin ? null : _mapelRoles);
      case 3: return AnalyticsScreen(filterMapel: _isAdmin ? null : _mapelRoles);
      case 4: return JadwalScreen(role: _isAdmin ? 'admin1' : 'guru');
      default: return ExamCreatorForm(allowedMapel: _isAdmin ? null : _mapelRoles);
    }
  }`,
  `  Widget _buildTab() {
    switch (_guruTab) {
      case 1: return ExamCreatorForm(allowedMapel: _isAdmin ? null : _mapelRoles);
      case 2: return ExamHistoryList(filterMapel: _isAdmin ? null : _mapelRoles);
      case 3: return RekapsNilaiScreen(filterMapel: _isAdmin ? null : _mapelRoles);
      case 4: return AnalyticsScreen(filterMapel: _isAdmin ? null : _mapelRoles);
      case 5: return JadwalScreen(role: _isAdmin ? 'admin1' : 'guru');
      default: return _berandaGuru();
    }
  }`,
  'GuruDashboard _buildTab: case indices updated + Beranda'
);

// ══════════════════════════════════════════════════════════════════
// 6. Tambah widget Beranda + helpers sebelum _buildGuruDrawer
// ══════════════════════════════════════════════════════════════════
replace(
  `  Widget _buildGuruDrawer() {`,
  `  // ── Greeting helpers ──────────────────────────────────────────
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
    {'label': 'Rekap Nilai', 'icon': Icons.grading,                'tab': 3, 'color': const Color(0xFF00897B)},
    {'label': 'Analitik',    'icon': Icons.bar_chart_outlined,     'tab': 4, 'color': const Color(0xFFF4511E)},
    {'label': 'Jadwal',      'icon': Icons.calendar_month_outlined,'tab': 5, 'color': const Color(0xFF039BE5)},
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final qa = items[i];
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(qa['icon'] as IconData, color: color, size: 26),
              ),
              const SizedBox(height: 7),
              Text(qa['label'] as String,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ]),
          ),
        );
      },
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
        Text("Kelas \$kelas — Semua Selesai!",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
        Text("\$count/\$total siswa telah submit",
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
        Expanded(child: Text("Kelas \$kelas",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Text("\$selesai/\$total",
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
              child: Text("\${selesai.length} submit",
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
            child: Text("+\${selesai.length + melanggar.length - 8} lainnya",
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
            Text("Kelas \${s.classFolder}",
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
                        Text("\${e.mapel}  •  \${e.jenjang}  •  Selesai \${DateFormat('HH:mm').format(e.waktuSelesai)}",
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

  Widget _buildGuruDrawer() {`,
  'GuruDashboard: tambah semua widget Beranda + helpers'
);

// ══════════════════════════════════════════════════════════════════
// 7. Admin1Dashboard state: tambah _adminQuickActions
// ══════════════════════════════════════════════════════════════════
replace(
  `  int _tab = 0;
  String _search = "";
  String _filter = "semua";

  @override
  void initState() {
    super.initState();
    startIdleWatcher();
  }`,
  `  int _tab = 0;
  String _search = "";
  String _filter = "semua";
  Set<int> _adminQuickActions = {1, 3, 5, 6, 7, 9};

  @override
  void initState() {
    super.initState();
    startIdleWatcher();
    _loadAdminQuickActions();
  }`,
  'Admin1Dashboard: tambah state _adminQuickActions'
);

// ══════════════════════════════════════════════════════════════════
// 8. Admin1Dashboard header: replace compact → besar
// ══════════════════════════════════════════════════════════════════
replace(
  `          // Header (gradient)
          Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.bm.primary, context.bm.gradient2],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF60A5FA)),
                tooltip: "Menu",
                onPressed: () => _scaffoldKey.currentState!.openDrawer(),
              ),
              const Icon(Icons.admin_panel_settings, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Administrator',
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text(widget.admin.nama,
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
              // Badge ujian aktif
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('exam').snapshots(),
                builder: (c, es) {
                  if (!es.hasData) return const SizedBox();
                  final n = es.data!.docs
                      .map((d) => ExamData.fromFirestore(d))
                      .where((e) => e.isOngoing)
                      .length;
                  if (n == 0) return const SizedBox();
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.green, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                      const SizedBox(width: 4),
                      Text("$n Ujian Aktif",
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ]),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                tooltip: "Keluar",
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Keluar?"),
                    content: const Text("Yakin ingin keluar dari sesi ini?"),
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
                ),
              ),
            ]),
          ),`,
  `          // ── Header Besar Admin ───────────────────────────────
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
              // Baris atas
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white70),
                    onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                  ),
                  const Icon(Icons.school_outlined, color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  const Expanded(child: Text("SMP Budi Mulia",
                      style: TextStyle(color: Colors.white38, fontSize: 12))),
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
                    builder: (c, es) {
                      if (!es.hasData) return const SizedBox();
                      final n = es.data!.docs
                          .map((d) => ExamData.fromFirestore(d))
                          .where((e) => e.isOngoing).length;
                      if (n == 0) return const SizedBox();
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.white, size: 7),
                          const SizedBox(width: 3),
                          Text("$n Aktif", style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ]),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                    tooltip: "Keluar",
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Keluar?"),
                        content: const Text("Yakin ingin keluar dari sesi ini?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
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
                    ),
                  ),
                ]),
              ),
              // Baris utama: greeting + nama besar + avatar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(_adminGreetIcon(), color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      Text(_adminGreetText(),
                          style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    ]),
                    const SizedBox(height: 4),
                    Text(widget.admin.nama,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 24,
                            fontWeight: FontWeight.bold, height: 1.2),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    _headerBadge2('Administrator', Colors.purple, Icons.admin_panel_settings),
                  ])),
                  const SizedBox(width: 14),
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(widget.admin.initials,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 22)),
                  ),
                ]),
              ),
            ]),
          ),`,
  'Admin1Dashboard: header besar'
);

// ══════════════════════════════════════════════════════════════════
// 9. Admin1Dashboard: tambah helper methods + enhances _stats
// ══════════════════════════════════════════════════════════════════
replace(
  `  static const _tabLabels = [`,
  `  // ── Admin greeting helpers ─────────────────────────────────
  String _adminGreetText() {
    final h = DateTime.now().hour;
    if (h < 11) return "Selamat Pagi";
    if (h < 15) return "Selamat Siang";
    if (h < 18) return "Selamat Sore";
    return "Selamat Malam";
  }

  IconData _adminGreetIcon() {
    final h = DateTime.now().hour;
    if (h < 11) return Icons.wb_sunny;
    if (h < 15) return Icons.wb_sunny_outlined;
    if (h < 18) return Icons.wb_twilight;
    return Icons.nightlight_round;
  }

  Widget _headerBadge2(String label, Color c, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: c.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.white70),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    ]),
  );

  // ── Admin Quick Actions ────────────────────────────────────────
  Future<void> _loadAdminQuickActions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('admin_quick_actions');
    if (saved != null && mounted) {
      setState(() => _adminQuickActions = saved.map(int.parse).toSet());
    }
  }

  Future<void> _saveAdminQuickActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('admin_quick_actions',
        _adminQuickActions.map((e) => e.toString()).toList());
  }

  List<Map<String, dynamic>> get _adminQuickActionItems => [
    {'label': 'Buat Ujian', 'icon': Icons.add_task_outlined,          'tab': 1, 'color': const Color(0xFF1E88E5)},
    {'label': 'Broadcast',  'icon': Icons.campaign_outlined,           'tab': 3, 'color': const Color(0xFFF4511E)},
    {'label': 'Guru',       'icon': Icons.manage_accounts_outlined,    'tab': 4, 'color': const Color(0xFF7B1FA2)},
    {'label': 'Siswa',      'icon': Icons.groups_outlined,             'tab': 5, 'color': const Color(0xFF00897B)},
    {'label': 'History',    'icon': Icons.history_edu_outlined,        'tab': 6, 'color': const Color(0xFF546E7A)},
    {'label': 'Rekap Nilai','icon': Icons.grading_outlined,            'tab': 7, 'color': const Color(0xFF039BE5)},
    {'label': 'Analitik',   'icon': Icons.bar_chart_outlined,          'tab': 9, 'color': const Color(0xFFE65100)},
    {'label': 'Jadwal',     'icon': Icons.calendar_month_outlined,     'tab': 10,'color': const Color(0xFF2E7D32)},
    {'label': 'Pengaturan', 'icon': Icons.settings_outlined,           'tab': 8, 'color': const Color(0xFF37474F)},
  ];

  Future<void> _showAdminQuickActionsDialog() async {
    final tmp = Set<int>.from(_adminQuickActions);
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Pilih Akses Cepat"),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ..._adminQuickActionItems.map((qa) {
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                setState(() => _adminQuickActions = tmp);
                _saveAdminQuickActions();
                Navigator.pop(ctx);
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminQuickActionsGrid() {
    final items = _adminQuickActionItems
        .where((qa) => _adminQuickActions.contains(qa['tab'] as int))
        .toList();
    if (items.isEmpty) return const SizedBox();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.95),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final qa = items[i];
        final color = qa['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _tab = qa['tab'] as int),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(qa['icon'] as IconData, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(qa['label'] as String,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ]),
          ),
        );
      },
    );
  }

  // ── Admin Kelas Selesai ────────────────────────────────────────
  Widget _buildAdminKelasSelesai(List<UserAccount> siswa) {
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
        cards.add(_adminKelasSelesaiCard(kelas, selesai, students.length));
      } else if (mengerjakan > 0 || selesai > 0) {
        cards.add(_adminKelasProgressCard(kelas, selesai, students.length));
      }
    }
    if (cards.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      const Text("Status Per Kelas",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      ...cards,
    ]);
  }

  Widget _adminKelasSelesaiCard(String kelas, int count, int total) => Container(
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
        Text("Kelas \$kelas — Semua Selesai!",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
        Text("\$count/\$total siswa telah submit",
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

  Widget _adminKelasProgressCard(String kelas, int selesai, int total) => Container(
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
        Expanded(child: Text("Kelas \$kelas",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Text("\$selesai/\$total", style: const TextStyle(color: Colors.grey, fontSize: 12)),
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

  static const _tabLabels = [`,
  'Admin1Dashboard: tambah semua helper methods'
);

// ══════════════════════════════════════════════════════════════════
// 10. Admin1Dashboard _stats(): tambah quick actions + kelas selesai
// ══════════════════════════════════════════════════════════════════
replace(
  `  Widget _stats(List<UserAccount> u) {
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
              Icons.groups),`,
  `  Widget _stats(List<UserAccount> u) {
    final s = u.where((x) => x.role == 'siswa').toList();
    final m = s.where((x) => x.statusMengerjakan == 'mengerjakan').length;
    final l = s.where((x) => x.statusMengerjakan == 'melanggar').length;
    final d = s.where((x) => x.statusMengerjakan == 'selesai').length;
    final bm = s.where((x) => x.statusMengerjakan == 'belum mulai').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ─ Akses Cepat ───────────────────────────────────────────
        Row(children: [
          const Expanded(child: Text("Akses Cepat",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          GestureDetector(
            onTap: _showAdminQuickActionsDialog,
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
        _buildAdminQuickActionsGrid(),
        const SizedBox(height: 20),
        // ─ Stat Cards ─────────────────────────────────────────────
        Row(children: [
          _statBox("Total Siswa", s.length.toString(), Colors.blue,
              Icons.groups),`,
  'Admin1Dashboard _stats(): tambah quick actions di atas stat cards'
);

// Tambah class selesai + activity feed setelah ujian aktif di _stats()
replace(
  `                )),
              ],
            );
          },
        ),
      ]),
    );
  }

  Widget _statBox(String t, String v, Color c, IconData icon) =>`,
  `                )),
              ],
            );
          },
        ),

        // ─ Status Per Kelas ─────────────────────────────────────
        _buildAdminKelasSelesai(s),
      ]),
    );
  }

  Widget _statBox(String t, String v, Color c, IconData icon) =>`,
  'Admin1Dashboard _stats(): tambah kelas selesai di bawah ujian aktif'
);

// ══════════════════════════════════════════════════════════════════
// 11. HomeScreen header: make bigger
// ══════════════════════════════════════════════════════════════════
replace(
  `        // Header gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 230,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.bm.primary, context.bm.gradient2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),`,
  `        // Header gradient
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
        ),`,
  'HomeScreen header: lebih besar + rounded + shadow'
);

// HomeScreen header bar: greeting lebih besar
replace(
  `            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 8, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF60A5FA)),
                  tooltip: "Menu",
                  onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                ),
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
                              "Kelas \${widget.user.kode}"),
                          const SizedBox(width: 6),
                          _chip(Icons.meeting_room,
                              "Ruang \${widget.user.ruang}"),
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
            ),`,
  `            // ── Header bar siswa ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 8, 0),
              child: Column(children: [
                // Baris atas: menu + sekolah + logout
                Row(children: [
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
                        _chip(Icons.class_, "Kelas \${widget.user.kode}"),
                        const SizedBox(width: 6),
                        _chip(Icons.meeting_room, "Ruang \${widget.user.ruang}"),
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
            ),`,
  'HomeScreen header: lebih besar dengan school name + date row'
);

// ══════════════════════════════════════════════════════════════════
// Tulis file
// ══════════════════════════════════════════════════════════════════
fs.writeFileSync(FILE, src, 'utf8');
console.log('\n🎉 Semua patch berhasil diterapkan!');