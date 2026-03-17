part of '../main.dart';

// ============================================================
// ANALYTICS SCREEN
// ============================================================
class AnalyticsScreen extends StatefulWidget {
  final Set<String>? filterMapel; // null = admin (semua), Set = guru (filter)

  const AnalyticsScreen({super.key, required this.filterMapel});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<ExamData> _exams = [];
  bool _loading = true;
  String? _selectedExamId;

  // Distribution data
  Map<String, int> _distrib = {'A': 0, 'B': 0, 'C': 0, 'D': 0};
  bool _loadingDist = false;

  // Average per mapel
  Map<String, double> _avgPerMapel = {};
  bool _loadingAvg = false;

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
          .limit(60)
          .get();

      final List<ExamData> exams = [];
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final mode = data['mode']?.toString() ?? '';
        if (mode == 'native') {
          exams.add(ExamData.fromFirestore(d));
        } else if (mode.isEmpty) {
          final soalSnap = await FirebaseFirestore.instance
              .collection('exam').doc(d.id).collection('soal').limit(1).get();
          if (soalSnap.docs.isNotEmpty) exams.add(ExamData.fromFirestore(d));
        }
      }

      var filtered = exams;
      if (widget.filterMapel != null && widget.filterMapel!.isNotEmpty) {
        filtered = exams.where((e) => widget.filterMapel!.contains(e.mapel)).toList();
      }
      setState(() { _exams = filtered; _loading = false; });
      _loadAvgPerMapel(filtered);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _loadAvgPerMapel(List<ExamData> exams) async {
    setState(() => _loadingAvg = true);
    final Map<String, List<double>> mapelScores = {};

    for (final exam in exams) {
      try {
        final soalSnap = await FirebaseFirestore.instance
            .collection('exam').doc(exam.id).collection('soal')
            .orderBy('nomor').get();
        if (soalSnap.docs.isEmpty) continue;
        final soals = soalSnap.docs
            .map((d) => SoalModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();
        final totalSkor = soals.fold<int>(0, (s, q) => s + q.skor);
        if (totalSkor == 0) continue;

        final jwbSnap = await FirebaseFirestore.instance
            .collection('exam').doc(exam.id).collection('jawaban').get();
        if (jwbSnap.docs.isEmpty) continue;

        for (final jwbDoc in jwbSnap.docs) {
          final jwbData = jwbDoc.data() as Map<String, dynamic>;
          final jawaban = jwbData['jawaban'] as Map<String, dynamic>? ?? {};
          int perolehan = 0;
          for (final soal in soals) {
            if (jawaban[soal.id]?.toString() == soal.kunciJawaban) {
              perolehan += soal.skor;
            }
          }
          mapelScores.putIfAbsent(exam.mapel, () => [])
              .add(perolehan / totalSkor * 100);
        }
      } catch (_) {}
    }

    final Map<String, double> avg = {};
    for (final entry in mapelScores.entries) {
      if (entry.value.isNotEmpty) {
        avg[entry.key] = entry.value.reduce((a, b) => a + b) / entry.value.length;
      }
    }
    setState(() { _avgPerMapel = avg; _loadingAvg = false; });
  }

  void _loadDistribution(String examId) async {
    setState(() { _loadingDist = true; _distrib = {'A': 0, 'B': 0, 'C': 0, 'D': 0}; });
    try {
      final soalSnap = await FirebaseFirestore.instance
          .collection('exam').doc(examId).collection('soal')
          .orderBy('nomor').get();
      final soals = soalSnap.docs
          .map((d) => SoalModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      final totalSkor = soals.fold<int>(0, (s, q) => s + q.skor);
      if (totalSkor == 0) { setState(() => _loadingDist = false); return; }

      final jwbSnap = await FirebaseFirestore.instance
          .collection('exam').doc(examId).collection('jawaban').get();

      final Map<String, int> dist = {'A': 0, 'B': 0, 'C': 0, 'D': 0};
      for (final jwbDoc in jwbSnap.docs) {
        final jwbData = jwbDoc.data() as Map<String, dynamic>;
        final jawaban = jwbData['jawaban'] as Map<String, dynamic>? ?? {};
        int perolehan = 0;
        for (final soal in soals) {
          if (jawaban[soal.id]?.toString() == soal.kunciJawaban) perolehan += soal.skor;
        }
        final nilai = perolehan / totalSkor * 100;
        if (nilai >= 90) dist['A'] = dist['A']! + 1;
        else if (nilai >= 75) dist['B'] = dist['B']! + 1;
        else if (nilai >= 60) dist['C'] = dist['C']! + 1;
        else dist['D'] = dist['D']! + 1;
      }
      setState(() { _distrib = dist; _loadingDist = false; });
    } catch (_) {
      setState(() => _loadingDist = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title
        Row(children: [
          Icon(Icons.analytics_outlined, color: context.bm.primary),
          const SizedBox(width: 8),
          Text('Analitik Ujian',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: context.bm.primary)),
          if (widget.filterMapel != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Chip(
                label: Text(widget.filterMapel!.join(', '),
                    style: const TextStyle(fontSize: 10)),
                backgroundColor: Colors.teal.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ]),
        const SizedBox(height: 16),

        // ── Chart 1: Distribusi Nilai ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Distribusi Nilai',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Pilih ujian untuk melihat distribusi nilai siswa',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 12),
              if (_exams.isEmpty)
                const Text('Tidak ada ujian tersedia', style: TextStyle(color: Colors.grey))
              else
                DropdownButtonFormField<String>(
                  value: _selectedExamId,
                  decoration: InputDecoration(
                    labelText: 'Pilih Ujian',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: _exams.map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(
                      '${e.mapel} - ${e.judul}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  )).toList(),
                  onChanged: (val) {
                    setState(() => _selectedExamId = val);
                    if (val != null) _loadDistribution(val);
                  },
                ),
              const SizedBox(height: 16),
              if (_selectedExamId == null)
                const Center(
                    child: Text('Pilih ujian di atas',
                        style: TextStyle(color: Colors.grey)))
              else if (_loadingDist)
                const Center(child: CircularProgressIndicator())
              else ...[
                LayoutBuilder(builder: (ctx, constraints) => SizedBox(
                  height: (MediaQuery.of(ctx).size.height * 0.25).clamp(160.0, 220.0),
                  child: BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (_distrib.values.fold<int>(0, (a, b) => a > b ? a : b) + 2).toDouble(),
                    barGroups: [
                      _barGroup(0, _distrib['A']!.toDouble(), Colors.green),
                      _barGroup(1, _distrib['B']!.toDouble(), Colors.blue),
                      _barGroup(2, _distrib['C']!.toDouble(), Colors.orange),
                      _barGroup(3, _distrib['D']!.toDouble(), Colors.red),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          const labels = ['A (≥90)', 'B (75-89)', 'C (60-74)', 'D (<60)'];
                          if (val.toInt() < 0 || val.toInt() >= labels.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(labels[val.toInt()], style: const TextStyle(fontSize: 9)),
                          );
                        },
                      )),
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 28,
                        getTitlesWidget: (val, _) =>
                            Text(val.toInt().toString(), style: const TextStyle(fontSize: 10)),
                      )),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                  )),
                )),
                const SizedBox(height: 8),
                Wrap(spacing: 12, children: [
                  _legend('A ≥90', Colors.green, _distrib['A']!),
                  _legend('B 75-89', Colors.blue, _distrib['B']!),
                  _legend('C 60-74', Colors.orange, _distrib['C']!),
                  _legend('D <60', Colors.red, _distrib['D']!),
                ]),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── Chart 2: Rata-rata per Mapel ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Rata-rata Nilai per Mata Pelajaran',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Berdasarkan semua ujian yang sudah memiliki jawaban',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 16),
              if (_loadingAvg)
                const Center(child: CircularProgressIndicator())
              else if (_avgPerMapel.isEmpty)
                const Center(
                    child: Text('Belum ada data nilai',
                        style: TextStyle(color: Colors.grey)))
              else ...[
                SizedBox(
                  height: (_avgPerMapel.length * 48 + 32).toDouble().clamp(120.0, 360.0),
                  child: BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100,
                    barGroups: _avgPerMapel.entries.toList().asMap().entries.map((e) =>
                        BarChartGroupData(
                          x: e.key,
                          barRods: [BarChartRodData(
                            toY: e.value.value,
                            color: context.bm.primary,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          )],
                        )).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 68,
                        getTitlesWidget: (val, _) {
                          final keys = _avgPerMapel.keys.toList();
                          if (val.toInt() < 0 || val.toInt() >= keys.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                                keys[val.toInt()].length > 10
                                    ? keys[val.toInt()].substring(0, 9) + '...'
                                    : keys[val.toInt()],
                                style: const TextStyle(fontSize: 9),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis),
                          );
                        },
                      )),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) =>
                            Text(val.toInt().toString(), style: const TextStyle(fontSize: 9)),
                      )),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                  )),
                ),
                const SizedBox(height: 12),
                ...(_avgPerMapel.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                    Text(e.value.toStringAsFixed(1),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: e.value >= 75
                                ? Colors.green
                                : e.value >= 60 ? Colors.orange : Colors.red)),
                  ]),
                )),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  BarChartGroupData _barGroup(int x, double y, Color color) =>
      BarChartGroupData(
        x: x,
        barRods: [BarChartRodData(
          toY: y,
          color: color,
          width: 30,
          borderRadius: BorderRadius.circular(4),
        )],
      );

  Widget _legend(String label, Color color, int count) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text('$label: $count', style: const TextStyle(fontSize: 11)),
    ],
  );
}

