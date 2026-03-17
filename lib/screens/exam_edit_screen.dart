part of '../main.dart';

// ============================================================
// HISTORY UJIAN — DETAIL
// ============================================================
// ============================================================
// EXAM EDIT SCREEN
// ============================================================
class ExamEditScreen extends StatefulWidget {
  final ExamData exam;
  final bool isReuse; // true = gunakan ulang, false = edit langsung
  final bool soalOnly; // true = langsung ke editor soal
  final List<SoalDraft>? initialSoals; // soal dari AI/template upload
  const ExamEditScreen({super.key, required this.exam, required this.isReuse,
    this.soalOnly = false, this.initialSoals});
  @override
  State<ExamEditScreen> createState() => _ExamEditScreenState();
}

class _ExamEditScreenState extends State<ExamEditScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _judulCtrl;
  late TextEditingController _linkCtrl;
  late TextEditingController _instruksiCtrl;
  late String _mapel;
  late String _jenjang;
  late DateTime _waktuMulai;
  late DateTime _waktuSelesai;
  late bool _antiCurang;
  late int _maxCurang;
  late bool _kameraAktif;
  late bool _autoSubmit;
  late int _kkm;
  late String _spiType;
  String? _parentExamId;
  bool _saving = false;
  List<String> _subjects = [];

  // ── Tab soal editor ──
  late TabController _tabCtrl;
  int _tabIndex = 0; // 0 = Info Ujian, 1 = Edit Soal
  final List<SoalDraft> _soals = [];
  int _editingIndex = -1;
  bool _soalLoading = false;
  bool _soalUploading = false;
  final _soalScrollCtrl = ScrollController();
  bool _isNativeExam = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) setState(() => _tabIndex = _tabCtrl.index); });
    final e = widget.exam;
    _judulCtrl = TextEditingController(text: e.judul);
    _linkCtrl = TextEditingController(text: e.link);
    _instruksiCtrl = TextEditingController(text: e.instruksi);
    _mapel = e.mapel;
    _jenjang = e.jenjang;
    _antiCurang = e.antiCurang;
    _maxCurang = e.maxCurang;
    _kameraAktif = e.kameraAktif;
    _autoSubmit = e.autoSubmit;
    _kkm = e.kkm;
    _spiType = e.spiType;
    _parentExamId = e.parentExamId;

    // Jika gunakan ulang, geser waktu ke hari ini
    if (widget.isReuse) {
      final now = DateTime.now();
      final durasi = e.waktuSelesai.difference(e.waktuMulai);
      _waktuMulai = DateTime(now.year, now.month, now.day,
          e.waktuMulai.hour, e.waktuMulai.minute);
      _waktuSelesai = _waktuMulai.add(durasi);
    } else {
      _waktuMulai = e.waktuMulai;
      _waktuSelesai = e.waktuSelesai;
    }
    _loadSubjects();

    // Jika soalOnly, langsung ke tab soal
    if (widget.soalOnly) {
      _isNativeExam = true;
      _tabCtrl.index = 1;
      _tabIndex = 1;
      // Jika ada initial soals (dari AI/template upload)
      if (widget.initialSoals != null && widget.initialSoals!.isNotEmpty) {
        _soals.addAll(widget.initialSoals!);
        _editingIndex = 0;
      } else {
        _checkNativeAndLoadSoal();
      }
    } else {
      _checkNativeAndLoadSoal();
    }
  }

  // Cek apakah ujian ini native, lalu load soal-soalnya
  void _checkNativeAndLoadSoal() async {
    if (widget.isReuse) return; // mode duplikasi tidak perlu load soal
    try {
      final doc = await FirebaseFirestore.instance
          .collection('exam').doc(widget.exam.id).get();
      final mode = (doc.data() as Map?)?['mode']?.toString() ?? '';
      if (!mounted) return;
      setState(() => _isNativeExam = mode == 'native' || widget.soalOnly);
      if (_isNativeExam) _loadSoal();
    } catch (_) {
      // soalOnly mode: tetap tampilkan soal tab meskipun gagal cek mode
      if (widget.soalOnly && mounted) {
        setState(() => _isNativeExam = true);
        _loadSoal();
      }
    }
  }

  Future<void> _loadSoal() async {
    setState(() { _soalLoading = true; _soals.clear(); });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('exam').doc(widget.exam.id).collection('soal')
          .orderBy('nomor').get();
      for (final d in snap.docs) {
        final data = d.data();
        final tipeStr = data['tipe'] ?? 'pilihanGanda';
        final tipe = tipeStr == 'benarSalah' ? TipeSoal.benarSalah
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
          tipe: tipe,
          pertanyaan: data['pertanyaan'] ?? '',
          gambarBase64: (data['gambar'] ?? '').isNotEmpty ? data['gambar'] : null,
          pilihan: pilihan,
          kunciJawaban: data['kunciJawaban'] ?? '',
          skor: data['skor'] ?? 1,
        ));
      }
      if (_soals.isEmpty) _soals.add(SoalDraft());
      setState(() => _soalLoading = false);
    } catch (e) {
      setState(() => _soalLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal memuat soal: $e'), backgroundColor: Colors.red));
    }
  }

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
                "Pastikan semua soal sudah dicek sebelum diterbitkan.",
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
              backgroundColor: const Color(0xFF0F172A),
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

  Future<void> _uploadSoal() async {
    // Validasi
    for (int i = 0; i < _soals.length; i++) {
      final s = _soals[i];
      if (s.pertanyaan.trim().isEmpty && s.gambarBase64 == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Soal ${i+1} belum ada pertanyaan!'),
            backgroundColor: Colors.orange));
        return;
      }
      if (s.tipe == TipeSoal.pilihanGanda) {
        if (s.pilihan.where((p) => p.trim().isNotEmpty).length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Soal ${i+1}: minimal 2 pilihan!'),
              backgroundColor: Colors.orange));
          return;
        }
        if (s.kunciJawaban.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Soal ${i+1}: belum ada kunci jawaban!'),
              backgroundColor: Colors.orange));
          return;
        }
      } else if (s.tipe == TipeSoal.benarSalah && s.kunciJawaban.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Soal ${i+1}: tentukan Benar/Salah!'),
            backgroundColor: Colors.orange));
        return;
      }
    }

    setState(() => _soalUploading = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('exam').doc(widget.exam.id).collection('soal');
      // Hapus soal lama
      final old = await ref.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var d in old.docs) batch.delete(d.reference);
      await batch.commit();
      // Upload soal baru
      for (int i = 0; i < _soals.length; i++) {
        final s = _soals[i];
        final piOpts = s.tipe == TipeSoal.pilihanGanda
            ? s.pilihan.asMap().entries
            .where((e) => e.value.trim().isNotEmpty)
            .map((e) => '${String.fromCharCode(65 + e.key)}. ${e.value}')
            .toList()
            : <String>[];
        await ref.add({
          'nomor': i + 1,
          'tipe': s.tipe.name,
          'pertanyaan': s.pertanyaan.trim(),
          'gambar': s.gambarBase64 ?? '',
          'pilihan': piOpts,
          'kunciJawaban': s.kunciJawaban.toUpperCase(),
          'skor': s.skor,
        });
      }
      await FirebaseFirestore.instance.collection('exam').doc(widget.exam.id)
          .update({'jumlahSoal': _soals.length});
      setState(() => _soalUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Soal berhasil disimpan!'), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _soalUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal simpan soal: $e'), backgroundColor: Colors.red));
    }
  }

  void _loadSubjects() async {
    final snap = await FirebaseFirestore.instance.collection('subjects').get();
    setState(() {
      _subjects = snap.docs.map((d) => d['name'].toString()).toList();
      if (!_subjects.contains(_mapel)) _subjects.insert(0, _mapel);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _soalScrollCtrl.dispose();
    _judulCtrl.dispose();
    _linkCtrl.dispose();
    _instruksiCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickWaktuMulai() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _waktuMulai,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_waktuMulai),
    );
    if (t == null || !mounted) return;
    setState(() {
      _waktuMulai = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (_waktuSelesai.isBefore(_waktuMulai)) {
        _waktuSelesai = _waktuMulai.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickWaktuSelesai() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _waktuSelesai,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_waktuSelesai),
    );
    if (t == null || !mounted) return;
    final newSelesai = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (newSelesai.isBefore(_waktuMulai)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Waktu selesai harus setelah waktu mulai!"),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _waktuSelesai = newSelesai);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_waktuSelesai.isBefore(_waktuMulai)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Waktu selesai harus setelah waktu mulai!"),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'judul': _judulCtrl.text.trim(),
        'mapel': _mapel,
        'jenjang': _jenjang,
        'link': _linkCtrl.text.trim(),
        'instruksi': _instruksiCtrl.text.trim(),
        'waktuMulai': Timestamp.fromDate(_waktuMulai),
        'waktuSelesai': Timestamp.fromDate(_waktuSelesai),
        'antiCurang': _antiCurang,
        'maxCurang': _maxCurang,
        'kameraAktif': _kameraAktif,
        'autoSubmit': _autoSubmit,
        'kkm': _kkm,
        'spiType': _spiType,
        if (_parentExamId != null) 'parentExamId': _parentExamId,
      };

      if (widget.isReuse) {
        // Buat dokumen baru
        await FirebaseFirestore.instance.collection('exam').add(data);
      } else {
        // Update dokumen yang ada
        await FirebaseFirestore.instance
            .collection('exam')
            .doc(widget.exam.id)
            .update(data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isReuse
            ? "Ujian berhasil diduplikasi!"
            : "Ujian berhasil diperbarui!"),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Gagal menyimpan: $e"),
        backgroundColor: Colors.red,
      ));
    }
    setState(() => _saving = false);
  }

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 14),
    child: Text(label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  );

  @override
  Widget build(BuildContext context) {
    // Tab: 0 = Info Ujian, 1 = Edit Soal (hanya native & bukan reuse)
    final showSoalTab = !widget.isReuse && _isNativeExam;

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(widget.soalOnly ? "Edit Soal" : widget.isReuse ? "Gunakan Ulang Ujian" : "Edit Ujian"),
        bottom: showSoalTab && !widget.soalOnly
            ? TabBar(
          controller: _tabCtrl,
          onTap: (i) => setState(() => _tabIndex = i),
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 18), text: "Info Ujian"),
            Tab(icon: Icon(Icons.quiz_outlined, size: 18), text: "Edit Soal"),
          ],
        )
            : null,
        actions: [
          if (_tabIndex == 0 && !widget.soalOnly)
            (_saving
                ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
              label: Text(widget.isReuse ? "Duplikasi" : "Simpan",
                  style: const TextStyle(color: Colors.white)),
            )),
          if ((_tabIndex == 1 && showSoalTab) || widget.soalOnly) ...[
            IconButton(
              tooltip: 'Simpan Draft',
              onPressed: _soals.isNotEmpty ? _saveDraft : null,
              icon: const Icon(Icons.save_outlined, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Preview Soal',
              onPressed: _soals.isNotEmpty ? _showPreviewDialog : null,
              icon: const Icon(Icons.visibility, color: Colors.white),
            ),
            _soalUploading
                ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : TextButton.icon(
              onPressed: _showTerbitkanDialog,
              icon: const Icon(Icons.publish, color: Colors.white),
              label: const Text("Terbitkan Soal",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
      body: widget.soalOnly
          ? _buildSoalTab()
          : showSoalTab
          ? (_tabIndex == 0 ? _buildInfoTab() : _buildSoalTab())
          : _buildInfoTab(),
    );

    // Wrap with back-navigation confirmation
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
            title: const Text('Keluar dari editor?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: const Text('Perubahan yang belum disimpan akan hilang.\nSimpan ke draft terlebih dahulu?',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'discard'),
                child: const Text('Buang', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, 'draft'),
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Simpan Draft'),
              ),
            ],
          ),
        );
        if (action == 'draft') {
          await _saveDraft();
          if (mounted) Navigator.pop(context);
        } else if (action == 'discard') {
          if (mounted) Navigator.pop(context);
        }
      },
      child: scaffold,
    );
  }

  // ── TAB 1: Info Ujian ──
  Widget _buildInfoTab() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.isReuse)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.teal, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  "Mode Gunakan Ulang: Ujian baru akan dibuat berdasarkan ujian ini. Ujian lama tidak berubah.",
                  style: TextStyle(color: Colors.teal, fontSize: 12),
                )),
              ]),
            ),

          // Judul
          _fieldLabel("Judul Ujian"),
          TextFormField(
            controller: _judulCtrl,
            decoration: InputDecoration(
              hintText: "Masukkan judul ujian",
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v!.trim().isEmpty ? "Judul tidak boleh kosong" : null,
          ),

          // Mata Pelajaran
          _fieldLabel("Mata Pelajaran"),
          DropdownButtonFormField<String>(
            value: _subjects.contains(_mapel) ? _mapel : null,
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _mapel = v!),
          ),

          // Jenjang
          _fieldLabel("Jenjang / Kelas"),
          DropdownButtonFormField<String>(
            value: _jenjang,
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: ["Kelas 7", "Kelas 8", "Kelas 9"]
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _jenjang = v!),
          ),

          // Link — hanya tampil jika bukan ujian native
          if (!_isNativeExam) ...[
            _fieldLabel("Link Google Form"),
            TextFormField(
              controller: _linkCtrl,
              decoration: InputDecoration(
                hintText: "https://docs.google.com/forms/...",
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Link tidak boleh kosong";
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) return "Link harus diawali https://";
                return null;
              },
            ),
          ],

          // Instruksi
          _fieldLabel("Instruksi (opsional)"),
          TextFormField(
            controller: _instruksiCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Tulis instruksi ujian...",
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // Waktu Mulai
          _fieldLabel("Waktu Mulai"),
          GestureDetector(
            onTap: _pickWaktuMulai,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Row(children: [
                const Icon(Icons.access_time, color: Colors.indigo, size: 18),
                const SizedBox(width: 10),
                Text(DateFormat("dd MMM yyyy, HH:mm").format(_waktuMulai),
                    style: const TextStyle(fontSize: 14)),
              ]),
            ),
          ),

          // Waktu Selesai
          _fieldLabel("Waktu Selesai"),
          GestureDetector(
            onTap: _pickWaktuSelesai,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Row(children: [
                const Icon(Icons.access_time_filled, color: Colors.red, size: 18),
                const SizedBox(width: 10),
                Text(DateFormat("dd MMM yyyy, HH:mm").format(_waktuSelesai),
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  "(${_waktuSelesai.difference(_waktuMulai).inMinutes} menit)",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ]),
            ),
          ),

          // Settings
          _fieldLabel("Pengaturan"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              SwitchListTile(
                title: const Text("Anti Curang"),
                subtitle: const Text("Keluar app dihitung pelanggaran"),
                value: _antiCurang,
                onChanged: (v) => setState(() => _antiCurang = v),
              ),
              if (_antiCurang) ...[
                const Divider(height: 1),
                ListTile(
                  title: const Text("Maksimal Pelanggaran"),
                  subtitle: Text("Saat ini: $_maxCurang kali"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _maxCurang > 1 ? () => setState(() => _maxCurang--) : null,
                    ),
                    Text("$_maxCurang",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _maxCurang++),
                    ),
                  ]),
                ),
              ],
              const Divider(height: 1),
              SwitchListTile(
                title: const Text("Kamera Aktif"),
                subtitle: const Text("Pantau siswa via kamera depan"),
                value: _kameraAktif,
                onChanged: (v) => setState(() => _kameraAktif = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text("Auto Submit"),
                subtitle: const Text("Form otomatis dikunci saat waktu habis"),
                value: _autoSubmit,
                onChanged: (v) => setState(() => _autoSubmit = v),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.verified, color: Colors.teal),
                title: const Text("KKM (Kriteria Ketuntasan)"),
                subtitle: Text(_kkm > 0 ? "Nilai minimum: $_kkm" : "Tidak aktif"),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _kkm > 0 ? () => setState(() => _kkm = (_kkm - 5).clamp(0, 100)) : null,
                  ),
                  Text("$_kkm",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _kkm < 100 ? () => setState(() => _kkm = (_kkm + 5).clamp(0, 100)) : null,
                  ),
                ]),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.event_repeat, color: Color(0xFF0F172A)),
                title: const Text("Tipe Sesi"),
                subtitle: SegmentedButton<String>(
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
              ),
            ]),
          ),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isReuse ? Colors.teal : const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(widget.isReuse ? Icons.replay : Icons.save),
              label: Text(
                widget.isReuse ? "Duplikasi sebagai Ujian Baru" : "Simpan Perubahan",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── TAB 2: Edit Soal ──
  Widget _buildSoalTab() {
    if (_soalLoading) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(),
        SizedBox(height: 14),
        Text("Memuat soal...", style: TextStyle(color: Colors.grey)),
      ]));
    }

    return Row(children: [
      // Sidebar daftar soal
      Container(
        width: 200,
        color: Colors.white,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF0F172A),
            child: Row(children: [
              const Icon(Icons.format_list_numbered, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text("${_soals.length} Soal",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _soals.add(SoalDraft());
                  _editingIndex = _soals.length - 1;
                }),
                child: const Icon(Icons.add_circle, color: Colors.white, size: 20),
              ),
            ]),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _soals.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _soals.removeAt(oldIndex);
                  _soals.insert(newIndex, item);
                  if (_editingIndex == oldIndex) _editingIndex = newIndex;
                });
              },
              itemBuilder: (ctx, i) {
                final s = _soals[i];
                final isActive = i == _editingIndex;
                final tipeIcon = s.tipe == TipeSoal.pilihanGanda
                    ? Icons.radio_button_checked
                    : s.tipe == TipeSoal.benarSalah
                    ? Icons.check_box
                    : Icons.edit_note;
                return ListTile(
                  key: ValueKey(i),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isActive ? const Color(0xFF0F172A) : Colors.grey.shade200,
                    child: Text("${i + 1}",
                        style: TextStyle(
                            fontSize: 11,
                            color: isActive ? Colors.white : Colors.black54,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(
                    s.pertanyaan.isNotEmpty
                        ? _stripGambarTag(s.pertanyaan).length > 30
                        ? _stripGambarTag(s.pertanyaan).substring(0, 30) + "..."
                        : _stripGambarTag(s.pertanyaan)
                        : "(belum ada pertanyaan)",
                    style: TextStyle(
                        fontSize: 11,
                        color: s.pertanyaan.isEmpty ? Colors.grey : Colors.black87),
                    maxLines: 2,
                  ),
                  subtitle: Row(children: [
                    Icon(tipeIcon, size: 10, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      s.tipe == TipeSoal.pilihanGanda ? "PG"
                          : s.tipe == TipeSoal.benarSalah ? "B/S" : "Uraian",
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ]),
                  selected: isActive,
                  selectedTileColor: Colors.indigo.shade50,
                  onTap: () => setState(() => _editingIndex = i),
                  trailing: _soals.length > 1
                      ? GestureDetector(
                    onTap: () => setState(() {
                      _soals.removeAt(i);
                      if (_editingIndex >= _soals.length) {
                        _editingIndex = _soals.length - 1;
                      }
                    }),
                    child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  )
                      : null,
                );
              },
            ),
          ),
          // Tombol tambah soal bawah
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _soals.add(SoalDraft());
                  _editingIndex = _soals.length - 1;
                }),
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Tambah Soal", style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ]),
      ),

      const VerticalDivider(width: 1),

      // Panel editor soal kanan
      Expanded(
        child: _editingIndex < 0 || _editingIndex >= _soals.length
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.touch_app, size: 50, color: Colors.grey),
          SizedBox(height: 12),
          Text("Pilih soal di kiri untuk mengedit",
              style: TextStyle(color: Colors.grey)),
        ]))
            : _buildSoalEditor(_soals[_editingIndex], _editingIndex),
      ),
    ]);
  }

  // ── Editor untuk satu soal ──
  Widget _buildSoalEditor(SoalDraft s, int idx) {
    return SingleChildScrollView(
      controller: _soalScrollCtrl,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header soal
        Row(children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF0F172A),
            child: Text("${idx + 1}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          const Text("Edit Soal",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          // Skor
          Row(children: [
            const Text("Skor:", style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: s.skor > 1 ? () => setState(() => s.skor--) : null,
            ),
            Text("${s.skor}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => setState(() => s.skor++),
            ),
          ]),
        ]),

        const SizedBox(height: 16),

        // Tipe soal
        const Text("Tipe Soal", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        SegmentedButton<TipeSoal>(
          segments: const [
            ButtonSegment(value: TipeSoal.pilihanGanda,
                label: Text("Pilihan Ganda", style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.radio_button_checked, size: 15)),
            ButtonSegment(value: TipeSoal.benarSalah,
                label: Text("Benar/Salah", style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.check_box, size: 15)),
            ButtonSegment(value: TipeSoal.uraian,
                label: Text("Uraian", style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.edit_note, size: 15)),
          ],
          selected: {s.tipe},
          onSelectionChanged: (val) => setState(() {
            s.tipe = val.first;
            s.kunciJawaban = "";
          }),
        ),

        const SizedBox(height: 16),

        // Pertanyaan
        const Text("Pertanyaan", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: s.pertanyaan)
            ..selection = TextSelection.collapsed(offset: s.pertanyaan.length),
          maxLines: 4,
          onChanged: (v) => s.pertanyaan = v,
          decoration: InputDecoration(
            hintText: "Tulis pertanyaan di sini... (LaTeX: \$rumus\$)",
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        // Preview LaTeX jika ada
        if (s.pertanyaan.contains(r'$')) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Preview:", style: TextStyle(fontSize: 10, color: Colors.blue)),
              const SizedBox(height: 4),
              _renderLatex(s.pertanyaan),
            ]),
          ),
        ],

        const SizedBox(height: 14),

        // Gambar
        Row(children: [
          const Text("Gambar (opsional)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          if (s.gambarBase64 != null)
            TextButton.icon(
              onPressed: () => setState(() => s.gambarBase64 = null),
              icon: const Icon(Icons.delete, size: 14, color: Colors.red),
              label: const Text("Hapus", style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          OutlinedButton.icon(
            onPressed: () => _pickGambar(s),
            icon: const Icon(Icons.image, size: 14),
            label: const Text("Pilih Gambar", style: TextStyle(fontSize: 12)),
          ),
        ]),
        if (s.gambarBase64 != null) ...[
          const SizedBox(height: 8),
          _buildZoomableImage(base64Decode(s.gambarBase64!), context),
        ],

        const SizedBox(height: 16),

        // Pilihan / Kunci
        if (s.tipe == TipeSoal.pilihanGanda) ...[
          const Text("Pilihan Jawaban", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ...List.generate(4, (i) {
            final label = String.fromCharCode(65 + i);
            final isKunci = s.kunciJawaban == label;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isKunci ? Colors.green.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isKunci ? Colors.green : Colors.grey.shade300,
                    width: isKunci ? 2 : 1),
              ),
              child: Row(children: [
                // Tombol set kunci jawaban
                GestureDetector(
                  onTap: () => setState(() => s.kunciJawaban = label),
                  child: Container(
                    width: 40, height: 50,
                    decoration: BoxDecoration(
                      color: isKunci ? Colors.green : Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(9), bottomLeft: Radius.circular(9)),
                    ),
                    child: Center(child: Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isKunci ? Colors.white : Colors.black54))),
                  ),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: TextEditingController(text: s.pilihan[i])
                        ..selection = TextSelection.collapsed(offset: s.pilihan[i].length),
                      onChanged: (v) => setState(() => s.pilihan[i] = v),
                      decoration: const InputDecoration(
                        hintText: "Isi pilihan...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    if (s.pilihan[i].contains(r'$') || s.pilihan[i].contains('^{') || s.pilihan[i].contains('_{') || s.pilihan[i].contains('[EQ:'))
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 6),
                        child: _renderLatex(s.pilihan[i]),
                      ),
                  ]),
                ),
                if (isKunci)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.check_circle, color: Colors.green, size: 18),
                  ),
              ]),
            );
          }),
          if (s.kunciJawaban.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text("* Ketuk huruf di kiri untuk set kunci jawaban",
                  style: TextStyle(color: Colors.orange, fontSize: 11)),
            ),
        ] else if (s.tipe == TipeSoal.benarSalah) ...[
          const Text("Kunci Jawaban", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setState(() => s.kunciJawaban = "BENAR"),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: s.kunciJawaban == "BENAR" ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: s.kunciJawaban == "BENAR" ? Colors.green : Colors.grey.shade300,
                      width: s.kunciJawaban == "BENAR" ? 2 : 1),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_outline,
                      color: s.kunciJawaban == "BENAR" ? Colors.green : Colors.grey),
                  const SizedBox(width: 8),
                  Text("BENAR",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: s.kunciJawaban == "BENAR" ? Colors.green : Colors.grey)),
                ]),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () => setState(() => s.kunciJawaban = "SALAH"),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: s.kunciJawaban == "SALAH" ? Colors.red.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: s.kunciJawaban == "SALAH" ? Colors.red : Colors.grey.shade300,
                      width: s.kunciJawaban == "SALAH" ? 2 : 1),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.cancel_outlined,
                      color: s.kunciJawaban == "SALAH" ? Colors.red : Colors.grey),
                  const SizedBox(width: 8),
                  Text("SALAH",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: s.kunciJawaban == "SALAH" ? Colors.red : Colors.grey)),
                ]),
              ),
            )),
          ]),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                "Soal uraian dikoreksi manual oleh guru setelah ujian selesai.",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              )),
            ]),
          ),
        ],

        const SizedBox(height: 24),

        // Navigasi cepat soal
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (idx > 0)
            OutlinedButton.icon(
              onPressed: () => setState(() => _editingIndex = idx - 1),
              icon: const Icon(Icons.arrow_back, size: 15),
              label: const Text("Soal Sebelumnya", style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(width: 10),
          if (idx < _soals.length - 1)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () => setState(() => _editingIndex = idx + 1),
              icon: const Icon(Icons.arrow_forward, size: 15),
              label: const Text("Soal Berikutnya", style: TextStyle(fontSize: 12)),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () => setState(() {
                _soals.add(SoalDraft());
                _editingIndex = _soals.length - 1;
              }),
              icon: const Icon(Icons.add, size: 15),
              label: const Text("Tambah Soal Baru", style: TextStyle(fontSize: 12)),
            ),
        ]),

        const SizedBox(height: 30),
      ]),
    );
  }

  // Render LaTeX inline
  Widget _renderLatex(String text) {
    // Hapus tag [GAMBAR_N] dari teks yang ditampilkan
    text = _stripGambarTag(text);
    // Pastikan ^{...}, _{...}, [EQ:...] ter-wrap $...$
    text = DocxLocalParser._processEq(text);
    final parts = <InlineSpan>[];
    final reg = RegExp(r'\$([^$]+)\$');
    int last = 0;
    for (final m in reg.allMatches(text)) {
      if (m.start > last) {
        parts.add(TextSpan(text: text.substring(last, m.start),
            style: const TextStyle(fontSize: 13)));
      }
      parts.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(m.group(1)!,
            textStyle: const TextStyle(fontSize: 13),
            onErrorFallback: (e) => Text(m.group(0)!,
                style: const TextStyle(fontSize: 13, color: Colors.red))),
      ));
      last = m.end;
    }
    if (last < text.length) {
      parts.add(TextSpan(text: text.substring(last),
          style: const TextStyle(fontSize: 13)));
    }
    return Text.rich(TextSpan(children: parts));
  }

  // Pilih gambar dari file
  Future<void> _pickGambar(SoalDraft s) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      setState(() => s.gambarBase64 = base64Encode(result.files.single.bytes!));
    }
  }

  // ── Simpan draft ke Firestore ──
  Future<void> _saveDraft() async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('exam').doc(widget.exam.id).collection('soal_draft');
      // Hapus draft lama
      final old = await ref.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var d in old.docs) batch.delete(d.reference);
      await batch.commit();
      // Simpan draft baru
      for (int i = 0; i < _soals.length; i++) {
        final s = _soals[i];
        final piOpts = s.tipe == TipeSoal.pilihanGanda
            ? s.pilihan.asMap().entries
            .where((e) => e.value.trim().isNotEmpty)
            .map((e) => '${String.fromCharCode(65 + e.key)}. ${e.value}')
            .toList()
            : <String>[];
        await ref.add({
          'nomor': i + 1,
          'tipe': s.tipe.name,
          'pertanyaan': s.pertanyaan.trim(),
          'gambar': s.gambarBase64 ?? '',
          'pilihan': piOpts,
          'kunciJawaban': s.kunciJawaban.toUpperCase(),
          'skor': s.skor,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Draft ${_soals.length} soal berhasil disimpan!'),
          backgroundColor: Colors.teal,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal simpan draft: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

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
              // Progress bar
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
                            _buildTextWithLatex(_stripGambarTag(s.pertanyaan), 16),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: s.kunciJawaban == "BENAR" ? Colors.green.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: s.kunciJawaban == "BENAR" ? Colors.green : Colors.grey.shade300),
                          ),
                          child: Center(child: Text("BENAR", style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: s.kunciJawaban == "BENAR" ? Colors.green : Colors.grey))),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: s.kunciJawaban == "SALAH" ? Colors.red.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: s.kunciJawaban == "SALAH" ? Colors.red : Colors.grey.shade300),
                          ),
                          child: Center(child: Text("SALAH", style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: s.kunciJawaban == "SALAH" ? Colors.red : Colors.grey))),
                        )),
                      ]),
                    ],
                    if (s.tipe == TipeSoal.uraian) ...[
                      Container(
                        width: double.infinity,
                        height: 100,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text("Jawaban siswa akan muncul di sini...",
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ]),
                ),
              ),
              // Nav buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
                ),
                child: Row(children: [
                  if (previewIdx > 0)
                    OutlinedButton.icon(
                      onPressed: () => setPreview(() => previewIdx--),
                      icon: const Icon(Icons.arrow_back, size: 15),
                      label: const Text("Sebelumnya", style: TextStyle(fontSize: 12)),
                    ),
                  const Spacer(),
                  Text("${previewIdx + 1} / ${_soals.length}",
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (previewIdx < _soals.length - 1)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                      onPressed: () => setPreview(() => previewIdx++),
                      icon: const Icon(Icons.arrow_forward, size: 15),
                      label: const Text("Berikutnya", style: TextStyle(fontSize: 12)),
                    ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

