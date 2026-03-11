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
// 1. FIX OVERFLOW: GuruRoleManager header Row
// ═══════════════════════════════════════════════════════════════
replace(
`          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Manajemen Role Guru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Atur hak akses dan mata pelajaran setiap guru',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          const Spacer(),
          // Legenda role
          ...GuruRoleManager.availableRoles.map((r) => Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: r.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: r.color.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(r.icon, color: r.color, size: 13),
              const SizedBox(width: 5),
              Text(r.label, style: TextStyle(color: r.color, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          )),`,
`          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Manajemen Role Guru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Atur hak akses dan mata pelajaran setiap guru',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ])),`,
'GuruRoleManager header overflow fix'
);

// ═══════════════════════════════════════════════════════════════
// 2. FIX OVERFLOW: Tipe soal Row → Wrap
// ═══════════════════════════════════════════════════════════════
replace(
`              Row(children: [
                _tipePill("Pilihan Ganda", TipeSoal.pilihanGanda, Colors.blue),
                const SizedBox(width: 6),
                _tipePill("Benar/Salah", TipeSoal.benarSalah, Colors.green),
                const SizedBox(width: 6),
                _tipePill("Uraian", TipeSoal.uraian, Colors.orange),
              ]),`,
`              Wrap(spacing: 8, runSpacing: 6, children: [
                _tipePill("Pilihan Ganda", TipeSoal.pilihanGanda, Colors.blue),
                _tipePill("Benar/Salah", TipeSoal.benarSalah, Colors.green),
                _tipePill("Uraian", TipeSoal.uraian, Colors.orange),
              ]),`,
'Tipe soal Row→Wrap overflow fix'
);

// ═══════════════════════════════════════════════════════════════
// 3. ExamData: add targetKelas field
// ═══════════════════════════════════════════════════════════════
replace(
`  final String creatorName;

  ExamData({`,
`  final String creatorName;
  final List<String> targetKelas;

  ExamData({`,
'ExamData add targetKelas field'
);

replace(
`    this.creatorName = '',
  });`,
`    this.creatorName = '',
    this.targetKelas = const [],
  });`,
'ExamData targetKelas constructor default'
);

replace(
`      creatorName: data['creatorName'] ?? '',
    );`,
`      creatorName: data['creatorName'] ?? '',
      targetKelas: List<String>.from(data['targetKelas'] ?? []),
    );`,
'ExamData.fromFirestore targetKelas'
);

// ═══════════════════════════════════════════════════════════════
// 4. ExamCreatorForm: add _selTargetKelas state
// ═══════════════════════════════════════════════════════════════
replace(
`  String? _selMapel, _selKelas, _selKategori;`,
`  String? _selMapel, _selKelas, _selKategori;
  Set<String> _selTargetKelas = {};`,
'ExamCreatorForm add _selTargetKelas state'
);

// reset targetKelas when jenjang changes
replace(
`          _drop("Pilih Jenjang / Kelas", _selKelas,
              ["Kelas 7", "Kelas 8", "Kelas 9"],
                  (v) => setState(() => _selKelas = v)),
          const SizedBox(height: 14),
          _drop("Kategori Ujian", _selKategori,`,
`          _drop("Pilih Jenjang / Kelas", _selKelas,
              ["Kelas 7", "Kelas 8", "Kelas 9"],
                  (v) => setState(() { _selKelas = v; _selTargetKelas = {}; })),
          if (_selKelas != null) ...[
            const SizedBox(height: 14),
            _buildTargetKelasSelector(),
          ],
          const SizedBox(height: 14),
          _drop("Kategori Ujian", _selKategori,`,
'ExamCreatorForm add targetKelas selector'
);

// ═══════════════════════════════════════════════════════════════
// 5. ExamCreatorForm: save targetKelas in _saveExam()
// ═══════════════════════════════════════════════════════════════
replace(
`        'kategori\'   : _selKategori ?? \'\',
        \'creatorName\': widget.creatorName ?? \'\',`,
`        'kategori\'   : _selKategori ?? \'\',
        \'creatorName\': widget.creatorName ?? \'\',
        \'targetKelas\': _selTargetKelas.toList(),`,
'_saveExam save targetKelas'
);

// ═══════════════════════════════════════════════════════════════
// 6. ExamCreatorForm: add _buildTargetKelasSelector method
//    (insert before _stepData)
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
    final classes = ['${grade}A', '${grade}B', '${grade}C', '${grade}D'];
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
      Text('Kosongkan = terbit ke semua kelas ${grade}',
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
// 7. Kelas panel (Guru) → show 7A-9D
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

// update isSelected logic in guru kelas panel (separator items are not selectable)
replace(
`              final val = j['value'] as String?;
              final isSelected = _panelKelas == val;
              return InkWell(
                onTap: () =>
                    setState(() => _panelKelas = val),`,
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
// 8. Kelas panel (Admin) → show 7A-9D
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
// 9. Fix penilaian filtering (Guru) — support targetKelas
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
// 10. Fix penilaian filtering (Admin) — support targetKelas
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
// 11. Guru tab 10: responsive LayoutBuilder
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
// 12. Admin tab 20: responsive LayoutBuilder
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
// 13. Exam card tappable (Guru penilaian itemBuilder)
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
// 14. Exam card tappable (Admin penilaian itemBuilder)
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
// 15. Enhance _exportCSV to include more data
// ═══════════════════════════════════════════════════════════════
replace(
`  void _exportCSV(List<UserAccount> peserta) {
    final buf = StringBuffer();
    buf.writeln("Nama,Kode,Kelas,Ruang,Status");
    for (final s in peserta) {
      buf.writeln("${s.nama},${s.kode},${s.classFolder},${s.ruang},${s.statusMengerjakan}");
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
      buf.writeln('"${s.nama}","${s.kode}","${s.classFolder}","${s.ruang}","$status","$ket"');
    }
    final selesai = peserta.where((s) => s.statusMengerjakan == 'selesai').length;
    final langgar = peserta.where((s) => s.statusMengerjakan == 'melanggar').length;
    final mengerjakan = peserta.where((s) => s.statusMengerjakan == 'mengerjakan').length;
    final belum = peserta.where((s) => s.statusMengerjakan == 'belum mulai').length;
    buf.writeln('');
    buf.writeln('"RINGKASAN"');
    buf.writeln('"Total Peserta","${peserta.length}"');
    buf.writeln('"Selesai","$selesai"');
    buf.writeln('"Melanggar","$langgar"');
    buf.writeln('"Mengerjakan","$mengerjakan"');
    buf.writeln('"Belum Mulai","$belum"');
    buf.writeln('"Ujian","${exam.judul}"');
    buf.writeln('"Mapel","${exam.mapel}"');
    buf.writeln('"Jenjang","${exam.jenjang}"');
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
