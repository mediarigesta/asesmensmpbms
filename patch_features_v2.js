const fs = require('fs');
const file = 'lib/main.dart';
let src = fs.readFileSync(file, 'utf8');
let count = 0;

function replace(oldStr, newStr, label) {
  if (!src.includes(oldStr)) { console.error('NOT FOUND: ' + label); process.exit(1); }
  src = src.replace(oldStr, newStr);
  count++;
  console.log('OK: ' + label);
}

// ═══════════════════════════════════════════════════════════════
// 9. ExamCreatorForm — add _buildTargetKelasSelector method
// ═══════════════════════════════════════════════════════════════
replace(
`  // ============================================================
  // STEP 1: DATA UJIAN
  // ============================================================
  Widget _stepData()`,
`  // ── Selector kelas spesifik ──────────────────────────────────
  Widget _buildTargetKelasSelector() {
    final grade = _selKelas == 'Kelas 7' ? '7'
        : _selKelas == 'Kelas 8' ? '8' : '9';
    final classes = ['\${grade}A', '\${grade}B', '\${grade}C', '\${grade}D'];
    final allSelected = classes.every((c) => _selTargetKelas.contains(c));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Target Kelas Spesifik',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() {
            if (allSelected) _selTargetKelas.clear();
            else _selTargetKelas = Set.from(classes);
          }),
          child: Text(allSelected ? 'Batal Pilih Semua' : 'Pilih Semua',
              style: TextStyle(color: context.bm.primary,
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 4),
      Text('Kosongkan = terbit ke semua kelas \${grade}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: classes.map((c) {
        final selected = _selTargetKelas.contains(c);
        return FilterChip(
          label: Text('Kelas \$c'),
          selected: selected,
          onSelected: (v) => setState(() {
            if (v) _selTargetKelas.add(c);
            else _selTargetKelas.remove(c);
          }),
          selectedColor: context.bm.primary.withValues(alpha: 0.15),
          checkmarkColor: context.bm.primary,
          labelStyle: TextStyle(
            color: selected ? context.bm.primary : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        );
      }).toList()),
    ]);
  }

  // ============================================================
  // STEP 1: DATA UJIAN
  // ============================================================
  Widget _stepData()`,
'ExamCreatorForm add _buildTargetKelasSelector method'
);

// ═══════════════════════════════════════════════════════════════
// 10. Kelas panel (Guru) → show 7A-9D
// ═══════════════════════════════════════════════════════════════
replace(
`  Widget _buildKelasPanel() {
    final jenjangList = [
      {'label': 'Semua Kelas', 'value': null},
      {'label': 'Kelas 7', 'value': 'Kelas 7'},
      {'label': 'Kelas 8', 'value': 'Kelas 8'},
      {'label': 'Kelas 9', 'value': 'Kelas 9'},
    ];`,
`  Widget _buildKelasPanel() {
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
    ];`,
'Guru kelas panel show 7A-9D'
);

// separator items not selectable (Guru)
replace(
`              final val = j['value'] as String?;
              final isSelected = _panelKelas == val;
              return InkWell(
                onTap: () => setState(() => _panelKelas = val),`,
`              final val = j['value'] as String?;
              final isSep = val != null && val.startsWith('__sep');
              if (isSep) return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Text(j['label'] as String,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              );
              final isSelected = _panelKelas == val;
              return InkWell(
                onTap: () => setState(() => _panelKelas = val),`,
'Guru kelas panel separator items'
);

// ═══════════════════════════════════════════════════════════════
// 11. Kelas panel (Admin) → show 7A-9D
// ═══════════════════════════════════════════════════════════════
replace(
`  Widget _buildAdminKelasPanel() {
    final jenjangList = [
      {'label': 'Semua Kelas', 'value': null},
      {'label': 'Kelas 7', 'value': 'Kelas 7'},
      {'label': 'Kelas 8', 'value': 'Kelas 8'},
      {'label': 'Kelas 9', 'value': 'Kelas 9'},
    ];`,
`  Widget _buildAdminKelasPanel() {
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
    ];`,
'Admin kelas panel show 7A-9D'
);

// separator items not selectable (Admin)
replace(
`              final val = j['value'] as String?;
              final isSelected = _adminPanelKelas == val;
              return InkWell(
                onTap: () =>
                    setState(() => _adminPanelKelas = val),`,
`              final val = j['value'] as String?;
              final isSep = val != null && val.startsWith('__sep');
              if (isSep) return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Text(j['label'] as String,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              );
              final isSelected = _adminPanelKelas == val;
              return InkWell(
                onTap: () => setState(() => _adminPanelKelas = val),`,
'Admin kelas panel separator items'
);

// ═══════════════════════════════════════════════════════════════
// 12. Fix penilaian filtering (Guru) — support targetKelas
// ═══════════════════════════════════════════════════════════════
replace(
`              if (_panelKelas != null && e.jenjang != _panelKelas) {
                return false;
              }`,
`              if (_panelKelas != null) {
                if (e.targetKelas.isNotEmpty) {
                  if (!e.targetKelas.contains(_panelKelas)) return false;
                } else {
                  if (!e.jenjang.contains(_panelKelas![0])) return false;
                }
              }`,
'Guru penilaian filtering targetKelas'
);

// ═══════════════════════════════════════════════════════════════
// 13. Fix penilaian filtering (Admin) — support targetKelas
// ═══════════════════════════════════════════════════════════════
replace(
`              if (_adminPanelKelas != null &&
                  e.jenjang != _adminPanelKelas) return false;`,
`              if (_adminPanelKelas != null) {
                if (e.targetKelas.isNotEmpty) {
                  if (!e.targetKelas.contains(_adminPanelKelas)) return false;
                } else {
                  if (!e.jenjang.contains(_adminPanelKelas![0])) return false;
                }
              }`,
'Admin penilaian filtering targetKelas'
);

// ═══════════════════════════════════════════════════════════════
// 14. Guru tab 10: responsive LayoutBuilder
// ═══════════════════════════════════════════════════════════════
replace(
`      case 10: return Row(children: [_buildKelasPanel(), Expanded(child: _buildPenilaianView())]);`,
`      case 10: return LayoutBuilder(builder: (ctx, cst) {
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
      });`,
'Guru tab 10 responsive LayoutBuilder'
);

// ═══════════════════════════════════════════════════════════════
// 15. Admin tab 20: responsive LayoutBuilder
// ═══════════════════════════════════════════════════════════════
replace(
`      case 20:
        return Row(children: [_buildAdminKelasPanel(), Expanded(child: _buildAdminPenilaianView())]);`,
`      case 20: return LayoutBuilder(builder: (ctx, cst) {
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
      });`,
'Admin tab 20 responsive LayoutBuilder'
);

// ═══════════════════════════════════════════════════════════════
// 16. Exam card tappable (Guru penilaian itemBuilder)
// ═══════════════════════════════════════════════════════════════
replace(
`              itemBuilder: (ctx, i) => _examCardWide(filtered[i]),`,
`              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => ExamHistoryScreen(exam: filtered[i]))),
                child: _examCardWide(filtered[i]),
              ),`,
'Guru exam card tappable'
);

// ═══════════════════════════════════════════════════════════════
// 17. Exam card tappable (Admin penilaian itemBuilder)
// ═══════════════════════════════════════════════════════════════
replace(
`                  _adminExamCard(filtered[i]),`,
`                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ExamHistoryScreen(exam: filtered[i]))),
                    child: _adminExamCard(filtered[i]),
                  ),`,
'Admin exam card tappable'
);

// ═══════════════════════════════════════════════════════════════
// 18. Enhance _exportCSV to include more data
// ═══════════════════════════════════════════════════════════════
replace(
`  void _exportCSV(List<UserAccount> peserta) {
    final buf = StringBuffer();
    buf.writeln("Nama,Kode,Kelas,Ruang,Status");
    for (final s in peserta) {
      buf.writeln("\${s.nama},\${s.kode},\${s.classFolder},\${s.ruang},\${s.statusMengerjakan}");
    }
    final csv = buf.toString();
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("✅ Data CSV disalin ke clipboard! Paste ke Excel/Sheets."),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 4),
    ));
  }`,
`  void _exportCSV(List<UserAccount> peserta) {
    final buf = StringBuffer();
    buf.writeln("Nama,Kode,Kelas,Ruang,Status,Keterangan");
    for (final s in peserta) {
      final status = s.statusMengerjakan;
      final ket = status == 'selesai' ? 'Selesai mengerjakan'
          : status == 'melanggar' ? 'Terdeteksi melanggar'
          : status == 'mengerjakan' ? 'Sedang mengerjakan'
          : 'Belum mulai';
      buf.writeln('"\${s.nama}","\${s.kode}","\${s.classFolder}","\${s.ruang}","\$status","\$ket"');
    }
    final selesai = peserta.where((s) => s.statusMengerjakan == 'selesai').length;
    final langgar = peserta.where((s) => s.statusMengerjakan == 'melanggar').length;
    final mengerjakan = peserta.where((s) => s.statusMengerjakan == 'mengerjakan').length;
    final belum = peserta.where((s) => s.statusMengerjakan == 'belum mulai').length;
    buf.writeln('');
    buf.writeln('"RINGKASAN"');
    buf.writeln('"Total Peserta","\${peserta.length}"');
    buf.writeln('"Selesai","\$selesai"');
    buf.writeln('"Melanggar","\$langgar"');
    buf.writeln('"Mengerjakan","\$mengerjakan"');
    buf.writeln('"Belum Mulai","\$belum"');
    buf.writeln('"Ujian","\${exam.judul}"');
    buf.writeln('"Mapel","\${exam.mapel}"');
    buf.writeln('"Jenjang","\${exam.jenjang}"');
    final csv = buf.toString();
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("✅ Data nilai disalin ke clipboard! Paste ke Excel/Sheets."),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 4),
    ));
  }`,
'ExamHistoryScreen enhance _exportCSV'
);

// ── Write ──────────────────────────────────────────────────────
fs.writeFileSync(file, src, 'utf8');
console.log('\nDone! ' + count + ' replacements applied.');
