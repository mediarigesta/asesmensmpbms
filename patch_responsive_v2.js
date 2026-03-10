const fs = require('fs');
let src = fs.readFileSync('lib/main.dart', 'utf8');
let count = 0;

function replace(find, rep, label) {
  if (!src.includes(find)) { console.error('NOT FOUND: ' + label); process.exit(1); }
  const next = src.replace(find, rep);
  if (next === src) { console.error('NO CHANGE: ' + label); process.exit(1); }
  src = next;
  count++;
  console.log('OK: ' + label);
}

// ═══════════════════════════════════════════════════════════════
// GURU DASHBOARD
// ═══════════════════════════════════════════════════════════════

// 1. GuruDashboard: drawer + body wrap
replace(
  `    drawer: _buildGuruDrawer(),
    body: SafeArea(
      bottom: false,
      child: Column(children: [`,
  `    drawer: MediaQuery.of(context).size.width >= 900 ? null : _buildGuruDrawer(),
    body: Row(children: [
      if (MediaQuery.of(context).size.width >= 900)
        SizedBox(width: 240, child: _buildGuruSideBar()),
      Expanded(child: SafeArea(
      bottom: false,
      child: Column(children: [`,
  'GuruDashboard: drawer + body wrap'
);

// 2. GuruDashboard: close Row + Expanded
replace(
  `      ]),
    ),
  );

  // Cek apakah string hari mengandung tanggal hari ini`,
  `      ]),
      )),
    ]),
  );

  // Cek apakah string hari mengandung tanggal hari ini`,
  'GuruDashboard: close Row+Expanded'
);

// 3. GuruDashboard: hamburger conditional
replace(
  `              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white70),
                onPressed: () => _scaffoldKey.currentState!.openDrawer(),
              ),
              const Icon(Icons.school_outlined, color: Colors.white38, size: 14),`,
  `              if (MediaQuery.of(context).size.width < 900)
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white70),
                  onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                ),
              const Icon(Icons.school_outlined, color: Colors.white38, size: 14),`,
  'GuruDashboard: hamburger conditional'
);

// 4. Add _buildGuruSideBar() before _buildGuruDrawer()
replace(
  `  Widget _buildGuruDrawer() {`,
  `  Widget _buildGuruSideBar() {
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
                leading: const Icon(Icons.calendar_month_outlined, size: 20),
                title: const Text('Jadwal', style: TextStyle(fontSize: 13)),
                selected: _guruTab == 5,
                selectedColor: context.bm.primary,
                selectedTileColor: context.bm.primary.withValues(alpha: 0.08),
                onTap: () => setState(() => _guruTab = 5),
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

  Widget _buildGuruDrawer() {`,
  'GuruDashboard: add _buildGuruSideBar'
);

// ═══════════════════════════════════════════════════════════════
// ADMIN1 DASHBOARD
// ═══════════════════════════════════════════════════════════════

// 5. Admin1Dashboard: drawer + body wrap
replace(
  `    drawer: _buildAdminDrawer(),
    body: StreamBuilder<QuerySnapshot>(`,
  `    drawer: MediaQuery.of(context).size.width >= 900 ? null : _buildAdminDrawer(),
    body: Row(children: [
      if (MediaQuery.of(context).size.width >= 900)
        SizedBox(width: 240, child: _buildAdminSideBar()),
      Expanded(child: StreamBuilder<QuerySnapshot>(`,
  'Admin1Dashboard: drawer + body wrap'
);

// 6. Admin1Dashboard: close Row + Expanded
replace(
  `      },
    ),
  );

  // Tab labels for header display`,
  `      },
    )),
  ]),
  );

  // Tab labels for header display`,
  'Admin1Dashboard: close Row+Expanded'
);

// 7. Admin1Dashboard: hamburger conditional
replace(
  `                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white70),
                    onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                  ),
                  const Icon(Icons.school_outlined, color: Colors.white38, size: 14),`,
  `                  if (MediaQuery.of(context).size.width < 900)
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white70),
                      onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                    ),
                  const Icon(Icons.school_outlined, color: Colors.white38, size: 14),`,
  'Admin1Dashboard: hamburger conditional'
);

// 8. Add _buildAdminSideBar() before _buildAdminDrawer()
replace(
  `  Widget _buildAdminDrawer() {`,
  `  Widget _buildAdminSideBar() {
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

  Widget _buildAdminDrawer() {`,
  'Admin1Dashboard: add _buildAdminSideBar'
);

// ═══════════════════════════════════════════════════════════════
// HOME SCREEN (SISWA)
// ═══════════════════════════════════════════════════════════════

// 9. HomeScreen: drawer + body wrap
replace(
  `      drawer: _buildHomeDrawer(),
      body: GestureDetector(
        onTap: resetIdleTimer,
        onPanDown: (_) => resetIdleTimer(),
        behavior: HitTestBehavior.translucent,`,
  `      drawer: MediaQuery.of(context).size.width >= 900 ? null : _buildHomeDrawer(),
      body: Row(children: [
        if (MediaQuery.of(context).size.width >= 900)
          SizedBox(width: 240, child: _buildHomeSideBar()),
        Expanded(child: GestureDetector(
          onTap: resetIdleTimer,
          onPanDown: (_) => resetIdleTimer(),
          behavior: HitTestBehavior.translucent,`,
  'HomeScreen: drawer + body wrap'
);

// 10. HomeScreen: close Row + Expanded
replace(
  `      ]),
      ),
    );
  }

  // Card tampilan ketika siswa sudah selesai mengerjakan`,
  `      ]),
      )),
    ]),
    );
  }

  // Card tampilan ketika siswa sudah selesai mengerjakan`,
  'HomeScreen: close Row+Expanded'
);

// 11. HomeScreen: hamburger conditional
replace(
  `                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white70),
                    onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                  ),`,
  `                Row(children: [
                  if (MediaQuery.of(context).size.width < 900)
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white70),
                      onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                    ),`,
  'HomeScreen: hamburger conditional'
);

// 12. Add _buildHomeSideBar() before _buildHomeDrawer()
replace(
  `  Widget _buildHomeDrawer() {`,
  `  Widget _buildHomeSideBar() {
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
                child: Text('Kelas ' + widget.user.kode + ' \u00b7 Ruang ' + widget.user.ruang,
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

  Widget _buildHomeDrawer() {`,
  'HomeScreen: add _buildHomeSideBar'
);

fs.writeFileSync('lib/main.dart', src, 'utf8');
console.log('\nDone! ' + count + ' changes applied.');
