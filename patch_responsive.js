// patch_responsive.js — Responsive Sidebar Layout
// Wide screen (>=900px): persistent sidebar, no overlay drawer
// Narrow screen (<900px): existing drawer behavior

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
// 1. GuruDashboard build(): arrow → full method + responsive
// ══════════════════════════════════════════════════════════════════
replace(
  `  Widget build(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    backgroundColor: context.bm.surface,
    drawer: _buildGuruDrawer(),
    body: SafeArea(`,
  `  @override
  Widget build(BuildContext context) {
    final _isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bm.surface,
      drawer: _isWide ? null : _buildGuruDrawer(),
      body: Row(children: [
        if (_isWide) _buildGuruSideBar(),
        Expanded(child: SafeArea(`,
  'GuruDashboard build(): responsive wrapper'
);

// GuruDashboard: fix closing brackets
replace(
  `        )),
      ]),
    ),
  );

  // Cek apakah string hari mengandung tanggal hari ini`,
  `        )),
      ]),
        )),
      ]),
    );
  }

  // Cek apakah string hari mengandung tanggal hari ini`,
  'GuruDashboard build(): closing brackets responsive'
);

// ══════════════════════════════════════════════════════════════════
// 2. GuruDashboard hamburger → conditional
// ══════════════════════════════════════════════════════════════════
replace(
  `            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white70),
                onPressed: () => _scaffoldKey.currentState!.openDrawer(),
              ),
              const Icon(Icons.school_outlined, color: Colors.white38, size: 14),`,
  `            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Row(children: [
              if (MediaQuery.of(context).size.width < 900)
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white70),
                  onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                ),
              const Icon(Icons.school_outlined, color: Colors.white38, size: 14),`,
  'GuruDashboard hamburger: conditional'
);

// ══════════════════════════════════════════════════════════════════
// 3. Tambah _buildGuruSideBar() sebelum _buildGuruDrawer()
// ══════════════════════════════════════════════════════════════════
replace(
  `  Widget _buildGuruDrawer() {`,
  `  // ── Persistent Sidebar (wide screen) ──────────────────────────
  Widget _buildGuruSideBar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8, offset: const Offset(2, 0),
        )],
      ),
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
            Image.asset('assets/logo.png', width: 56, height: 56),
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
        // Menu
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [
          ListTile(
            leading: Image.asset('assets/logo.png', width: 22, height: 22),
            title: const Text('Dashboard'),
            selected: _guruTab == 0,
            selectedColor: context.bm.primary,
            selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => setState(() => _guruTab = 0),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profil Saya'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProfilePage(user: widget.guru, canEdit: false))),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Buat Ujian'),
            selected: _guruTab == 1,
            selectedColor: context.bm.primary,
            selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => setState(() => _guruTab = 1),
          ),
          ListTile(
            leading: const Icon(Icons.history_edu),
            title: const Text('History Ujian'),
            selected: _guruTab == 2,
            selectedColor: context.bm.primary,
            selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => setState(() => _guruTab = 2),
          ),
          ListTile(
            leading: const Icon(Icons.grading),
            title: const Text('Rekap Nilai'),
            selected: _guruTab == 3,
            selectedColor: context.bm.primary,
            selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => setState(() => _guruTab = 3),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Analitik'),
            selected: _guruTab == 4,
            selectedColor: context.bm.primary,
            selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => setState(() => _guruTab = 4),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Jadwal'),
            selected: _guruTab == 5,
            selectedColor: context.bm.primary,
            selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => setState(() => _guruTab = 5),
          ),
          const Divider(height: 1),
          _buildThemeSwitcher(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Keluar', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context),
          ),
        ])),
      ]),
    );
  }

  Widget _buildGuruDrawer() {`,
  'GuruDashboard: tambah _buildGuruSideBar()'
);

// ══════════════════════════════════════════════════════════════════
// 4. Admin1Dashboard build(): arrow → full method + responsive
// ══════════════════════════════════════════════════════════════════
replace(
  `  Widget build(BuildContext context) => Scaffold(
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
          child: Column(children: [`,
  `  @override
  Widget build(BuildContext context) {
    final _isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bm.surface,
      drawer: _isWide ? null : _buildAdminDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final u = snap.data!.docs.map((d) => UserAccount.fromFirestore(d)).toList();
          final mainContent = SafeArea(
            bottom: false,
            child: Column(children: [`,
  'Admin1Dashboard build(): responsive wrapper'
);

// Admin1Dashboard: fix closing brackets + add responsive
replace(
  `          Expanded(child: GestureDetector(
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

  // Tab labels for header display`,
  `          Expanded(child: GestureDetector(
            onTap: resetIdleTimer,
            onPanDown: (_) => resetIdleTimer(),
            behavior: HitTestBehavior.translucent,
            child: _buildTab(u),
          )),
            ]),
          );
          if (_isWide) return Row(children: [_buildAdminSideBar(), Expanded(child: mainContent)]);
          return mainContent;
        },
      ),
    );
  }

  // Tab labels for header display`,
  'Admin1Dashboard build(): closing responsive'
);

// ══════════════════════════════════════════════════════════════════
// 5. Admin1Dashboard hamburger → conditional
// ══════════════════════════════════════════════════════════════════
replace(
  `                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white70),
                    onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                  ),
                  const Icon(Icons.school_outlined, color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  const Expanded(child: Text("SMP Budi Mulia",`,
  `                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(children: [
                  if (MediaQuery.of(context).size.width < 900)
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white70),
                      onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                    ),
                  const Icon(Icons.school_outlined, color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  const Expanded(child: Text("SMP Budi Mulia",`,
  'Admin1Dashboard hamburger: conditional'
);

// ══════════════════════════════════════════════════════════════════
// 6. Tambah _buildAdminSideBar() sebelum _buildAdminDrawer()
// ══════════════════════════════════════════════════════════════════
replace(
  `  Widget _buildAdminDrawer() {
    Widget _sectionLabel(String text) => Padding(`,
  `  // ── Persistent Sidebar Admin (wide screen) ───────────────────
  Widget _buildAdminSideBar() {
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
      onTap: () => setState(() => _tab = tab),
    );
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8, offset: const Offset(2, 0),
        )],
      ),
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
            Image.asset('assets/logo.png', width: 56, height: 56),
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
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), children: [
            ListTile(
              leading: Image.asset('assets/logo.png', width: 22, height: 22),
              title: const Text('Dashboard', style: TextStyle(fontSize: 14)),
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
              title: const Text('Profil Saya', style: TextStyle(fontSize: 14)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ProfilePage(user: widget.admin, canEdit: false))),
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
            _item(8, Icons.settings_outlined, 'Pengaturan'),
            const Divider(height: 8),
            _buildThemeSwitcher(),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red, size: 20),
              title: const Text('Keluar', style: TextStyle(color: Colors.red, fontSize: 14)),
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
    );
  }

  Widget _buildAdminDrawer() {
    Widget _sectionLabel(String text) => Padding(`,
  'Admin1Dashboard: tambah _buildAdminSideBar()'
);

// ══════════════════════════════════════════════════════════════════
// 7. HomeScreen build(): responsive
// ══════════════════════════════════════════════════════════════════
replace(
  `    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bm.surface,
      drawer: _buildHomeDrawer(),
      body: GestureDetector(
        onTap: resetIdleTimer,
        onPanDown: (_) => resetIdleTimer(),
        behavior: HitTestBehavior.translucent,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [`,
  `    final _isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bm.surface,
      drawer: _isWide ? null : _buildHomeDrawer(),
      body: Row(children: [
        if (_isWide) _buildHomeSideBar(),
        Expanded(child: GestureDetector(
        onTap: resetIdleTimer,
        onPanDown: (_) => resetIdleTimer(),
        behavior: HitTestBehavior.translucent,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [`,
  'HomeScreen build(): responsive wrapper'
);

// HomeScreen: fix closing + hamburger
replace(
  `                // Baris atas: menu + sekolah + logout
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white70),
                    onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                  ),
                  const Icon(Icons.school_outlined, color: Colors.white38, size: 13),`,
  `                // Baris atas: menu + sekolah + logout
                Row(children: [
                  if (MediaQuery.of(context).size.width < 900)
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white70),
                      onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                    ),
                  const Icon(Icons.school_outlined, color: Colors.white38, size: 13),`,
  'HomeScreen hamburger: conditional'
);

// ══════════════════════════════════════════════════════════════════
// 8. Tambah _buildHomeSideBar() sebelum _buildHomeDrawer()
// ══════════════════════════════════════════════════════════════════
replace(
  `  Widget _buildHomeDrawer() {`,
  `  // ── Persistent Sidebar Siswa (wide screen) ───────────────────
  Widget _buildHomeSideBar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8, offset: const Offset(2, 0),
        )],
      ),
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
            Image.asset('assets/logo.png', width: 56, height: 56),
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
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [
          ListTile(
            leading: Image.asset('assets/logo.png', width: 22, height: 22),
            title: const Text('Dashboard'),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Jadwal Ujian'),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => JadwalScreen(role: 'siswa', userKode: widget.user.kode))),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profil Saya'),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProfilePage(user: widget.user, canEdit: false))),
          ),
          const Divider(height: 1),
          _buildThemeSwitcher(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Keluar', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context),
          ),
        ])),
      ]),
    );
  }

  Widget _buildHomeDrawer() {`,
  'HomeScreen: tambah _buildHomeSideBar()'
);

// ══════════════════════════════════════════════════════════════════
// 9. HomeScreen build(): close the extra Row wrapper
// ══════════════════════════════════════════════════════════════════
// Find the closing of the HomeScreen body Stack/Column and add the Row closing
replace(
  `          ]),
        ]),
      ]),
    );
  }

  void _loadExam() {`,
  `          ]),
        ]),
        )),
      ]),
    );
  }

  void _loadExam() {`,
  'HomeScreen build(): Row closing bracket'
);

// ══════════════════════════════════════════════════════════════════
// Write
// ══════════════════════════════════════════════════════════════════
fs.writeFileSync(FILE, src, 'utf8');
console.log('\n🎉 Responsive patch selesai!');
