const fs = require('fs');
const file = 'lib/main.dart';
let src = fs.readFileSync(file, 'utf8');
let count = 0;

function replace(oldStr, newStr, label) {
  if (!src.includes(oldStr)) {
    console.error('NOT FOUND: ' + label);
    process.exit(1);
  }
  src = src.replace(oldStr, newStr);
  count++;
  console.log('OK: ' + label);
}

// ═══════════════════════════════════════════════════════════════
// 1. GURU _buildTab() — tambah case 10 (Penilaian)
// ═══════════════════════════════════════════════════════════════
replace(
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
`  Widget _buildTab() {
    switch (_guruTab) {
      case 1:  return ExamCreatorForm(allowedMapel: _isAdmin ? null : _mapelRoles);
      case 2:  return ExamHistoryList(filterMapel: _isAdmin ? null : _mapelRoles);
      case 3:  return RekapsNilaiScreen(filterMapel: _isAdmin ? null : _mapelRoles);
      case 4:  return AnalyticsScreen(filterMapel: _isAdmin ? null : _mapelRoles);
      case 5:  return JadwalScreen(role: _isAdmin ? 'admin1' : 'guru');
      case 10: return Row(children: [_buildKelasPanel(), Expanded(child: _buildPenilaianView())]);
      default: return _berandaGuru();
    }
  }`,
'Guru _buildTab add case 10'
);

// ═══════════════════════════════════════════════════════════════
// 2. GURU _buildPenilaianView() — fix "Tambah Ujian" button
// ═══════════════════════════════════════════════════════════════
replace(
`            onPressed: () =>
                setState(() {
                  _sidebarIdx = 1;
                  _subPage = 'tambah';
                }),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah Ujian',
                style: TextStyle(fontSize: 13)),`,
`            onPressed: () => setState(() => _guruTab = 1),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah Ujian',
                style: TextStyle(fontSize: 13)),`,
'Guru _buildPenilaianView fix Tambah Ujian button'
);

// ═══════════════════════════════════════════════════════════════
// 3. GURU Drawer — tambah ExpansionTile "Ujian"
// ═══════════════════════════════════════════════════════════════
replace(
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
            ),`,
`            ExpansionTile(
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
                _drawerSub(Icons.history_edu, 'Bank Soal / History', _guruTab == 2,
                    () { Navigator.pop(context); setState(() => _guruTab = 2); }),
              ],
            ),`,
'Guru Drawer ExpansionTile Ujian'
);

// ═══════════════════════════════════════════════════════════════
// 4. GURU — tambah helper _drawerSub setelah _buildGuruDrawer
// ═══════════════════════════════════════════════════════════════
replace(
`  Widget _buildGuruSideBar() {`,
`  Widget _drawerSub(IconData icon, String label, bool selected, VoidCallback onTap) {
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

  Widget _buildGuruSideBar() {`,
'Guru add _drawerSub helper'
);

// ═══════════════════════════════════════════════════════════════
// 5. ADMIN _buildTab(u) — tambah case 20 (Penilaian)
// ═══════════════════════════════════════════════════════════════
replace(
`      case 10:
        return const JadwalScreen(role: 'admin1');
      default:
        return GestureDetector(
          onTap: resetIdleTimer,
          onPanDown: (_) => resetIdleTimer(),
          behavior: HitTestBehavior.translucent,
          child: _settings(u),
        );
    }
  }`,
`      case 10:
        return const JadwalScreen(role: 'admin1');
      case 20:
        return Row(children: [_buildAdminKelasPanel(), Expanded(child: _buildAdminPenilaianView())]);
      default:
        return GestureDetector(
          onTap: resetIdleTimer,
          onPanDown: (_) => resetIdleTimer(),
          behavior: HitTestBehavior.translucent,
          child: _settings(u),
        );
    }
  }`,
'Admin _buildTab add case 20'
);

// ═══════════════════════════════════════════════════════════════
// 6. ADMIN _buildAdminPenilaianView() — fix "Tambah Ujian" button
// ═══════════════════════════════════════════════════════════════
replace(
`            onPressed: () => setState(() {
              _adminSidebarIdx = 1;
              _adminSubPage = 'tambah';
            }),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah Ujian',
                style: TextStyle(fontSize: 13)),`,
`            onPressed: () => setState(() => _tab = 1),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah Ujian',
                style: TextStyle(fontSize: 13)),`,
'Admin _buildAdminPenilaianView fix Tambah Ujian button'
);

// ═══════════════════════════════════════════════════════════════
// 7. ADMIN Drawer — tambah item Penilaian di MANAJEMEN UJIAN
// ═══════════════════════════════════════════════════════════════
replace(
`            _sectionLabel('MANAJEMEN UJIAN'),
            _item(1, Icons.add_task_outlined, 'Upload Soal'),
            _item(2, Icons.menu_book_outlined, 'Mata Pelajaran'),
            _item(6, Icons.history_edu_outlined, 'History Ujian'),`,
`            _sectionLabel('MANAJEMEN UJIAN'),
            _item(20, Icons.fact_check_outlined, 'Penilaian'),
            _item(1, Icons.add_task_outlined, 'Buat / Upload Soal'),
            _item(2, Icons.menu_book_outlined, 'Mata Pelajaran'),
            _item(6, Icons.history_edu_outlined, 'History Ujian'),`,
'Admin Drawer add Penilaian item'
);

// ═══════════════════════════════════════════════════════════════
// 8. ADMIN Drawer — tambah item Broadcast Aplikasi
// ═══════════════════════════════════════════════════════════════
replace(
`            _sectionLabel('SISTEM'),
// Ganti _item(3, ...) dengan ListTile di bawah ini:
            ListTile(
              leading: const Icon(Icons.campaign_outlined, size: 20),
              title: const Text('Broadcast WA', style: TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.chevron_right, size: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              onTap: () {
                Navigator.pop(context); // Menutup drawer/menu terlebih dahulu
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BroadcastWaScreen()),
                );
              },
            ),
            _item(8, Icons.settings_outlined, 'Pengaturan'),`,
`            _sectionLabel('SISTEM'),
            _item(3, Icons.campaign_outlined, 'Broadcast'),
            _item(8, Icons.settings_outlined, 'Pengaturan'),`,
'Admin Drawer simplify Sistem section'
);

// ── Write ──────────────────────────────────────────────────────
fs.writeFileSync(file, src, 'utf8');
console.log('\nDone! ' + count + ' replacements applied.');
