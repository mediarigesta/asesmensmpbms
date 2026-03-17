part of '../main.dart';

// ============================================================
// REKAP NILAI SCREEN
// ============================================================
class RekapsNilaiScreen extends StatefulWidget {
  /// null = tampilkan semua (admin). Set<String> = filter mapel guru.
  final Set<String>? filterMapel;
  const RekapsNilaiScreen({super.key, this.filterMapel});
  @override
  State<RekapsNilaiScreen> createState() => _RekapsNilaiScreenState();
}

class _RekapsNilaiScreenState extends State<RekapsNilaiScreen> {
  String? _selectedExamId;
  String? _selectedExamJudul;
  List<ExamData> _exams = [];
  bool _loadingExams = true;
  bool _loadingRekap = false;
  List<Map<String, dynamic>> _rekap = [];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  void _loadExams() async {
    setState(() => _loadingExams = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('exam')
          .orderBy('waktuMulai', descending: true)
          .limit(50)
          .get();

      // Ambil ujian native: mode == 'native' ATAU punya sub-koleksi soal
      // (ujian lama mungkin belum ada field 'mode')
      final List<ExamData> exams = [];
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final mode = data['mode']?.toString() ?? '';
        if (mode == 'native') {
          exams.add(ExamData.fromFirestore(d));
        } else if (mode.isEmpty) {
          // Ujian lama tanpa field mode — cek apakah punya soal
          final soalSnap = await FirebaseFirestore.instance
              .collection('exam').doc(d.id).collection('soal')
              .limit(1).get();
          if (soalSnap.docs.isNotEmpty) {
            exams.add(ExamData.fromFirestore(d));
          }
        }
      }

      var filtered = exams;
      if (widget.filterMapel != null && widget.filterMapel!.isNotEmpty) {
        filtered = exams.where((e) => widget.filterMapel!.contains(e.mapel)).toList();
      }
      setState(() { _exams = filtered; _loadingExams = false; });
    } catch (e) {
      setState(() => _loadingExams = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat daftar ujian: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _loadRekap(String examId) async {
    setState(() { _loadingRekap = true; _rekap = []; });
    try {
      // Load soal + kunci
      final soalSnap = await FirebaseFirestore.instance
          .collection('exam').doc(examId).collection('soal')
          .orderBy('nomor').get();
      final soals = soalSnap.docs.map((d) => SoalModel.fromMap(d.data(), d.id)).toList();
      final totalSkor = soals.fold<int>(0, (s, q) => s + q.skor);

      // Load semua jawaban siswa untuk exam ini
      final jwbSnap = await FirebaseFirestore.instance
          .collection('exam').doc(examId).collection('jawaban')
          .get();

      if (jwbSnap.docs.isEmpty) {
        setState(() { _rekap = []; _loadingRekap = false; });
        return;
      }

      // Group per siswa
      final Map<String, List<QueryDocumentSnapshot>> bySiswa = {};
      for (var d in jwbSnap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final siswaId = data['siswaId']?.toString() ?? '';
        if (siswaId.isEmpty) continue;
        bySiswa.putIfAbsent(siswaId, () => []).add(d);
      }

      if (bySiswa.isEmpty) {
        setState(() { _rekap = []; _loadingRekap = false; });
        return;
      }

      // Load nama siswa
      final List<Map<String, dynamic>> rekap = [];
      for (final entry in bySiswa.entries) {
        final siswaId = entry.key;
        final jwbs = entry.value;

        // Hitung nilai
        int nilaiPG = 0, nilaiBS = 0;
        int totalPG = 0, totalBS = 0, totalUraian = 0;
        int correctPG = 0, correctBS = 0;

        for (final soal in soals) {
          final jwbDoc = jwbs.cast<QueryDocumentSnapshot?>().firstWhere(
                  (j) => (j!.data() as Map)['soalId'] == soal.id, orElse: () => null);
          final jawaban = (jwbDoc?.data() as Map?)?['jawaban']?.toString().toUpperCase() ?? '';

          if (soal.tipe == TipeSoal.pilihanGanda) {
            totalPG += soal.skor;
            if (jawaban == soal.kunciJawaban.toUpperCase()) {
              nilaiPG += soal.skor; correctPG++;
            }
          } else if (soal.tipe == TipeSoal.benarSalah) {
            totalBS += soal.skor;
            if (jawaban == soal.kunciJawaban.toUpperCase()) {
              nilaiBS += soal.skor; correctBS++;
            }
          } else {
            totalUraian += soal.skor;
          }
        }

        final nilaiOtomatis = nilaiPG + nilaiBS;
        final persen = totalSkor > 0 ? (nilaiOtomatis / totalSkor * 100).round() : 0;

        // Get nama & kode kelas
        String nama = siswaId;
        String kode = '';
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(siswaId).get();
          if (userDoc.exists) {
            final ud = userDoc.data() as Map;
            nama = ud['nama'] ?? siswaId;
            kode = ud['kode']?.toString() ?? '';
          }
        } catch (_) {}

        // Folder kelas: ambil prefix angka+huruf, e.g. "7A01" → "7A", "7B" → "7B"
        String kelasFolder = '';
        final matchFolder = RegExp(r'^\d+[A-Za-z]+').stringMatch(kode);
        if (matchFolder != null) {
          kelasFolder = matchFolder;
        } else {
          final matchAngka = RegExp(r'^\d+').stringMatch(kode);
          kelasFolder = matchAngka ?? kode;
        }

        rekap.add({
          'siswaId': siswaId,
          'nama': nama,
          'kode': kode,
          'kelas': kelasFolder,
          'nilaiPG': nilaiPG,
          'nilaiBS': nilaiBS,
          'nilaiTotal': nilaiOtomatis,
          'totalSkor': totalSkor,
          'persen': persen,
          'correctPG': correctPG,
          'correctBS': correctBS,
        });
      }

      // Sort: urut kelas dulu, lalu nilai tertinggi
      rekap.sort((a, b) {
        final kelasA = (a['kelas'] ?? '') as String;
        final kelasB = (b['kelas'] ?? '') as String;
        final kelasComp = kelasA.compareTo(kelasB);
        if (kelasComp != 0) return kelasComp;
        return ((b['persen'] ?? 0) as int).compareTo((a['persen'] ?? 0) as int);
      });
      setState(() { _rekap = rekap; _loadingRekap = false; });
    } catch (e) {
      setState(() => _loadingRekap = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  /// Bangun tampilan rekap dikelompokkan per kelas
  Widget _buildRekapGrouped() {
    // Kumpulkan semua kelas unik, urut abjad
    final kelasSet = <String>{};
    for (final r in _rekap) kelasSet.add((r['kelas'] ?? '') as String);
    final kelasList = kelasSet.toList()..sort();

    final rataTotal = (_rekap.fold<int>(0, (s, r) => s + ((r['persen'] ?? 0) as int)) / _rekap.length).round();

    return Column(children: [
      // Summary bar global
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF0F172A),
        child: Row(children: [
          const Icon(Icons.people, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text("${_rekap.length} peserta", style: const TextStyle(color: Colors.white, fontSize: 13)),
          const Spacer(),
          Text("Rata-rata: $rataTotal%",
              style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: kelasList.length,
          itemBuilder: (c, ki) {
            final kelas = kelasList[ki];
            final siswaKelas = _rekap.where((r) => (r['kelas'] ?? '') == kelas).toList();
            final rataKelas = siswaKelas.isEmpty ? 0
                : (siswaKelas.fold<int>(0, (s, r) => s + ((r['persen'] ?? 0) as int)) / siswaKelas.length).round();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header folder kelas
                Container(
                  margin: EdgeInsets.only(bottom: 8, top: ki == 0 ? 0 : 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.folder, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Text("Kelas $kelas",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    Text("${siswaKelas.length} siswa  •  rata-rata $rataKelas%",
                        style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ]),
                ),
                // Daftar siswa dalam kelas ini
                ...siswaKelas.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final r = entry.value;
                  final persen = (r['persen'] ?? 0) as int;
                  final nilaiColor = persen >= 75 ? Colors.green
                      : persen >= 60 ? Colors.orange : Colors.red;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: nilaiColor.withValues(alpha: 0.15),
                          child: Text("$rank",
                              style: TextStyle(color: nilaiColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r['nama']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text("${r['kode'] ?? ''}  •  PG: ${r['correctPG'] ?? 0} benar  •  B/S: ${r['correctBS'] ?? 0} benar",
                              style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text("$persen%",
                              style: TextStyle(color: nilaiColor, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("${r['nilaiTotal'] ?? 0}/${r['totalSkor'] ?? 0}",
                              style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ]),
                      ]),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Pilih ujian
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Rekap Nilai Otomatis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text("Khusus ujian native (bukan Google Form)", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _loadingExams
                  ? const Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text("Memuat daftar ujian...", style: TextStyle(color: Colors.grey)),
              ])
                  : _exams.isEmpty
                  ? Row(children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                const Expanded(child: Text(
                  "Belum ada ujian native. Buat ujian dengan mode 'Via Aplikasi'.",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                )),
                TextButton.icon(
                  onPressed: _loadExams,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text("Muat Ulang"),
                ),
              ])
                  : DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Pilih Ujian",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true, filled: true, fillColor: Colors.grey.shade50,
                ),
                value: _selectedExamId,
                items: _exams.map((e) => DropdownMenuItem(
                  value: e.id,
                  child: Text("${e.judul} • ${e.jenjang}", overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedExamId = v;
                    _selectedExamJudul = _exams.firstWhere((e) => e.id == v).judul;
                  });
                  if (v != null) _loadRekap(v);
                },
              ),
            ),
          ]),
        ]),
      ),

      // Content
      Expanded(
        child: _loadingRekap
            ? const Center(child: CircularProgressIndicator())
            : _rekap.isEmpty
            ? Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_selectedExamId == null ? Icons.grading : Icons.inbox_outlined,
                size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_selectedExamId == null
                ? "Pilih ujian untuk melihat rekap nilai"
                : "Belum ada siswa yang mengerjakan",
                style: const TextStyle(color: Colors.grey)),
          ]),
        )
            : _buildRekapGrouped(),
      ),
    ]);
  }
}

