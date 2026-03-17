part of '../main.dart';

// ============================================================
// FORM BUAT PENILAIAN (dipakai Admin1 & Guru)
// Alur: Step0=PilihMode → Step1=DataUjian → Step2=Pengaturan
//       → (native) Step3=PilihMetodeSoal → Step4=BuatSoal → Step99=Selesai
// ============================================================
class ExamCreatorForm extends StatefulWidget {
  /// null = akses semua mapel (admin). Set<String> = filter mapel guru.
  final Set<String>? allowedMapel;
  final String? creatorName;
  const ExamCreatorForm({super.key, this.allowedMapel, this.creatorName});
  @override
  State<ExamCreatorForm> createState() => _ExamCreatorFormState();
}

class _ExamCreatorFormState extends State<ExamCreatorForm> {
  // step: 0=pilih mode, 1=data, 2=pengaturan,
  //       3=pilih metode soal, 4=buat soal, 99=selesai
  int _step = 0;
  bool _isNative = false;

  // --- Data ujian ---
  final _judul     = TextEditingController();
  final _instruksi = TextEditingController();
  final _link      = TextEditingController();
  String? _selMapel, _selKelas, _selKategori;
  Set<String> _selTargetKelas = {};

  // --- Pengaturan ---
  bool _anti = true, _cam = true, _auto = true;
  int  _max  = 3;
  int  _kkm  = 0; // 0 = tidak aktif
  String _spiType = 'reguler'; // reguler, susulan, remedial
  String? _parentExamId;
  DateTime  _tgl      = DateTime.now();
  TimeOfDay _jamStart = TimeOfDay.now();
  TimeOfDay _jamEnd   = const TimeOfDay(hour: 10, minute: 0);

  // --- State soal ---
  String? _savedExamId;
  String? _soalMethod; // 'manual' | 'template'
  final List<SoalDraft> _soals = [];
  bool _uploading = false;
  int  _editingIndex = -1;
  final _scrollCtrl = ScrollController();

  // --- Docx import state ---
  bool   _docxParsing  = false;
  String? _docxFileName;
  bool   _docxParsed   = false;

  @override
  void dispose() {
    _judul.dispose(); _instruksi.dispose(); _link.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Simpan ujian ke Firestore ──
  Future<bool> _saveExam({bool asDraft = false}) async {
    if (_judul.text.trim().isEmpty || _selMapel == null || _selKelas == null) {
      _snack("Lengkapi semua data ujian!", Colors.orange); return false;
    }
    if (!_isNative && _link.text.trim().isEmpty) {
      _snack("Link soal wajib diisi!", Colors.orange); return false;
    }
    final start = DateTime(_tgl.year, _tgl.month, _tgl.day, _jamStart.hour, _jamStart.minute);
    final end   = DateTime(_tgl.year, _tgl.month, _tgl.day, _jamEnd.hour,   _jamEnd.minute);
    if (end.isBefore(start)) {
      _snack("Waktu selesai harus setelah waktu mulai!", Colors.red); return false;
    }
    setState(() => _uploading = true);
    try {
      final data = {
        'judul'      : _judul.text.trim(),
        'mapel'      : _selMapel,
        'jenjang'    : _selKelas,
        'antiCurang' : _anti,
        'maxCurang'  : _max,
        'kameraAktif': _cam,
        'autoSubmit' : _auto,
        'waktuMulai' : Timestamp.fromDate(start),
        'waktuSelesai': Timestamp.fromDate(end),
        'instruksi'  : _instruksi.text.trim(),
        'link'       : _isNative ? '' : _link.text.trim(),
        'mode'       : _isNative ? 'native' : 'form',
        'jumlahSoal' : 0,
        'createdAt'  : FieldValue.serverTimestamp(),
        'status'     : asDraft ? 'draft' : 'published',
        'kategori'   : _selKategori ?? '',
        'creatorName': widget.creatorName ?? '',
        'targetKelas': _selTargetKelas.toList(),
        'kkm': _kkm,
        'spiType': _spiType,
        if (_parentExamId != null) 'parentExamId': _parentExamId,
      };
      if (_savedExamId != null) {
        await FirebaseFirestore.instance.collection('exam').doc(_savedExamId).update(data);
      } else {
        final doc = await FirebaseFirestore.instance.collection('exam').add(data);
        _savedExamId = doc.id;
      }
      setState(() => _uploading = false);
      return true;
    } catch (e) {
      setState(() => _uploading = false);
      _snack("Gagal menyimpan: $e", Colors.red);
      return false;
    }
  }

  // ── Dialog konfirmasi terbitkan ──
  void _showTerbitkanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.publish, color: Colors.blue, size: 40),
        title: const Text("Terbitkan Soal?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("${_soals.length} soal akan disimpan dan diterbitkan.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text(
                "Pastikan semua soal sudah dicek sebelum diterbitkan.\nSoal yang sudah diterbitkan akan langsung tersedia di ujian.",
                style: TextStyle(fontSize: 12, color: Colors.black87),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _uploadSoal();
            },
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text("Terbitkan"),
          ),
        ],
      ),
    );
  }

  // ── Upload soal ke Firestore ──
  Future<void> _uploadSoal() async {
    if (_soals.isEmpty)       { _snack("Belum ada soal!", Colors.orange); return; }
    if (_savedExamId == null) { _snack("Data ujian belum tersimpan!", Colors.red); return; }
    for (int i = 0; i < _soals.length; i++) {
      final s = _soals[i];
      if (s.pertanyaan.trim().isEmpty && s.gambarBase64 == null) {
        _snack("Soal ${i+1} belum ada pertanyaan!", Colors.orange); return;
      }
      if (s.tipe == TipeSoal.pilihanGanda) {
        if (s.pilihan.where((p) => p.trim().isNotEmpty).length < 2) {
          _snack("Soal ${i+1}: minimal 2 pilihan!", Colors.orange); return;
        }
        if (s.kunciJawaban.isEmpty) {
          _snack("Soal ${i+1}: belum ada kunci!", Colors.orange); return;
        }
      } else if (s.tipe == TipeSoal.benarSalah && s.kunciJawaban.isEmpty) {
        _snack("Soal ${i+1}: tentukan Benar/Salah!", Colors.orange); return;
      }
    }
    setState(() => _uploading = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('exam').doc(_savedExamId).collection('soal');
      final old   = await ref.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var d in old.docs) batch.delete(d.reference);
      await batch.commit();

      for (int i = 0; i < _soals.length; i++) {
        final s      = _soals[i];
        final piOpts = s.tipe == TipeSoal.pilihanGanda
            ? s.pilihan.asMap().entries
            .where((e) => e.value.trim().isNotEmpty)
            .map((e) => '${String.fromCharCode(65 + e.key)}. ${e.value}')
            .toList()
            : <String>[];
        await ref.add({
          'nomor'       : i + 1,
          'tipe'        : s.tipe.name,
          'pertanyaan'  : s.pertanyaan.trim(),
          'gambar'      : s.gambarBase64 ?? '',
          'pilihan'     : piOpts,
          'kunciJawaban': s.kunciJawaban.toUpperCase(),
          'skor'        : s.skor,
        });
      }
      await FirebaseFirestore.instance.collection('exam').doc(_savedExamId)
          .update({'mode': 'native', 'jumlahSoal': _soals.length});

      setState(() { _uploading = false; _step = 99; });
      _snack("${_soals.length} soal berhasil diupload!", Colors.green);
    } catch (e) {
      setState(() => _uploading = false);
      _snack("Gagal upload soal: $e", Colors.red);
    }
  }

  // ── Load soal existing dari Firestore (untuk edit soal ujian yang sudah ada) ──
  Future<void> _loadSoalFromExam(String examId) async {
    setState(() { _soals.clear(); _editingIndex = -1; });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('exam').doc(examId).collection('soal')
          .orderBy('nomor').get();
      for (final d in snap.docs) {
        final data     = d.data();
        final tipeStr  = data['tipe'] ?? 'pilihanGanda';
        final tipe     = tipeStr == 'benarSalah' ? TipeSoal.benarSalah
            : tipeStr == 'uraian' ? TipeSoal.uraian
            : TipeSoal.pilihanGanda;
        final pilihanRaw = List<String>.from(data['pilihan'] ?? []);
        final pilihan = List<String>.generate(4, (i) {
          if (i < pilihanRaw.length) {
            final p = pilihanRaw[i];
            final idx = p.indexOf('.');
            return idx >= 0 ? p.substring(idx + 1).trim() : p;
          }
          return '';
        });
        _soals.add(SoalDraft(
          tipe          : tipe,
          pertanyaan    : data['pertanyaan'] ?? '',
          gambarBase64  : (data['gambar'] ?? '').isNotEmpty ? data['gambar'] : null,
          pilihan       : pilihan,
          kunciJawaban  : data['kunciJawaban'] ?? '',
          skor          : data['skor'] ?? 1,
        ));
      }
      if (_soals.isEmpty) _soals.add(SoalDraft());
      setState(() {});
      _snack(_soals.length == 1 && _soals[0].pertanyaan.isEmpty
          ? 'Belum ada soal. Silakan tambahkan.'
          : '${_soals.length} soal dimuat!', Colors.teal);
    } catch (e) {
      _snack('Gagal memuat soal: $e', Colors.red);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF1F5F9),
    child: Column(children: [
      _buildHeader(),
      Expanded(child: _buildStep()),
    ]),
  );

  // ── Header progress ──
  Widget _buildHeader() {
    final labels = _isNative
        ? ['Mode', 'Data', 'Pengaturan', 'Soal']
        : ['Mode', 'Data', 'Pengaturan'];
    int cur = _step.clamp(0, labels.length - 1);
    if (_step == 99) cur = labels.length - 1;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _step == 0  ? "Buat Ujian Baru"
              : _step == 1 ? "Data Ujian"
              : _step == 2 ? "Pengaturan Ujian"
              : _step == 3 ? "Metode Soal"
              : _step >= 4 ? "Buat Soal"
              : "Selesai",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Row(children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(child: Divider(
              color: cur > i ~/ 2 ? const Color(0xFF0F172A) : Colors.grey.shade300,
              thickness: 2,
            ));
          }
          final idx    = i ~/ 2;
          final active = cur >= idx;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: active ? const Color(0xFF0F172A) : Colors.grey.shade200,
              child: Text("${idx+1}", style: TextStyle(
                  color: active ? Colors.white : Colors.grey,
                  fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 2),
            Text(labels[idx], style: TextStyle(
                fontSize: 9,
                color: active ? const Color(0xFF0F172A) : Colors.grey)),
          ]);
        })),
      ]),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:  return _stepMode();
      case 1:  return _stepData();
      case 2:  return _stepPengaturan();
      case 3:  return _stepPilihMetode();
      case 4:  return _soalMethod == 'template' ? _stepDocxImport() : _stepSoalEditor();
      case 99: return _stepSelesai();
      default: return const SizedBox();
    }
  }

  // ============================================================
  // STEP 0: PILIH MODE
  // ============================================================
  Widget _stepMode() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const SizedBox(height: 8),
      const Text("Pilih mode pembuatan soal",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text("Pilih metode yang akan digunakan untuk ujian ini.",
          style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      _modeCard(
        selected  : !_isNative,
        icon      : Icons.link,
        iconBg    : Colors.blue.shade50,
        iconColor : Colors.blue,
        title     : "Via Google Form",
        subtitle  : "Soal dibuat di Google Forms. Siswa mengerjakan via link yang kamu berikan.",
        badge     : "Mudah & Cepat",
        badgeColor: Colors.blue,
        onTap     : () => setState(() => _isNative = false),
      ),
      const SizedBox(height: 14),
      _modeCard(
        selected  : _isNative,
        icon      : Icons.edit_note,
        iconBg    : Colors.teal.shade50,
        iconColor : Colors.teal,
        title     : "Via Aplikasi",
        subtitle  : "Buat soal langsung di dalam aplikasi. Nilai dihitung otomatis.",
        badge     : "Nilai Otomatis",
        badgeColor: Colors.teal,
        onTap     : () => setState(() => _isNative = true),
      ),
      const SizedBox(height: 36),
      SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => setState(() => _step = 1),
          icon : const Icon(Icons.arrow_forward),
          label: const Text("LANJUT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    ]),
  );

  Widget _modeCard({
    required bool selected, required IconData icon,
    required Color iconBg, required Color iconColor,
    required String title, required String subtitle,
    required String badge, required Color badgeColor,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: selected ? const Color(0xFF0F172A) : Colors.grey.shade200,
            width: selected ? 2.5 : 1),
        boxShadow: selected ? [BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(badge, style: TextStyle(
                  color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4)),
        ])),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 20, height: 20,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? const Color(0xFF0F172A) : Colors.transparent,
              border: Border.all(
                  color: selected ? const Color(0xFF0F172A) : Colors.grey.shade300, width: 2)),
          child: selected ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
        ),
      ]),
    ),
  );

  // ── Selector kelas spesifik ──────────────────────────────────
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
          label: Text('Kelas $c'),
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
  Widget _stepData() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Badge mode aktif
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isNative ? Colors.teal.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isNative ? Icons.edit_note : Icons.link,
                  color: _isNative ? Colors.teal : Colors.blue, size: 13),
              const SizedBox(width: 4),
              Text(_isNative ? "Via Aplikasi" : "Via Google Form",
                  style: TextStyle(
                      color: _isNative ? Colors.teal : Colors.blue,
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 16),
          _field("Judul Ujian / Penilaian", _judul, icon: Icons.title),
          const SizedBox(height: 14),
          _buildMapelDrop(),
          const SizedBox(height: 14),
          _drop("Pilih Jenjang / Kelas", _selKelas,
              ["Kelas 7", "Kelas 8", "Kelas 9"],
                  (v) => setState(() { _selKelas = v; _selTargetKelas = {}; })),
          if (_selKelas != null) ...[
            const SizedBox(height: 14),
            _buildTargetKelasSelector(),
          ],
          const SizedBox(height: 14),
          _drop("Kategori Ujian", _selKategori,
              ["Sumatif", "Formatif", "Harian", "UTS", "UAS"],
                  (v) => setState(() => _selKategori = v)),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() => _step = 0),
              icon : const Icon(Icons.arrow_back, size: 16),
              label: const Text("KEMBALI"),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50)),
              onPressed: () {
                if (_judul.text.trim().isEmpty || _selMapel == null || _selKelas == null) {
                  _snack("Lengkapi semua data!", Colors.orange); return;
                }
                setState(() => _step = 2);
              },
              icon : const Icon(Icons.arrow_forward),
              label: const Text("LANJUT"),
            )),
          ]),
        ]),
      ),
    ),
  );

  // ============================================================
  // STEP 2: PENGATURAN
  // ============================================================
  Widget _stepPengaturan() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      // ── Keamanan ──
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pengaturan Keamanan",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, secondary: const Icon(Icons.security),
              title   : const Text("Anti Curang"),
              subtitle: const Text("Kunci layar jika siswa keluar aplikasi"),
              value: _anti, onChanged: (v) => setState(() => _anti = v),
            ),
            if (_anti) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text("Maks. Pelanggaran: $_max kali",
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ]),
              ),
              Slider(value: _max.toDouble(), min: 1, max: 10, divisions: 9,
                  label: "$_max", activeColor: Colors.orange,
                  onChanged: (v) => setState(() => _max = v.toInt())),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero, secondary: const Icon(Icons.videocam),
              title   : const Text("Kamera Monitor"),
              subtitle: const Text("Ambil foto siswa secara berkala"),
              value: _cam, onChanged: (v) => setState(() => _cam = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, secondary: const Icon(Icons.send),
              title   : const Text("Auto Submit"),
              subtitle: const Text("Submit otomatis saat waktu habis"),
              value: _auto, onChanged: (v) => setState(() => _auto = v),
            ),
            const Divider(height: 16),
            // KKM
            Row(children: [
              const Icon(Icons.verified, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text("KKM (Kriteria Ketuntasan)",
                  style: TextStyle(fontWeight: FontWeight.w500))),
              SizedBox(
                width: 60,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                    hintText: '0',
                  ),
                  controller: TextEditingController(text: _kkm > 0 ? '$_kkm' : ''),
                  onChanged: (v) => _kkm = int.tryParse(v) ?? 0,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(_kkm > 0 ? "Siswa di bawah $_kkm dianggap tidak tuntas" : "KKM tidak aktif (0)",
                style: TextStyle(fontSize: 11, color: _kkm > 0 ? Colors.teal : Colors.grey)),
            const Divider(height: 16),
            // Tipe Sesi
            Row(children: [
              const Icon(Icons.event_repeat, color: Color(0xFF0F172A), size: 20),
              const SizedBox(width: 8),
              const Text("Tipe Sesi", style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              SegmentedButton<String>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 11)),
                ),
                segments: const [
                  ButtonSegment(value: 'reguler', label: Text('Reguler')),
                  ButtonSegment(value: 'susulan', label: Text('Susulan')),
                  ButtonSegment(value: 'remedial', label: Text('Remedial')),
                ],
                selected: {_spiType},
                onSelectionChanged: (v) => setState(() => _spiType = v.first),
              ),
            ]),
          ],
        )),
      ),
      const SizedBox(height: 12),

      // ── Jadwal ──
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Jadwal Ujian",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading  : const Icon(Icons.calendar_month, color: Color(0xFF0F172A)),
              title    : const Text("Tanggal"),
              subtitle : Text(DateFormat('dd MMMM yyyy').format(_tgl)),
              trailing : const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                final p = await showDatePicker(context: context,
                    initialDate: _tgl, firstDate: DateTime.now(), lastDate: DateTime(2030));
                if (p != null) setState(() => _tgl = p);
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading  : const Icon(Icons.timer, color: Colors.green),
              title    : const Text("Waktu Mulai"),
              subtitle : Text(_jamStart.format(context)),
              trailing : const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                final p = await showTimePicker(context: context, initialTime: _jamStart);
                if (p != null) setState(() => _jamStart = p);
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading  : const Icon(Icons.timer_off, color: Colors.red),
              title    : const Text("Waktu Selesai"),
              subtitle : Text(_jamEnd.format(context)),
              trailing : const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                final p = await showTimePicker(context: context, initialTime: _jamEnd);
                if (p != null) setState(() => _jamEnd = p);
              },
            ),
          ],
        )),
      ),
      const SizedBox(height: 12),

      // ── Konten soal ──
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Konten Soal",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 16),
            _field("Instruksi untuk Siswa", _instruksi, maxL: 4, icon: Icons.info_outline),
            // Link hanya muncul untuk mode Google Form
            if (!_isNative) ...[
              const SizedBox(height: 12),
              _field("Link Soal (Google Form / URL)", _link, icon: Icons.link),
            ],
          ],
        )),
      ),
      const SizedBox(height: 20),

      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: () => setState(() => _step = 1),
          icon : const Icon(Icons.arrow_back, size: 16),
          label: const Text("KEMBALI"),
        )),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 50)),
          onPressed: _uploading ? null : () async {
            final ok = await _saveExam(asDraft: true);
            if (!ok) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Draft tersimpan!'), backgroundColor: Colors.orange));
          },
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text("DRAFT"),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _isNative ? Colors.teal : Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 50)),
          onPressed: _uploading ? null : () async {
            final ok = await _saveExam();
            if (!ok) return;
            setState(() => _step = _isNative ? 3 : 99);
          },
          icon: _uploading
              ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Icon(_isNative ? Icons.arrow_forward : Icons.cloud_upload),
          label: Text(_uploading
              ? "Menyimpan..."
              : _isNative ? "MULAI UPLOAD SOAL" : "UPLOAD UJIAN"),
        )),
      ]),
      const SizedBox(height: 20),
    ]),
  );

  // ============================================================
  // STEP 3: PILIH METODE SOAL (native only)
  // ============================================================
  Widget _stepPilihMetode() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const SizedBox(height: 8),
      const Icon(Icons.quiz, size: 48, color: Color(0xFF0F172A)),
      const SizedBox(height: 14),
      const Text("Bagaimana cara membuat soal?",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text("Pilih metode yang paling sesuai.",
          style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 28),
      _modeCard(
        selected  : _soalMethod == 'manual',
        icon      : Icons.edit,
        iconBg    : Colors.indigo.shade50,
        iconColor : Colors.indigo,
        title     : "Buat Soal Manual",
        subtitle  : "Tulis soal satu per satu langsung di aplikasi. Mendukung PG, Benar/Salah, dan Uraian.",
        badge     : "Lebih Fleksibel",
        badgeColor: Colors.indigo,
        onTap     : () => setState(() => _soalMethod = 'manual'),
      ),
      const SizedBox(height: 14),
      _modeCard(
        selected  : _soalMethod == 'template',
        icon      : Icons.upload_file,
        iconBg    : Colors.orange.shade50,
        iconColor : Colors.orange,
        title     : "Upload Template Word",
        subtitle  : "Buat soal di file .docx sesuai template BM-Exam, lalu upload ke aplikasi.",
        badge     : "Banyak Soal Sekaligus",
        badgeColor: Colors.orange,
        onTap     : () => setState(() => _soalMethod = 'template'),
      ),
      const SizedBox(height: 14),
      _modeCard(
        selected  : _soalMethod == 'bank',
        icon      : Icons.library_books,
        iconBg    : Colors.teal.shade50,
        iconColor : Colors.teal,
        title     : "Tarik dari Bank Soal",
        subtitle  : "Ambil soal dari Bank Soal yang sudah tersimpan. Pilih manual atau otomatis.",
        badge     : "Cepat & Terstruktur",
        badgeColor: Colors.teal,
        onTap     : () => setState(() => _soalMethod = 'bank'),
      ),
      const SizedBox(height: 36),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: () => setState(() => _step = 2),
          icon : const Icon(Icons.arrow_back, size: 16),
          label: const Text("KEMBALI"),
        )),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
              minimumSize: const Size(0, 50)),
          onPressed: _soalMethod == null ? null : () async {
            if (_soalMethod == 'bank') {
              // Save exam first if needed
              if (_savedExamId == null) {
                final ok = await _saveExam(asDraft: true);
                if (!ok) return;
              }
              if (!mounted) return;
              final drafts = await showBankSoalPickerDialog(context, mapel: _selMapel, filterMapel: widget.allowedMapel);
              if (drafts != null && drafts.isNotEmpty) {
                setState(() {
                  _soals.addAll(drafts);
                  _editingIndex = 0;
                  _soalMethod = 'manual';
                  _step = 4;
                });
                _snack("${drafts.length} soal ditarik dari Bank Soal!", Colors.green);
              }
            } else {
              setState(() => _step = 4);
            }
          },
          icon : const Icon(Icons.arrow_forward),
          label: const Text("LANJUT"),
        )),
      ]),
    ]),
  );

  // ============================================================
  // STEP 4a: EDITOR SOAL MANUAL
  // ============================================================
  Widget _stepSoalEditor() {
    if (_soals.isEmpty) { _soals.add(SoalDraft()); _editingIndex = 0; }
    return Column(children: [
      // Banner: switch ke template or bank
      Container(
        color: Colors.orange.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.upload_file, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text("Upload template Word atau tarik dari Bank Soal?",
              style: TextStyle(color: Colors.orange, fontSize: 12))),
          TextButton(
            onPressed: () => setState(() { _soalMethod = 'template'; _docxParsed = false; }),
            child: const Text("Template",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 11)),
          ),
          TextButton(
            onPressed: () async {
              final drafts = await showBankSoalPickerDialog(context, mapel: _selMapel, filterMapel: widget.allowedMapel);
              if (drafts != null && drafts.isNotEmpty) {
                setState(() { _soals.addAll(drafts); _editingIndex = 0; });
                _snack("${drafts.length} soal ditarik dari Bank Soal!", Colors.green);
              }
            },
            child: const Text("Bank Soal",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 11)),
          ),
        ]),
      ),
      // Info jumlah soal
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 14, color: Colors.teal),
          const SizedBox(width: 6),
          Text("${_soals.length} soal  •  Ketuk soal untuk edit",
              style: const TextStyle(fontSize: 11, color: Colors.teal)),
        ]),
      ),
      // Daftar soal
      Expanded(
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
          itemCount: _soals.length,
          itemBuilder: (c, i) => _SoalCard(
            index     : i,
            total     : _soals.length,
            draft     : _soals[i],
            isEditing : _editingIndex == i,
            onTap     : () => setState(() => _editingIndex = _editingIndex == i ? -1 : i),
            onDelete  : () => _deleteSoal(i),
            onMoveUp  : i > 0                 ? () => _moveSoal(i, -1) : null,
            onMoveDown: i < _soals.length - 1 ? () => _moveSoal(i,  1) : null,
            onChanged : () => setState(() {}),
          ),
        ),
      ),
      // Bottom bar
      Container(
        padding: const EdgeInsets.all(12), color: Colors.white,
        child: Row(children: [
          OutlinedButton.icon(
            onPressed: _addSoal,
            icon : const Icon(Icons.add, size: 16),
            label: const Text("Tambah Soal"),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: _soals.isNotEmpty ? () => _showPreviewDialog() : null,
            icon : const Icon(Icons.visibility, size: 16),
            label: const Text("Preview"),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.deepPurple),
          ),
          const SizedBox(width: 6),
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white,
                minimumSize: const Size(0, 46)),
            onPressed: _uploading ? null : _showTerbitkanDialog,
            icon: _uploading
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.publish),
            label: Text(_uploading ? "Menyimpan..." : "Terbitkan ${_soals.length} Soal"),
          )),
        ]),
      ),
    ]);
  }

  // ============================================================
  // STEP 4b: UPLOAD DOCX TEMPLATE
  // ============================================================
  Widget _stepDocxImport() {
    // Setelah parse berhasil → tampilkan editor soal langsung
    if (_docxParsed && _soals.isNotEmpty) return _stepSoalEditor();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Banner: switch ke manual
        Container(
          decoration: BoxDecoration(
              color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            const Icon(Icons.edit, color: Colors.indigo, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text("Ingin buat soal manual saja?",
                style: TextStyle(color: Colors.indigo, fontSize: 12))),
            TextButton(
              onPressed: () => setState(() { _soalMethod = 'manual'; _docxParsed = false; }),
              child: const Text("Buat Manual",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Format guide
        Card(
          color: Colors.amber.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.amber.shade300)),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text("Format Template Word", style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  "[PILIHAN GANDA]\n1. Soal...\nA. Pilihan A\nB. Pilihan B\nC. Pilihan C\nD. Pilihan D\nJAWABAN: B\n\n"
                      "[BENAR SALAH]\n1. Pernyataan...\nJAWABAN: BENAR\n\n"
                      "[URAIAN]\n1. Soal uraian...\nSKOR: 10",
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 6),
              const Text("* Mendukung rumus LaTeX: \$\\frac{a}{b}\$",
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          )),
        ),
        const SizedBox(height: 20),

        // Upload area
        GestureDetector(
          onTap: _docxParsing ? null : _pickDocx,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.shade300, width: 2, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(16),
              color: Colors.blue.shade50,
            ),
            child: _docxParsing
                ? const Column(children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text("Memproses file...", style: TextStyle(color: Colors.grey)),
            ])
                : Column(children: [
              Icon(_docxFileName != null ? Icons.check_circle : Icons.upload_file,
                  size: 50,
                  color: _docxFileName != null ? Colors.green : Colors.blue),
              const SizedBox(height: 10),
              Text(
                _docxFileName ?? "Tap untuk pilih file .docx",
                style: TextStyle(
                    color: _docxFileName != null ? Colors.green.shade700 : Colors.blue,
                    fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text("Format: .docx (Microsoft Word)",
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // ── Divider "Atau" ──
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('Atau', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 16),

        // ── Upload Otomatis dari Word ──
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade600, Colors.green.shade700],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.upload_file, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Upload Otomatis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Tanpa internet — instan', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ]),
            const SizedBox(height: 12),
            const Text(
              'Upload soal dari Word format apapun. Soal bernomor, pilihan A-D, gambar, equation, dan kunci jawaban dideteksi otomatis.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _docxParsing ? null : _pickDocxLocal,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Pilih File .docx', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _pickDocxLocal() async {
    setState(() => _docxParsing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['docx'], withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _docxParsing = false); return;
      }
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        _snack('Gagal membaca file', Colors.red);
        setState(() => _docxParsing = false); return;
      }

      final drafts = DocxLocalParser.parseLocal(bytes);
      _soals.clear();
      _soals.addAll(drafts);

      setState(() {
        _docxFileName = result.files.first.name;
        _docxParsing  = false;
        _docxParsed   = drafts.isNotEmpty;
        _editingIndex = -1;
      });

      if (drafts.isEmpty) {
        _snack('Tidak ada soal ditemukan. Pastikan soal bernomor (1. 2. 3.) dengan pilihan A-D.', Colors.orange);
      } else {
        final withKey = drafts.where((d) => d.kunciJawaban.isNotEmpty).length;
        final withImg = drafts.where((d) => d.gambarBase64 != null).length;
        _snack('${drafts.length} soal ($withKey kunci, $withImg gambar). Cek & edit sebelum upload.', Colors.green);
      }
    } catch (e) {
      setState(() => _docxParsing = false);
      _snack('Gagal: $e', Colors.red);
    }
  }

  Future<void> _pickDocx() async {
    setState(() => _docxParsing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['docx'], withData: true);
      if (result == null || result.files.isEmpty) {
        setState(() => _docxParsing = false); return;
      }
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        _snack("Gagal membaca file", Colors.red);
        setState(() => _docxParsing = false); return;
      }
      final soalModels = await compute(_parseDocxIsolate, bytes);
      _soals.clear();
      for (final s in soalModels) {
        final pilihanTeks = s.pilihan.map((p) {
          final idx = p.indexOf('.');
          return idx >= 0 ? p.substring(idx + 1).trim() : p;
        }).toList();
        while (pilihanTeks.length < 4) pilihanTeks.add('');
        _soals.add(SoalDraft(
          tipe        : s.tipe,
          pertanyaan  : s.pertanyaan,
          gambarBase64: s.gambar.isNotEmpty ? s.gambar : null,
          pilihan     : pilihanTeks,
          kunciJawaban: s.kunciJawaban,
          skor        : s.skor,
        ));
      }
      setState(() {
        _docxFileName = result.files.first.name;
        _docxParsing  = false;
        _docxParsed   = soalModels.isNotEmpty;
        _editingIndex = -1;
      });
      if (soalModels.isEmpty) {
        _snack("Tidak ada soal. Cek format template!", Colors.orange);
      } else {
        _snack("${soalModels.length} soal berhasil diparsing! Cek & edit sebelum upload.", Colors.green);
      }
    } catch (e) {
      setState(() => _docxParsing = false);
      _snack("Error: $e", Colors.red);
    }
  }

  static List<SoalModel> _parseDocxIsolate(Uint8List bytes) => DocxParser.parse(bytes);


  // ============================================================
  // STEP 99: SELESAI
  // ============================================================
  Widget _stepSelesai() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 90, height: 90,
          decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        ),
        const SizedBox(height: 20),
        Text(
          _isNative ? "Ujian & Soal Berhasil Dibuat!" : "Ujian Berhasil Diupload!",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _isNative
              ? "${_soals.length} soal tersimpan untuk \"${_judul.text}\""
              : "Ujian \"${_judul.text}\" telah dijadwalkan.",
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => setState(() {
              _step = 0; _isNative = false; _savedExamId = null;
              _soalMethod = null; _soals.clear();
              _docxParsed = false; _docxFileName = null; _editingIndex = -1;
              _judul.clear(); _instruksi.clear(); _link.clear();
              _selMapel = null; _selKelas = null;
            }),
            icon : const Icon(Icons.add),
            label: const Text("Buat Ujian Lagi"),
          ),
        ),
        const SizedBox(height: 12),
        // Tombol edit soal lagi (hanya native, setelah ujian tersimpan)
        if (_isNative && _savedExamId != null)
          OutlinedButton.icon(
            onPressed: () => setState(() => _step = 4),
            icon : const Icon(Icons.edit),
            label: const Text("Edit Soal Lagi"),
          ),
      ]),
    ),
  );

  // ── Preview dialog — simulasi tampilan soal di layar siswa ──
  void _showPreviewDialog() {
    int previewIdx = 0;
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPreview) {
          final s = _soals[previewIdx];
          final tipeLabel = s.tipe == TipeSoal.pilihanGanda ? 'Pilihan Ganda'
              : s.tipe == TipeSoal.benarSalah ? 'Benar/Salah' : 'Uraian';
          final tipeColor = s.tipe == TipeSoal.pilihanGanda ? Colors.blue
              : s.tipe == TipeSoal.benarSalah ? Colors.green : Colors.orange;
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              title: const Text("Preview Soal", style: TextStyle(fontSize: 16)),
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              actions: [
                Center(child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text("${previewIdx + 1} / ${_soals.length}",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                )),
              ],
            ),
            body: Column(children: [
              // Progress
              LinearProgressIndicator(
                value: (previewIdx + 1) / _soals.length,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 4,
              ),
              // Soal content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Tipe badge + skor
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tipeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tipeLabel, style: TextStyle(
                            color: tipeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text("Skor: ${s.skor}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                    const SizedBox(height: 12),

                    // Pertanyaan card
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("Soal ${previewIdx + 1}",
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          if (s.pertanyaan.isNotEmpty)
                            _buildTextWithLatex(s.pertanyaan, 16),
                          if (s.gambarBase64 != null) ...[
                            const SizedBox(height: 10),
                            _buildZoomableImage(base64Decode(s.gambarBase64!), context),
                          ],
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pilihan jawaban
                    if (s.tipe == TipeSoal.pilihanGanda) ...[
                      ...List.generate(s.pilihan.length, (i) {
                        if (s.pilihan[i].trim().isEmpty) return const SizedBox.shrink();
                        final letter = String.fromCharCode(65 + i);
                        final isKunci = s.kunciJawaban == letter;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isKunci ? Colors.green.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isKunci ? Colors.green : Colors.grey.shade300,
                              width: isKunci ? 2 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: isKunci ? Colors.green : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(child: Text(letter, style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12,
                                  color: isKunci ? Colors.white : Colors.grey.shade600))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextWithLatex(s.pilihan[i], 14)),
                            if (isKunci)
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          ]),
                        );
                      }),
                    ],
                    if (s.tipe == TipeSoal.benarSalah) ...[
                      Row(children: [
                        Expanded(child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: s.kunciJawaban == 'BENAR' ? Colors.green.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: s.kunciJawaban == 'BENAR' ? Colors.green : Colors.grey.shade300,
                              width: s.kunciJawaban == 'BENAR' ? 2 : 1),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.check_circle_outline, color: s.kunciJawaban == 'BENAR' ? Colors.green : Colors.grey),
                            const SizedBox(width: 8),
                            Text("BENAR", style: TextStyle(fontWeight: FontWeight.bold,
                                color: s.kunciJawaban == 'BENAR' ? Colors.green : Colors.grey)),
                          ]),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: s.kunciJawaban == 'SALAH' ? Colors.red.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: s.kunciJawaban == 'SALAH' ? Colors.red : Colors.grey.shade300,
                              width: s.kunciJawaban == 'SALAH' ? 2 : 1),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.cancel_outlined, color: s.kunciJawaban == 'SALAH' ? Colors.red : Colors.grey),
                            const SizedBox(width: 8),
                            Text("SALAH", style: TextStyle(fontWeight: FontWeight.bold,
                                color: s.kunciJawaban == 'SALAH' ? Colors.red : Colors.grey)),
                          ]),
                        )),
                      ]),
                    ],
                    if (s.tipe == TipeSoal.uraian) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text("Siswa akan menulis jawaban di sini...",
                            style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                      ),
                    ],

                    // Kunci jawaban indicator
                    if (s.kunciJawaban.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(children: [
                          const Icon(Icons.vpn_key, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text("Kunci Jawaban: ${s.kunciJawaban}",
                              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Row(children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Text("Kunci jawaban belum diatur",
                              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ),

              // Navigasi
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
                        final isActive = i == previewIdx;
                        final hasKunci = _soals[i].kunciJawaban.isNotEmpty;
                        return GestureDetector(
                          onTap: () => setPreview(() => previewIdx = i),
                          child: Container(
                            width: 30, height: 30,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF0F172A)
                                  : hasKunci ? Colors.green.shade100
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActive ? const Color(0xFF0F172A)
                                    : hasKunci ? Colors.green
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text("${i + 1}",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isActive ? Colors.white
                                          : hasKunci ? Colors.green.shade700
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
                    if (previewIdx > 0)
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => setPreview(() => previewIdx--),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text("Sebelumnya"),
                      )),
                    if (previewIdx > 0) const SizedBox(width: 10),
                    if (previewIdx < _soals.length - 1)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white),
                          onPressed: () => setPreview(() => previewIdx++),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text("Selanjutnya"),
                        ),
                      ),
                    if (previewIdx == _soals.length - 1)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.edit),
                          label: const Text("Kembali ke Editor"),
                        ),
                      ),
                  ]),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Helpers soal editor ──
  void _addSoal() {
    setState(() { _soals.add(SoalDraft()); _editingIndex = _soals.length - 1; });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _deleteSoal(int idx) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title  : const Text("Hapus Soal?"),
      content: Text("Hapus soal nomor ${idx + 1}?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
        ElevatedButton(
          style    : ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              _soals.removeAt(idx);
              if (_editingIndex == idx) _editingIndex = -1;
              else if (_editingIndex > idx) _editingIndex--;
              if (_soals.isEmpty) { _soals.add(SoalDraft()); _editingIndex = 0; }
            });
          },
          child: const Text("Hapus"),
        ),
      ],
    ));
  }

  void _moveSoal(int idx, int delta) {
    final n = idx + delta;
    if (n < 0 || n >= _soals.length) return;
    setState(() {
      final tmp = _soals[idx]; _soals[idx] = _soals[n]; _soals[n] = tmp;
      if (_editingIndex == idx) _editingIndex = n;
      else if (_editingIndex == n) _editingIndex = idx;
    });
  }

  // ── Field/drop helpers ──
  Widget _field(String t, TextEditingController? c, {int? maxL, IconData? icon}) =>
      TextField(
        controller: c, maxLines: maxL,
        decoration: InputDecoration(
          labelText : t,
          border    : OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          prefixIcon: icon != null ? Icon(icon) : null,
          filled    : true, fillColor: Colors.grey.shade50,
        ),
      );

  Widget _buildMapelDrop() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('subjects').snapshots(),
    builder: (context, snap) {
      if (!snap.hasData) return const LinearProgressIndicator();
      var items = snap.data!.docs.map((d) => (d.data() as Map)['name'].toString()).toList();
      // Filter berdasarkan allowedMapel guru (jika bukan admin)
      if (widget.allowedMapel != null && widget.allowedMapel!.isNotEmpty) {
        items = items.where((m) => widget.allowedMapel!.contains(m)).toList();
      }
      if (items.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Row(children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 16),
            SizedBox(width: 8),
            Text('Tidak ada mata pelajaran yang tersedia untuk akun Anda.',
                style: TextStyle(color: Colors.orange, fontSize: 12)),
          ]),
        );
      }
      // Auto-pilih jika hanya satu mapel
      if (items.length == 1 && _selMapel == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selMapel = items.first);
        });
      }
      return _drop("Mata Pelajaran", _selMapel, items, (v) => setState(() => _selMapel = v));
    },
  );

  Widget _drop(String t, String? v, List<String> items, Function(String?) onCh) =>
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText : t,
          border    : OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled    : true, fillColor: Colors.grey.shade50,
        ),
        value: v,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onCh,
      );
}


class _SoalCard extends StatefulWidget {
  final int index;
  final int total;
  final SoalDraft draft;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onChanged;

  const _SoalCard({
    required this.index,
    required this.total,
    required this.draft,
    required this.isEditing,
    required this.onTap,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    required this.onChanged,
  });

  @override
  State<_SoalCard> createState() => _SoalCardState();
}

class _SoalCardState extends State<_SoalCard> {
  late TextEditingController _pertanyaanCtrl;
  late List<TextEditingController> _pilihanCtrls;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _pertanyaanCtrl = TextEditingController(text: widget.draft.pertanyaan);
    _pilihanCtrls = List.generate(4, (i) =>
        TextEditingController(text: i < widget.draft.pilihan.length ? widget.draft.pilihan[i] : ''));
  }

  @override
  void didUpdateWidget(covariant _SoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      _pertanyaanCtrl.text = widget.draft.pertanyaan;
      final pilihan = widget.draft.pilihan;
      for (int i = 0; i < _pilihanCtrls.length; i++) {
        _pilihanCtrls[i].text = i < pilihan.length ? pilihan[i] : '';
      }
    }
  }

  @override
  void dispose() {
    _pertanyaanCtrl.dispose();
    for (var c in _pilihanCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result != null && result.files.first.bytes != null) {
        widget.draft.gambarBase64 = base64Encode(result.files.first.bytes!);
        widget.onChanged();
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
    setState(() => _pickingImage = false);
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final tipeColor = draft.tipe == TipeSoal.pilihanGanda ? Colors.blue
        : draft.tipe == TipeSoal.benarSalah ? Colors.green : Colors.orange;
    final tipeLabel = draft.tipe == TipeSoal.pilihanGanda ? "Pilihan Ganda"
        : draft.tipe == TipeSoal.benarSalah ? "Benar/Salah" : "Uraian";

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: widget.isEditing ? const Color(0xFF0F172A) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header soal — tap untuk expand/collapse
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFF0F172A),
                child: Text("${widget.index + 1}",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: tipeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(tipeLabel, style: TextStyle(color: tipeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  draft.pertanyaan.isEmpty ? "Ketuk untuk mengisi soal..." : draft.pertanyaan,
                  style: TextStyle(
                      color: draft.pertanyaan.isEmpty ? Colors.grey : const Color(0xFF1E293B),
                      fontSize: 13,
                      fontStyle: draft.pertanyaan.isEmpty ? FontStyle.italic : FontStyle.normal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (draft.gambarBase64 != null)
                const Icon(Icons.image, color: Colors.teal, size: 16),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (widget.onMoveUp != null)
                  IconButton(icon: const Icon(Icons.arrow_upward, size: 16), onPressed: widget.onMoveUp,
                      constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                if (widget.onMoveDown != null)
                  IconButton(icon: const Icon(Icons.arrow_downward, size: 16), onPressed: widget.onMoveDown,
                      constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    onPressed: widget.onDelete,
                    constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                Icon(widget.isEditing ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
              ]),
            ]),
          ),
        ),

        // Form editing — hanya muncul kalau isEditing
        if (widget.isEditing) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Tipe soal selector
              const Text("Tipe Soal", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _tipePill("Pilihan Ganda", TipeSoal.pilihanGanda, Colors.blue),
                _tipePill("Benar/Salah", TipeSoal.benarSalah, Colors.green),
                _tipePill("Uraian", TipeSoal.uraian, Colors.orange),
              ]),
              const SizedBox(height: 14),

              // Pertanyaan
              const Text("Pertanyaan", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              TextField(
                controller: _pertanyaanCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Ketik pertanyaan di sini...\nGunakan \$rumus\$ untuk equation LaTeX",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: Colors.grey.shade50,
                ),
                onChanged: (v) {
                  draft.pertanyaan = v;
                  widget.onChanged();
                },
              ),

              // Preview LaTeX jika ada
              if (_pertanyaanCtrl.text.contains('\$')) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Preview:", style: TextStyle(fontSize: 10, color: Colors.blue)),
                    const SizedBox(height: 4),
                    _buildTextWithLatex(_pertanyaanCtrl.text, 14),
                  ]),
                ),
              ],
              const SizedBox(height: 12),

              // Gambar soal
              const Text("Gambar Soal (opsional)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              if (draft.gambarBase64 != null) ...[
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(draft.gambarBase64!),
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () { setState(() => draft.gambarBase64 = null); widget.onChanged(); },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ]),
              ] else
                GestureDetector(
                  onTap: _pickingImage ? null : _pickImage,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey.shade50,
                    ),
                    child: _pickingImage
                        ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                        : const Column(children: [
                      Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 32),
                      SizedBox(height: 6),
                      Text("Upload Gambar Soal (jpg/png)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                  ),
                ),
              const SizedBox(height: 14),

              // Pilihan jawaban
              if (draft.tipe == TipeSoal.pilihanGanda) ...[
                const Text("Pilihan Jawaban", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                ...List.generate(4, (i) {
                  final letter = String.fromCharCode(65 + i);
                  final isKunci = draft.kunciJawaban == letter;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isKunci ? Colors.green : Colors.grey.shade300,
                          width: isKunci ? 2 : 1),
                      color: isKunci ? Colors.green.shade50 : Colors.white,
                    ),
                    child: Row(children: [
                      // Tombol kunci jawaban
                      GestureDetector(
                        onTap: () {
                          setState(() => draft.kunciJawaban = isKunci ? '' : letter);
                          widget.onChanged();
                        },
                        child: Container(
                          width: 40,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isKunci ? Colors.green : Colors.grey.shade100,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                          ),
                          child: Center(
                            child: Text(letter, style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isKunci ? Colors.white : Colors.grey.shade600)),
                          ),
                        ),
                      ),
                      // Input teks pilihan
                      Expanded(
                        child: TextField(
                          controller: _pilihanCtrls[i],
                          decoration: InputDecoration(
                            hintText: "Pilihan $letter...",
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (v) {
                            while (draft.pilihan.length <= i) draft.pilihan.add('');
                            draft.pilihan[i] = v;
                            widget.onChanged();
                          },
                        ),
                      ),
                      if (isKunci)
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(Icons.check_circle, color: Colors.green, size: 18),
                        ),
                    ]),
                  );
                }),
                if (draft.kunciJawaban.isEmpty)
                  const Text("* Ketuk huruf (A/B/C/D) untuk menandai kunci jawaban",
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
              ],

              // Benar/Salah selector
              if (draft.tipe == TipeSoal.benarSalah) ...[
                const Text("Kunci Jawaban", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _bsSelectorBtn("BENAR", Colors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: _bsSelectorBtn("SALAH", Colors.red)),
                ]),
              ],

              // Uraian info
              if (draft.tipe == TipeSoal.uraian) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      "Soal uraian tidak memiliki kunci jawaban otomatis. Dikoreksi manual oleh guru.",
                      style: TextStyle(color: Colors.orange, fontSize: 11),
                    )),
                  ]),
                ),
              ],

              // Skor
              const SizedBox(height: 14),
              Row(children: [
                const Text("Skor: ", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: draft.skor > 1 ? () { setState(() => draft.skor--); widget.onChanged(); } : null,
                  constraints: const BoxConstraints(), padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                Text("${draft.skor}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                  onPressed: () { setState(() => draft.skor++); widget.onChanged(); },
                  constraints: const BoxConstraints(), padding: EdgeInsets.zero,
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _tipePill(String label, TipeSoal tipe, Color color) {
    final selected = widget.draft.tipe == tipe;
    return GestureDetector(
      onTap: () {
        setState(() {
          widget.draft.tipe = tipe;
          widget.draft.kunciJawaban = '';
        });
        widget.onChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade600,
            fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _bsSelectorBtn(String label, Color color) {
    final isSelected = widget.draft.kunciJawaban == label;
    return GestureDetector(
      onTap: () {
        setState(() => widget.draft.kunciJawaban = isSelected ? '' : label);
        widget.onChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(label == 'BENAR' ? Icons.check_circle : Icons.cancel,
              color: isSelected ? Colors.white : color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : color, fontSize: 14)),
        ]),
      ),
    );
  }
}


