part of '../main.dart';

// ============================================================
// LIVE MONITORING SCREEN — Real-time exam monitoring dashboard
// ============================================================
class LiveMonitoringScreen extends StatefulWidget {
  final ExamData exam;
  const LiveMonitoringScreen({super.key, required this.exam});
  @override
  State<LiveMonitoringScreen> createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  ExamData get exam => widget.exam;
  String _filter = 'semua';
  String _search = '';
  int _totalSoal = 0;

  @override
  void initState() {
    super.initState();
    _loadTotalSoal();
  }

  Future<void> _loadTotalSoal() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('exam').doc(exam.id).collection('soal').count().get();
      if (mounted) setState(() => _totalSoal = snap.count ?? 0);
    } catch (_) {}
  }

  String _statusForExam(UserAccount s) => s.statusForExam(exam.id);

  Color _statusColor(String s) {
    switch (s) {
      case 'selesai': return Colors.green;
      case 'melanggar': return Colors.red;
      case 'mengerjakan': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'selesai': return Icons.check_circle;
      case 'melanggar': return Icons.warning_amber;
      case 'mengerjakan': return Icons.edit_note;
      default: return Icons.hourglass_empty;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'selesai': return 'SELESAI';
      case 'melanggar': return 'MELANGGAR';
      case 'mengerjakan': return 'MENGERJAKAN';
      default: return 'BELUM MULAI';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Live Monitoring", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(exam.judul, style: const TextStyle(fontSize: 11, color: Colors.white60),
              overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          // Live indicator
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: exam.isOngoing ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: exam.isOngoing
                      ? [const BoxShadow(color: Colors.white, blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(exam.isOngoing ? "LIVE" : "OFFLINE",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'siswa')
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allUsers = userSnap.data!.docs
              .map((d) => UserAccount.fromFirestore(d))
              .toList();
          final peserta = allUsers.where((s) => s.matchJenjang(exam.jenjang)).toList();

          // Count by status
          final selesaiList = peserta.where((s) => _statusForExam(s) == 'selesai').toList();
          final melanggarList = peserta.where((s) => _statusForExam(s) == 'melanggar').toList();
          final mengerjakanList = peserta.where((s) => _statusForExam(s) == 'mengerjakan').toList();
          final belumList = peserta.where((s) => _statusForExam(s) == 'belum mulai').toList();

          // Filter
          var filtered = peserta.where((s) {
            final matchSearch = _search.isEmpty ||
                s.nama.toLowerCase().contains(_search.toLowerCase()) ||
                s.kode.toLowerCase().contains(_search.toLowerCase());
            final status = _statusForExam(s);
            final matchFilter = _filter == 'semua' ||
                (_filter == 'belum' && status == 'belum mulai') ||
                status == _filter;
            return matchSearch && matchFilter;
          }).toList();

          // Group by class
          final Map<String, List<UserAccount>> grouped = {};
          for (var s in filtered) {
            grouped.putIfAbsent(s.classFolder, () => []).add(s);
          }
          final sortedKeys = grouped.keys.toList()..sort();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('exam').doc(exam.id)
                .collection('draft_jawaban')
                .snapshots(),
            builder: (context, draftSnap) {
              // Map siswaId → draft data for progress
              final Map<String, Map<String, dynamic>> draftMap = {};
              if (draftSnap.hasData) {
                for (final doc in draftSnap.data!.docs) {
                  draftMap[doc.id] = doc.data() as Map<String, dynamic>;
                }
              }

              return Column(children: [
                // ── Summary stats bar ──
                _buildSummaryBar(peserta.length, mengerjakanList.length,
                    selesaiList.length, melanggarList.length, belumList.length),

                // ── Countdown / Time info ──
                _buildTimeBar(),

                // ── Search + filter ──
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Column(children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Cari nama atau kode siswa...",
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _filterChip('semua', 'Semua (${peserta.length})', Colors.blueGrey),
                        const SizedBox(width: 6),
                        _filterChip('mengerjakan', '🖊 Ujian (${mengerjakanList.length})', Colors.indigo),
                        const SizedBox(width: 6),
                        _filterChip('selesai', '✓ Selesai (${selesaiList.length})', Colors.green),
                        const SizedBox(width: 6),
                        _filterChip('melanggar', '⚠ Langgar (${melanggarList.length})', Colors.red),
                        const SizedBox(width: 6),
                        _filterChip('belum', '⏳ Belum (${belumList.length})', Colors.grey),
                      ]),
                    ),
                  ]),
                ),

                // ── Student list ──
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 50, color: Colors.grey),
                            SizedBox(height: 10),
                            Text("Tidak ada siswa ditemukan.",
                                style: TextStyle(color: Colors.grey)),
                          ]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: sortedKeys.length,
                          itemBuilder: (ctx, idx) {
                            final kelas = sortedKeys[idx];
                            final siswaKelas = grouped[kelas]!;
                            return _buildClassGroup(kelas, siswaKelas, draftMap);
                          },
                        ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }

  // ── Summary stats bar ──
  Widget _buildSummaryBar(int total, int mengerjakan, int selesai, int melanggar, int belum) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0F172A), Colors.indigo.shade900],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
      ),
      child: Column(children: [
        Row(children: [
          _statBox(total.toString(), "Total", Colors.white, Icons.groups),
          _statBox(mengerjakan.toString(), "Ujian", Colors.blue.shade300, Icons.edit_note),
          _statBox(selesai.toString(), "Selesai", Colors.green.shade300, Icons.check_circle),
          _statBox(melanggar.toString(), "Langgar", Colors.red.shade300, Icons.warning_amber),
          _statBox(belum.toString(), "Belum", Colors.grey.shade400, Icons.hourglass_empty),
        ]),
        if (total > 0) ...[
          const SizedBox(height: 10),
          // Stacked progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(children: [
                if (selesai > 0)
                  Expanded(flex: selesai, child: Container(color: Colors.green.shade400)),
                if (mengerjakan > 0)
                  Expanded(flex: mengerjakan, child: Container(color: Colors.blue.shade400)),
                if (melanggar > 0)
                  Expanded(flex: melanggar, child: Container(color: Colors.red.shade400)),
                if (belum > 0)
                  Expanded(flex: belum, child: Container(color: Colors.grey.shade600)),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "$selesai dari $total selesai (${(selesai / total * 100).toStringAsFixed(0)}%)",
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ]),
    );
  }

  Widget _statBox(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9)),
      ]),
    );
  }

  // ── Time / countdown bar ──
  Widget _buildTimeBar() {
    final now = DateTime.now();
    String timeText;
    Color barColor;
    IconData barIcon;

    if (exam.belumMulai) {
      final diff = exam.waktuMulai.difference(now);
      timeText = "Mulai dalam ${_formatDuration(diff)}";
      barColor = Colors.orange.shade700;
      barIcon = Icons.schedule;
    } else if (exam.isOngoing) {
      final diff = exam.waktuSelesai.difference(now);
      timeText = "Sisa waktu: ${_formatDuration(diff)}";
      barColor = Colors.teal.shade700;
      barIcon = Icons.timer;
    } else {
      timeText = "Ujian telah selesai";
      barColor = Colors.grey.shade600;
      barIcon = Icons.event_available;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: barColor,
      child: Row(children: [
        Icon(barIcon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text(timeText,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(
          "${DateFormat('HH:mm').format(exam.waktuMulai)} — ${DateFormat('HH:mm').format(exam.waktuSelesai)}",
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ]),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "0m";
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return "${h}j ${m}m";
    return "${m}m";
  }

  // ── Filter chip ──
  Widget _filterChip(String value, String label, Color color) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Class group card ──
  Widget _buildClassGroup(String kelas, List<UserAccount> siswa,
      Map<String, Map<String, dynamic>> draftMap) {
    final sK = siswa.where((s) => _statusForExam(s) == 'selesai').length;
    final mK = siswa.where((s) => _statusForExam(s) == 'mengerjakan').length;
    final lK = siswa.where((s) => _statusForExam(s) == 'melanggar').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Column(children: [
        // Class header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(kelas,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text("Kelas $kelas",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            if (mK > 0) _miniChip("$mK ujian", Colors.blue.shade300),
            if (mK > 0) const SizedBox(width: 4),
            if (sK > 0) _miniChip("$sK selesai", Colors.green.shade300),
            if (sK > 0) const SizedBox(width: 4),
            if (lK > 0) _miniChip("$lK langgar", Colors.red.shade300),
          ]),
        ),
        // Student rows
        ...siswa.map((s) => _buildStudentRow(s, draftMap[s.id])),
      ]),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }

  // ── Individual student row ──
  Widget _buildStudentRow(UserAccount s, Map<String, dynamic>? draft) {
    final status = _statusForExam(s);
    final sColor = _statusColor(status);
    final sIcon = _statusIcon(status);
    final sLabel = _statusLabel(status);
    final vCount = s.violationForExam(exam.id);
    final rawExam = s.examStatus[exam.id];
    final proktorCount = (rawExam is Map && rawExam['proktorUnlockCount'] is int)
        ? rawExam['proktorUnlockCount'] as int : 0;

    // Progress from draft
    int answered = 0;
    int lastIndex = 0;
    if (draft != null) {
      final jawaban = draft['jawaban'] as Map<String, dynamic>? ?? {};
      answered = jawaban.values.where((v) => v.toString().isNotEmpty).length;
      lastIndex = (draft['lastSoalIndex'] as int?) ?? 0;
    }
    // If selesai, show full progress
    if (status == 'selesai') answered = _totalSoal;

    final progressPct = _totalSoal > 0 ? answered / _totalSoal : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        // Status avatar
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: sColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: sColor, width: 1.5),
          ),
          child: Icon(sIcon, color: sColor, size: 18),
        ),
        const SizedBox(width: 12),

        // Name + progress
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(s.nama,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              if (vCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.warning, size: 10, color: Colors.red.shade700),
                    const SizedBox(width: 2),
                    Text('$vCount', style: TextStyle(fontSize: 9, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
              if (proktorCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.vpn_key, size: 10, color: Colors.orange.shade700),
                    const SizedBox(width: 2),
                    Text('$proktorCount', style: TextStyle(fontSize: 9, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            // Progress bar
            if (status == 'mengerjakan' || status == 'selesai') ...[
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressPct,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        status == 'selesai' ? Colors.green : Colors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _totalSoal > 0 ? "$answered/$_totalSoal" : "$answered soal",
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
              ]),
              if (status == 'mengerjakan' && _totalSoal > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    "Sedang di soal ${lastIndex + 1}",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ),
            ] else ...[
              Text(
                "Kode: ${s.kode}",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ]),
        ),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: sColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(sLabel,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
