part of '../main.dart';

class Admin1Dashboard extends StatefulWidget {
  final UserAccount admin;
  const Admin1Dashboard({super.key, required this.admin});
  @override
  State<Admin1Dashboard> createState() => _Admin1DashboardState();
}

class _Admin1DashboardState extends State<Admin1Dashboard> with IdleTimeoutMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _tab = 0;
  String _search = "";
  String _filter = "semua";
  Set<int> _adminQuickActions = {1, 3, 5, 6, 7, 9};
  // 3-col wide layout state
  int _adminSidebarIdx = 0;  // 0=Dashboard,1=Ujian,2=Monitoring,3=Pengguna,4=Jadwal,5=Broadcast,6=Pengaturan
  String _adminSubPage = ''; // submenu page identifier
  String? _adminPanelKelas;  // selected kelas for penilaian panel
  int _adminFlyoutIdx = -1;  // -1=none
  int _adminUjianTab = 0;    // 0=saat ini,1=terjadwal,2=selesai,3=draft
  String _broadcastTarget = 'semua'; // 'semua'|'guru'|'siswa'

  @override
  void initState() {
    super.initState();
    startIdleWatcher();
    _loadAdminQuickActions();
  }

  @override
  void dispose() {
    stopIdleWatcher();
    super.dispose();
  }

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
  @override
  Widget build(BuildContext context) => _buildAdminNarrowLayout(context);

  Widget _buildAdminNarrowLayout(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    backgroundColor: context.bm.surface,
    drawer: _buildAdminDrawer(),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (c, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final u = snap.data!.docs.map((d) => UserAccount.fromFirestore(d)).toList();
        return SafeArea(
          bottom: false,
          child: Column(children: [
          // ── Header Besar Admin ───────────────────────────────
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
          ),
          Expanded(child: GestureDetector(
            onTap: resetIdleTimer,
            onPanDown: (_) => resetIdleTimer(),
            behavior: HitTestBehavior.translucent,
            child: _buildTab(u),
          )),
          ]),
        );
      },
    ),
  );

  // Tab labels for header display
  // ── Admin greeting helpers ─────────────────────────────────
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((qa) {
        final color = qa['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _tab = qa['tab'] as int),
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
        Expanded(child: Text("Kelas $kelas",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Text("$selesai/$total", style: const TextStyle(color: Colors.grey, fontSize: 12)),
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

  static const _tabLabels = [
    'Statistik', 'Upload Soal', 'Mata Pelajaran', 'Broadcast',
    'Manaj. Guru', 'Manaj. Siswa', 'History Ujian', 'Rekap Nilai', 'Pengaturan',
  ];

  // ═══════════════════════════════════════════════════════════════
  // ADMIN WIDE LAYOUT (≥1024px)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAdminWideLayout(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bm.surface,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            resetIdleTimer();
            if (_adminFlyoutIdx >= 0) setState(() => _adminFlyoutIdx = -1);
          },
          behavior: HitTestBehavior.translucent,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .snapshots(),
            builder: (ctx, snap) {
              final u = snap.hasData
                  ? snap.data!.docs
                      .map((d) => UserAccount.fromFirestore(d))
                      .toList()
                  : <UserAccount>[];
              return Stack(children: [
                Row(children: [
                  _buildAdminIconSidebar(),
                  if (_adminSidebarIdx == 1 &&
                      _adminSubPage == 'penilaian')
                    _buildAdminKelasPanel(),
                  Expanded(child: _buildAdminWideContent(u)),
                ]),
                if (_adminFlyoutIdx >= 0) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _adminFlyoutIdx = -1),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  _buildAdminFlyout(),
                ],
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAdminIconSidebar() {
    final items = [
      {'idx': 0, 'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'flyout': false},
      {'idx': 1, 'icon': Icons.quiz_outlined, 'label': 'Ujian', 'flyout': true},
      {'idx': 2, 'icon': Icons.monitor_heart_outlined, 'label': 'Monitor', 'flyout': true},
      {'idx': 3, 'icon': Icons.group_outlined, 'label': 'Pengguna', 'flyout': true},
      {'idx': 4, 'icon': Icons.calendar_month_outlined, 'label': 'Jadwal', 'flyout': false},
      {'idx': 5, 'icon': Icons.campaign_outlined, 'label': 'Broadcast', 'flyout': false},
      {'idx': 6, 'icon': Icons.settings_outlined, 'label': 'Pengaturan', 'flyout': false},
    ];
    return Container(
      width: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.bm.primary, context.bm.gradient2],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
          final isActive = _adminSidebarIdx == idx;
          final hasFlyout = item['flyout'] as bool;
          return GestureDetector(
            onTap: () {
              if (hasFlyout) {
                setState(() => _adminFlyoutIdx =
                    _adminFlyoutIdx == idx ? -1 : idx);
              } else {
                setState(() {
                  _adminSidebarIdx = idx;
                  _adminSubPage = '';
                  _adminFlyoutIdx = -1;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              margin:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      color: isActive
                          ? Colors.white
                          : Colors.white60,
                      size: 22),
                  if (hasFlyout)
                    Positioned(
                      right: -8,
                      bottom: -2,
                      child: Icon(Icons.chevron_right,
                          color: Colors.white38, size: 11),
                    ),
                ]),
                const SizedBox(height: 3),
                Text(item['label'] as String,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : Colors.white60,
                      fontSize: 9,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center),
              ]),
            ),
          );
        }),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ProfilePage(user: widget.admin, canEdit: false))),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Text(widget.admin.initials,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11)),
            ),
          ),
        ),
        IconButton(
          icon:
              const Icon(Icons.logout, color: Colors.white54, size: 18),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Keluar?"),
              content:
                  const Text("Yakin ingin keluar dari sesi ini?"),
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
                    final prefs =
                        await SharedPreferences.getInstance();
                    await prefs.remove('saved_user_id');
                    await prefs.remove('saved_username');
                    await prefs.remove('saved_password');
                    if (context.mounted) {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LoginScreen()));
                    }
                  },
                  child: const Text("Keluar"),
                ),
              ],
            ),
          ),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildAdminFlyout() {
    final Map<int, List<Map<String, dynamic>>> flyoutMap = {
      1: [
        {'label': 'Penilaian', 'icon': Icons.list_alt_outlined, 'sub': 'penilaian'},
        {'label': 'Tambah Ujian', 'icon': Icons.add_circle_outline, 'sub': 'tambah'},
        {'label': 'Bank Soal', 'icon': Icons.library_books_outlined, 'sub': 'banksoal'},
      ],
      2: [
        {'label': 'Monitor Siswa', 'icon': Icons.people_outline, 'sub': 'monitor'},
        {'label': 'Rekap Nilai', 'icon': Icons.grading_outlined, 'sub': 'rekap'},
        {'label': 'Analitik', 'icon': Icons.bar_chart_outlined, 'sub': 'analitik'},
      ],
      3: [
        {'label': 'Data Guru', 'icon': Icons.manage_accounts_outlined, 'sub': 'guru'},
        {'label': 'Data Siswa', 'icon': Icons.groups_outlined, 'sub': 'siswa'},
      ],
    };
    final items = flyoutMap[_adminFlyoutIdx] ?? [];
    if (items.isEmpty) return const SizedBox();
    return Positioned(
      left: 72,
      top: 60.0 + _adminFlyoutIdx * 56.0,
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
            border: Border.all(
                color: Colors.grey.shade200.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items.map((item) {
              final isActive = _adminSubPage == item['sub'] as String;
              return ListTile(
                dense: true,
                leading: Icon(item['icon'] as IconData,
                    size: 18,
                    color: isActive
                        ? context.bm.primary
                        : Colors.grey.shade500),
                title: Text(item['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive
                          ? context.bm.primary
                          : Colors.grey.shade800,
                    )),
                tileColor: isActive
                    ? context.bm.primary.withValues(alpha: 0.08)
                    : null,
                onTap: () {
                  setState(() {
                    _adminSidebarIdx = _adminFlyoutIdx;
                    _adminSubPage = item['sub'] as String;
                    _adminFlyoutIdx = -1;
                    if (_adminSubPage == 'penilaian') {
                      _adminPanelKelas = null;
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminKelasPanel() {
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
          right: BorderSide(
              color: Colors.grey.shade200.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.quiz_outlined,
                size: 16, color: context.bm.primary),
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
              final isSelected = _adminPanelKelas == val;
              return InkWell(
                onTap: () => setState(() => _adminPanelKelas = val),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.bm.primary
                            .withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: isSelected
                        ? Border(
                            left: BorderSide(
                                color: context.bm.primary,
                                width: 3))
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

  Widget _buildAdminWideContent(List<UserAccount> u) {
    switch (_adminSidebarIdx) {
      case 1:
        switch (_adminSubPage) {
          case 'tambah':
            return const ExamCreatorForm();
          case 'banksoal':
            return const ExamHistoryList();
          default:
            return _buildAdminPenilaianView();
        }
      case 2:
        switch (_adminSubPage) {
          case 'rekap':
            return const RekapsNilaiScreen();
          case 'analitik':
            return const AnalyticsScreen(filterMapel: null);
          default:
            return _stats(u);
        }
      case 3:
        switch (_adminSubPage) {
          case 'siswa':
            return _students(u);
          default:
            return const GuruRoleManager();
        }
      case 4:
        return const JadwalScreen(role: 'admin1');
      case 5:
        return _broadcast();
      case 6:
        return _settings(u);
      default:
        return _stats(u);
    }
  }

  Widget _buildAdminPenilaianView() {
    final tabLabels = ['Saat Ini', 'Terjadwal', 'Selesai', 'Draft'];
    final tabColors = [Colors.green, Colors.blue, Colors.grey, Colors.orange];
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        color: context.bm.surface,
        child: Row(children: [
          Expanded(
            child: Text(
              _adminPanelKelas != null
                  ? 'Penilaian — ' + _adminPanelKelas!
                  : 'Semua Penilaian',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.bm.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() => _tab = 1),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah Ujian',
                style: TextStyle(fontSize: 13)),
          ),
        ]),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        color: context.bm.surface,
        child: Row(
          children: List.generate(tabLabels.length, (i) {
            final isActive = _adminUjianTab == i;
            return GestureDetector(
              onTap: () => setState(() => _adminUjianTab = i),
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
                      color: isActive
                          ? tabColors[i]
                          : Colors.grey.shade600,
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
              return const Center(
                  child: CircularProgressIndicator());
            }
            final all = snap.data!.docs
                .map((d) => ExamData.fromFirestore(d))
                .toList();
            final filtered = all.where((e) {
              if (_adminPanelKelas != null) {
                if (e.targetKelas.isNotEmpty) {
                  if (!e.targetKelas.contains(_adminPanelKelas)) return false;
                } else {
                  if (!e.jenjang.contains(_adminPanelKelas![0])) return false;
                }
              }
              switch (_adminUjianTab) {
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
                              color: Colors.grey.shade400)),
                    ]),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
              itemBuilder: (ctx, i) =>
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ExamHistoryScreen(exam: filtered[i]))),
                    child: _adminExamCard(filtered[i]),
                  ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _adminExamCard(ExamData e) {
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
          if (e.spiType == 'remedial') _adminExamBadge('Remedial', Colors.deepOrange.shade50, Colors.deepOrange),
          if (e.spiType == 'susulan') _adminExamBadge('Susulan', Colors.indigo.shade50, Colors.indigo),
          if (e.kkm > 0) _adminExamBadge('KKM ${e.kkm}', Colors.teal.shade50, Colors.teal),
          if (e.kategori.isNotEmpty) _adminExamBadge(e.kategori, Colors.purple.shade100, Colors.purple.shade700),
          _adminExamBadge(isNativeMode ? 'Via Aplikasi' : 'Via Google Form', Colors.blue.shade50, Colors.blue.shade600),
          if (!isDraft) _adminExamBadge(DateFormat('dd MMM, HH:mm').format(e.waktuMulai) + ' — ' + DateFormat('HH:mm').format(e.waktuSelesai), Colors.grey.shade100, Colors.grey.shade600),
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

  Widget _adminExamBadge(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w600)),
  );

  Widget _buildAdminSideBar() {
    Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold,
              color: Colors.grey, letterSpacing: 0.8)),
    );
    Widget _item(int tab, IconData icon, String label) => ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      selected: _tab == tab,
      selectedColor: context.bm.primary,
      selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      onTap: () => setState(() => _tab = tab),
    );
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
                onTap: () => setState(() => _tab = 0),
                child: Image.asset('assets/logo.png', width: 48, height: 48),
              ),
              const SizedBox(height: 10),
              Text(widget.admin.nama,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: const Text('Administrator',
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), children: [
              ListTile(
                leading: Image.asset('assets/logo.png', width: 20, height: 20),
                title: const Text('Dashboard', style: TextStyle(fontSize: 13)),
                selected: _tab == 0,
                selectedColor: context.bm.primary,
                selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () => setState(() => _tab = 0),
              ),
              const Divider(height: 8),
              _sectionLabel('MONITORING'),
              _item(0, Icons.dashboard_outlined, 'Statistik'),
              _item(7, Icons.grading_outlined, 'Rekap Nilai'),
              _item(9, Icons.bar_chart_outlined, 'Analitik'),
              _item(10, Icons.calendar_month_outlined, 'Jadwal'),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.person_outline, size: 20),
                title: const Text('Profil Saya', style: TextStyle(fontSize: 13)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfilePage(user: widget.admin, canEdit: false),
                )),
              ),
              const Divider(height: 8),
              _sectionLabel('MANAJEMEN UJIAN'),
              _item(1, Icons.add_task_outlined, 'Upload Soal'),
              _item(2, Icons.menu_book_outlined, 'Mata Pelajaran'),
              _item(6, Icons.history_edu_outlined, 'History Ujian'),
              const Divider(height: 8),
              _sectionLabel('PENGGUNA'),
              _item(4, Icons.manage_accounts_outlined, 'Manaj. Guru'),
              _item(5, Icons.groups_outlined, 'Manaj. Siswa'),
              const Divider(height: 8),
              _sectionLabel('SISTEM'),
              ListTile(
                leading: const Icon(Icons.campaign_outlined, size: 20),
                title: const Text('Broadcast WA', style: TextStyle(fontSize: 13)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const BroadcastWaScreen()),
                ),
              ),
              _item(8, Icons.settings_outlined, 'Pengaturan'),
              const Divider(height: 8),
              _buildThemeSwitcher(),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red, size: 20),
                title: const Text('Keluar', style: TextStyle(color: Colors.red, fontSize: 13)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Keluar?"),
                    content: const Text("Yakin ingin keluar dari sesi ini?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
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
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildAdminDrawer() {
    Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: Colors.grey, letterSpacing: 0.8)),
    );

    Widget _item(int tab, IconData icon, String label) => ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      selected: _tab == tab,
      selectedColor: context.bm.primary,
      selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      onTap: () { Navigator.pop(context); setState(() => _tab = tab); },
    );

    return Drawer(
      child: Column(children: [
        // Header
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
              onTap: () { Navigator.pop(context); setState(() => _tab = 0); },
              child: Image.asset('assets/logo.png', width: 56, height: 56),
            ),
            const SizedBox(height: 12),
            Text(widget.admin.nama,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: const Text('Administrator',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ]),
        ),
        // Menu
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), children: [
            // Dashboard
            ListTile(
              leading: Image.asset('assets/logo.png', width: 22, height: 22),
              title: const Text('Dashboard', style: TextStyle(fontSize: 14)),
              selected: _tab == 0,
              selectedColor: context.bm.primary,
              selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () { Navigator.pop(context); setState(() => _tab = 0); },
            ),
            const Divider(height: 8),

            // Group: Monitoring
            _sectionLabel('MONITORING'),
            _item(0, Icons.dashboard_outlined, 'Statistik'),
            _item(7, Icons.grading_outlined, 'Rekap Nilai'),
            _item(9, Icons.bar_chart_outlined, 'Analitik'),
            _item(10, Icons.calendar_month_outlined, 'Jadwal'),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.person_outline, size: 20),
              title: const Text('Profil Saya', style: TextStyle(fontSize: 14)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfilePage(user: widget.admin, canEdit: false),
                ));
              },
            ),
            const Divider(height: 8),

            // Group: Manajemen Ujian
            _sectionLabel('MANAJEMEN UJIAN'),
            _item(20, Icons.fact_check_outlined, 'Penilaian'),
            _item(1, Icons.add_task_outlined, 'Buat / Upload Soal'),
            _item(2, Icons.menu_book_outlined, 'Mata Pelajaran'),
            _item(6, Icons.history_edu_outlined, 'History Ujian'),
            const Divider(height: 8),

            // Group: Pengguna
            _sectionLabel('PENGGUNA'),
            _item(4, Icons.manage_accounts_outlined, 'Manaj. Guru'),
            _item(5, Icons.groups_outlined, 'Manaj. Siswa'),
            const Divider(height: 8),

// Group: Sistem
            _sectionLabel('SISTEM'),
            _item(3, Icons.campaign_outlined, 'Broadcast'),
            _item(8, Icons.settings_outlined, 'Pengaturan'),
            const Divider(height: 8),
            _buildThemeSwitcher(),
            const Divider(height: 8),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red, size: 20),
              title: const Text('Keluar', style: TextStyle(color: Colors.red, fontSize: 14)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Keluar?"),
                    content: const Text("Yakin ingin keluar dari sesi ini?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
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
              },
            ),
          ]),
        ),
      ]),
    );
  }

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
      // Manajemen Role Guru
        return const GuruRoleManager();
      case 5:
        return _students(u);
      case 6:
        return const ExamHistoryList();
      case 7:
        return const RekapsNilaiScreen();
      case 9:
        return const AnalyticsScreen(filterMapel: null);
      case 10:
        return const JadwalScreen(role: 'admin1');
      case 20: return LayoutBuilder(builder: (ctx, cst) {
        if (cst.maxWidth >= 600) {
          return Row(children: [_buildAdminKelasPanel(), Expanded(child: _buildAdminPenilaianView())]);
        }
        final kelasAll = [null,'7A','7B','7C','7D','8A','8B','8C','8D','9A','9B','9C','9D'];
        return Column(children: [
          Container(
            height: 44, color: context.bm.surface,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: kelasAll.map((c) {
                final isActive = _adminPanelKelas == c;
                return GestureDetector(
                  onTap: () => setState(() => _adminPanelKelas = c),
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
          Expanded(child: _buildAdminPenilaianView()),
        ]);
      });
      default:
        return GestureDetector(
          onTap: resetIdleTimer,
          onPanDown: (_) => resetIdleTimer(),
          behavior: HitTestBehavior.translucent,
          child: _settings(u),
        );
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

        // ─ Status Per Kelas ─────────────────────────────────────
        _buildAdminKelasSelesai(s),
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
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          color: context.bm.surface,
          child: TabBar(
            labelColor: context.bm.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: context.bm.primary,
            tabs: const [
              Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'Broadcast Aplikasi'),
              Tab(icon: Icon(Icons.chat_bubble, size: 18), text: 'Broadcast WhatsApp'),
            ],
          ),
        ),
        Expanded(child: TabBarView(children: [
          _broadcastAplikasi(),
          _broadcastWa(),
        ])),
      ]),
    );
  }

  Widget _broadcastAplikasi() {
    final msgCtrl = TextEditingController();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('broadcast').snapshots(),
      builder: (c, snap) {
        String existing = "";
        String existingTarget = "semua";
        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() as Map;
          existing = d['message']?.toString() ?? "";
          existingTarget = d['target']?.toString() ?? "semua";
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.campaign, color: Colors.orange.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Broadcast Aplikasi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Pesan muncul sebagai notifikasi di aplikasi", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 20),
            if (existing.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 14),
                    const SizedBox(width: 6),
                    Text("Pesan Aktif — Target: ${existingTarget == 'semua' ? 'Semua Pengguna' : existingTarget == 'guru' ? 'Guru' : 'Siswa'}",
                        style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                  ]),
                  const SizedBox(height: 6),
                  Text(existing, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            const Text("Target Penerima", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final t in [
                {'val': 'semua', 'label': 'Semua Pengguna', 'icon': Icons.people_outline},
                {'val': 'guru',  'label': 'Guru Saja',      'icon': Icons.school_outlined},
                {'val': 'siswa', 'label': 'Siswa Saja',     'icon': Icons.person_outline},
              ])
                ChoiceChip(
                  avatar: Icon(t['icon'] as IconData, size: 16,
                      color: _broadcastTarget == t['val'] ? Colors.white : Colors.grey),
                  label: Text(t['label'] as String),
                  selected: _broadcastTarget == t['val'],
                  selectedColor: context.bm.primary,
                  labelStyle: TextStyle(
                      color: _broadcastTarget == t['val'] ? Colors.white : Colors.grey.shade700,
                      fontSize: 12),
                  onSelected: (_) => setState(() => _broadcastTarget = t['val'] as String),
                ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "Ketik Pesan Broadcast",
                hintText: "Pesan yang akan ditampilkan kepada penerima...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => FirebaseFirestore.instance.collection('settings').doc('broadcast').set({
                    'message': '', 'target': 'semua', 'timestamp': FieldValue.serverTimestamp(),
                  }),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text("HAPUS PESAN"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48)),
                  onPressed: () {
                    if (msgCtrl.text.trim().isEmpty) return;
                    FirebaseFirestore.instance.collection('settings').doc('broadcast').set({
                      'message': msgCtrl.text.trim(),
                      'target': _broadcastTarget,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    msgCtrl.clear();
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text("KIRIM BROADCAST"),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _broadcastWa() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(color: const Color(0xFF25D366).withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble, color: Color(0xFF25D366), size: 36),
          ),
          const SizedBox(height: 16),
          const Text("Broadcast WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text("Kirim pesan broadcast ke nomor WhatsApp siswa atau guru yang terdaftar.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.chat_bubble, size: 20),
              label: const Text("Buka Broadcast WhatsApp", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BroadcastWaScreen())),
            ),
          ),
        ]),
      ),
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
                onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(user: x, canEdit: true))); },
                leading: CircleAvatar(
                    backgroundColor:
                    x.statusAktif == 'aktif'
                        ? Colors.green
                        : Colors.red,
                    child: Text(x.initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12))),
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
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                      onSelected: (val) async {
                        if (val == 'reset') {
                          final chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
                          final rng = List.generate(8, (_) => chars[DateTime.now().microsecondsSinceEpoch % chars.length]).join();
                          final newPass = rng + DateTime.now().millisecond.toString().padLeft(2, '0');
                          await FirebaseFirestore.instance.collection('users').doc(x.id).update({'password': newPass});
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Password Baru'),
                                content: Column(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('Password berhasil direset:', style: TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 12),
                                  _resetPassRow('Username', x.username),
                                  const SizedBox(height: 8),
                                  _resetPassRow('Password', newPass),
                                ]),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
                                ],
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'reset', child: Row(children: [
                          Icon(Icons.lock_reset_outlined, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Reset Password', style: TextStyle(fontSize: 13)),
                        ])),
                      ],
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

  Widget _resetPassRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.copy_outlined, size: 18, color: Colors.blue),
          tooltip: 'Salin',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
          },
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      ]),
    );
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
                  final data = snap.hasData && snap.data!.exists
                      ? snap.data!.data() as Map<String, dynamic>
                      : <String, dynamic>{};
                  final ctrl = TextEditingController(
                      text: data['proctor_password']?.toString() ?? '');
                  final guruBisaLihat = data['guru_lihat_pin_token'] == true;

                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Input PIN
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
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
                            .set({'proctor_password': ctrl.text},
                            SetOptions(merge: true)),
                        child: const Text("Simpan"),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    // Toggle: guru bisa lihat PIN & Token
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Guru dapat melihat PIN & Token",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const SizedBox(height: 3),
                              const Text(
                                  "Jika aktif, PIN proktor dan token ujian tampil di header layar guru.",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ]),
                      ),
                      Switch(
                        value: guruBisaLihat,
                        activeColor: Colors.teal,
                        onChanged: (val) => FirebaseFirestore.instance
                            .collection('settings')
                            .doc('app_config')
                            .set({'guru_lihat_pin_token': val},
                            SetOptions(merge: true)),
                      ),
                    ]),
                  ]);
                },
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Nomor WA Admin (untuk fitur Test Broadcast)
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Nomor WA Admin",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              const Text(
                  "Nomor ini digunakan sebagai tujuan kirim test broadcast WA. Masukkan format: 08xxxxxxxxxx",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 20),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('settings')
                    .doc('app_config')
                    .snapshots(),
                builder: (c, snap) {
                  final data = snap.hasData && snap.data!.exists
                      ? snap.data!.data() as Map<String, dynamic>
                      : <String, dynamic>{};
                  final ctrl = TextEditingController(
                      text: data['admin_phone']?.toString() ?? '');
                  return Row(children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          hintText: "Contoh: 081234567890",
                          prefixIcon: const Icon(Icons.phone_android),
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
                          .set({'admin_phone': ctrl.text.trim()},
                              SetOptions(merge: true)),
                      child: const Text("Simpan"),
                    ),
                  ]);
                },
              ),
            ],
          ),
        ),
      ),

      // AI Provider untuk parse soal otomatis
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.purple.shade600, Colors.indigo.shade600]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text("AI untuk Upload Soal",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 6),
            const Text("Pilih provider AI dan masukkan API Key untuk fitur upload soal otomatis.",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(height: 20),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('settings').doc('app_config').snapshots(),
              builder: (ctx, snap) {
                final data = snap.hasData && snap.data!.exists
                    ? snap.data!.data() as Map<String, dynamic> : <String, dynamic>{};
                final provider = data['ai_provider']?.toString() ?? 'groq';
                final keyField = provider == 'gemini'     ? 'gemini_api_key'
                               : provider == 'openrouter' ? 'openrouter_api_key'
                               : 'groq_api_key';
                final hintMap = {
                  'groq':        'gsk_xxxxxxxxxxxxxxxxxxxx',
                  'gemini':      'AIzaSyXXXXXXXXXXXXXXXXXX',
                  'openrouter':  'sk-or-v1-xxxxxxxxxxxxxxxxxxxx',
                };
                final infoMap = {
                  'groq':       '🔗 console.groq.com — Gratis, cepat (Llama 3.3 70B)',
                  'gemini':     '🔗 aistudio.google.com — Gratis, pintar (Gemini 2.0 Flash)',
                  'openrouter': '🔗 openrouter.ai — Gratis, pilihan model banyak',
                };
                final ctrl = TextEditingController(text: data[keyField]?.toString() ?? '');
                final modelCtrl = TextEditingController(text: data['ai_model']?.toString() ?? '');
                void save() {
                  FirebaseFirestore.instance.collection('settings').doc('app_config').set({
                    'ai_provider': provider,
                    keyField: ctrl.text.trim(),
                    'ai_model': modelCtrl.text.trim(),
                  }, SetOptions(merge: true));
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Provider selector
                  const Text("Provider", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _aiProviderChip('groq',       'Groq',       provider, Icons.bolt),
                    const SizedBox(width: 8),
                    _aiProviderChip('gemini',     'Gemini',     provider, Icons.stars),
                    const SizedBox(width: 8),
                    _aiProviderChip('openrouter', 'OpenRouter', provider, Icons.hub),
                  ]),
                  const SizedBox(height: 10),
                  Text(infoMap[provider] ?? '', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                  const SizedBox(height: 12),
                  // API Key
                  const Text("API Key", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          hintText: hintMap[provider] ?? '',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
                      onPressed: save,
                      child: const Text("Simpan"),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // Model override (opsional)
                  const Text("Model (opsional, kosongkan = default)",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: modelCtrl,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      hintText: provider == 'gemini' ? 'gemini-2.0-flash'
                               : provider == 'openrouter' ? 'google/gemini-2.0-flash-exp:free'
                               : 'llama-3.3-70b-versatile',
                      prefixIcon: const Icon(Icons.memory_outlined),
                    ),
                    onSubmitted: (_) => save(),
                  ),
                ]);
              },
            ),
          ]),
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

