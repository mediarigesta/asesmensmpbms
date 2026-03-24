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
  List<ExamData> _allExams = [];
  bool _loading = true;
  String _search = '';

  // Filters
  String? _filterMapel;
  String? _filterJenjang;
  DateTimeRange? _filterTanggal;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  void _loadExams() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('exam')
          .orderBy('waktuMulai', descending: true)
          .get();

      final List<ExamData> exams = [];
      for (final d in snap.docs) {
        final exam = ExamData.fromFirestore(d);
        if (exam.isDraft) continue;
        exams.add(exam);
      }

      // Filter berdasarkan mapel guru jika ada
      var filtered = exams;
      if (widget.filterMapel != null && widget.filterMapel!.isNotEmpty) {
        filtered = exams.where((e) => widget.filterMapel!.contains(e.mapel)).toList();
      }
      setState(() { _allExams = filtered; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat daftar ujian: $e'), backgroundColor: Colors.red));
    }
  }

  List<ExamData> get _filteredExams {
    var list = _allExams;
    if (_filterMapel != null) {
      list = list.where((e) => e.mapel == _filterMapel).toList();
    }
    if (_filterJenjang != null) {
      list = list.where((e) => e.jenjang == _filterJenjang).toList();
    }
    if (_filterTanggal != null) {
      list = list.where((e) =>
          !e.waktuMulai.isBefore(_filterTanggal!.start) &&
          e.waktuMulai.isBefore(_filterTanggal!.end.add(const Duration(days: 1)))).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) =>
          e.judul.toLowerCase().contains(q) ||
          e.mapel.toLowerCase().contains(q) ||
          e.jenjang.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Set<String> get _mapelSet => _allExams.map((e) => e.mapel).where((m) => m.isNotEmpty).toSet();
  Set<String> get _jenjangSet => _allExams.map((e) => e.jenjang).where((j) => j.isNotEmpty).toSet();

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _filterTanggal,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF0F172A))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _filterTanggal = picked);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredExams;
    final mapelList = _mapelSet.toList()..sort();
    final jenjangs = _jenjangSet.toList()..sort();

    return Column(children: [
      // Header + Search
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.grading, color: Color(0xFF0F172A), size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text("Rekap Nilai", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
            GestureDetector(
              onTap: _loadExams,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh, size: 14, color: const Color(0xFF0F172A).withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text("Muat Ulang", style: TextStyle(fontSize: 11, color: const Color(0xFF0F172A).withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          // Filter row
          Row(children: [
            // Mapel filter
            Expanded(child: DropdownButtonFormField<String>(
              value: _filterMapel,
              decoration: InputDecoration(
                labelText: "Mapel", isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: [
                const DropdownMenuItem(value: null, child: Text("Semua Mapel", style: TextStyle(fontSize: 12))),
                ...mapelList.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))),
              ],
              onChanged: (v) => setState(() => _filterMapel = v),
            )),
            const SizedBox(width: 8),
            // Kelas/Jenjang filter
            Expanded(child: DropdownButtonFormField<String>(
              value: _filterJenjang,
              decoration: InputDecoration(
                labelText: "Kelas", isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: [
                const DropdownMenuItem(value: null, child: Text("Semua Kelas", style: TextStyle(fontSize: 12))),
                ...jenjangs.map((j) => DropdownMenuItem(value: j, child: Text(j, style: const TextStyle(fontSize: 12)))),
              ],
              onChanged: (v) => setState(() => _filterJenjang = v),
            )),
            const SizedBox(width: 8),
            // Date range
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                  color: _filterTanggal != null ? const Color(0xFF0F172A).withValues(alpha: 0.06) : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.date_range, size: 14,
                      color: _filterTanggal != null ? const Color(0xFF0F172A) : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _filterTanggal != null
                        ? "${DateFormat('dd/MM').format(_filterTanggal!.start)} - ${DateFormat('dd/MM').format(_filterTanggal!.end)}"
                        : "Tanggal",
                    style: TextStyle(fontSize: 11,
                        color: _filterTanggal != null ? const Color(0xFF0F172A) : Colors.grey.shade600,
                        fontWeight: _filterTanggal != null ? FontWeight.bold : FontWeight.normal),
                  ),
                  if (_filterTanggal != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _filterTanggal = null),
                      child: const Icon(Icons.close, size: 14, color: Colors.red),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // Search
          TextField(
            decoration: InputDecoration(
              hintText: "Cari ujian...",
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true, filled: true, fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _search = v),
          ),
        ]),
      ),

      // Stats bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF0F172A),
        child: Row(children: [
          const Icon(Icons.assessment, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text("${filtered.length} ujian ditemukan", style: const TextStyle(color: Colors.white, fontSize: 12)),
          const Spacer(),
          if (_filterMapel != null || _filterJenjang != null || _filterTanggal != null)
            GestureDetector(
              onTap: () => setState(() { _filterMapel = null; _filterJenjang = null; _filterTanggal = null; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.filter_alt_off, size: 12, color: Colors.white70),
                  SizedBox(width: 4),
                  Text("Reset Filter", style: TextStyle(fontSize: 10, color: Colors.white70)),
                ]),
              ),
            ),
        ]),
      ),

      // Content
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.grading, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text("Tidak ada ujian ditemukan", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text("Coba ubah filter atau cari dengan kata kunci lain.",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _buildExamCard(filtered[i]),
                  ),
      ),
    ]);
  }

  Widget _buildExamCard(ExamData exam) {
    final statusColor = exam.sudahSelesai
        ? Colors.grey : exam.isOngoing ? Colors.green : Colors.orange;
    final statusLabel = exam.sudahSelesai
        ? "SELESAI" : exam.isOngoing ? "BERLANGSUNG" : "BELUM MULAI";

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ExamHistoryScreen(exam: exam))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title row
            Row(children: [
              Expanded(child: Text(exam.judul,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(12)),
                child: Text(statusLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            // Info chips
            Wrap(spacing: 6, runSpacing: 4, children: [
              _infoChip(Icons.book, exam.mapel, Colors.blue),
              _infoChip(Icons.school, exam.jenjang, Colors.teal),
              _infoChip(Icons.calendar_today,
                  DateFormat('dd MMM yyyy').format(exam.waktuMulai), Colors.purple),
              _infoChip(Icons.schedule,
                  "${DateFormat('HH:mm').format(exam.waktuMulai)} - ${DateFormat('HH:mm').format(exam.waktuSelesai)}",
                  Colors.indigo),
              if (exam.mode == 'native')
                _infoChip(Icons.smartphone, "Native", Colors.deepOrange),
              if (exam.spiType == 'remedial')
                _infoChip(Icons.healing, "Remedial", Colors.deepOrange),
              if (exam.spiType == 'susulan')
                _infoChip(Icons.event_repeat, "Susulan", Colors.indigo),
              if (exam.kkm > 0)
                _infoChip(Icons.verified, "KKM: ${exam.kkm}", Colors.teal),
            ]),
            const SizedBox(height: 8),
            // Footer
            Row(children: [
              if (exam.creatorName.isNotEmpty) ...[
                Icon(Icons.person_outline, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(exam.creatorName,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const Spacer(),
              ] else
                const Spacer(),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

