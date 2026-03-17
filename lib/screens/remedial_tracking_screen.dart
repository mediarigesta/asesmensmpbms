part of '../main.dart';

// ============================================================
// REMEDIAL TRACKING — Lacak status remedial siswa
// ============================================================
class RemedialTrackingScreen extends StatefulWidget {
  final Set<String>? filterMapel;
  const RemedialTrackingScreen({super.key, this.filterMapel});
  @override
  State<RemedialTrackingScreen> createState() => _RemedialTrackingScreenState();
}

class _RemedialTrackingScreenState extends State<RemedialTrackingScreen> {
  String? _selMapel;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.healing, color: Colors.deepOrange, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text("Tracking Remedial", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
          ]),
          const SizedBox(height: 10),
          // Mapel filter
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mapel').snapshots(),
            builder: (ctx, snap) {
              final list = <String>[];
              if (snap.hasData) {
                for (final d in snap.data!.docs) {
                  final n = d['nama']?.toString() ?? d.id;
                  if (widget.filterMapel == null || widget.filterMapel!.contains(n)) list.add(n);
                }
              }
              return DropdownButtonFormField<String>(
                value: _selMapel,
                decoration: InputDecoration(
                  labelText: "Filter Mata Pelajaran",
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                items: [
                  const DropdownMenuItem(value: null, child: Text("Semua Mapel", style: TextStyle(fontSize: 12))),
                  ...list.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))),
                ],
                onChanged: (v) => setState(() => _selMapel = v),
              );
            },
          ),
        ]),
      ),
      // Body
      Expanded(child: _buildRemedialList()),
    ]);
  }

  Widget _buildRemedialList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('exam')
          .where('spiType', whereIn: ['remedial', 'susulan'])
          .snapshots(),
      builder: (ctx, examSnap) {
        if (!examSnap.hasData) return const Center(child: CircularProgressIndicator());

        var exams = examSnap.data!.docs.map((d) => ExamData.fromFirestore(d)).toList();

        // Filter by mapel
        if (_selMapel != null) {
          exams = exams.where((e) => e.mapel == _selMapel).toList();
        }
        if (widget.filterMapel != null) {
          exams = exams.where((e) => widget.filterMapel!.contains(e.mapel)).toList();
        }

        // Sort by date descending
        exams.sort((a, b) => b.waktuMulai.compareTo(a.waktuMulai));

        if (exams.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.healing_outlined, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text("Belum ada ujian remedial/susulan.", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              const Text("Buat ujian remedial dari halaman History Ujian.",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: exams.length,
          itemBuilder: (ctx, i) => _buildRemedialExamCard(exams[i]),
        );
      },
    );
  }

  Widget _buildRemedialExamCard(ExamData exam) {
    final isRemedial = exam.spiType == 'remedial';
    final color = isRemedial ? Colors.deepOrange : Colors.indigo;
    final label = isRemedial ? 'Remedial' : 'Susulan';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(exam.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              _statusBadge(exam),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              _infoBadge(Icons.book_outlined, exam.mapel, Colors.teal),
              _infoBadge(Icons.school_outlined, exam.jenjang, Colors.blue),
              _infoBadge(Icons.calendar_today, DateFormat('dd MMM yyyy').format(exam.waktuMulai), Colors.grey),
              _infoBadge(Icons.access_time, "${DateFormat('HH:mm').format(exam.waktuMulai)} - ${DateFormat('HH:mm').format(exam.waktuSelesai)}", Colors.grey),
              if (exam.kkm > 0) _infoBadge(Icons.flag, "KKM: ${exam.kkm}", Colors.teal),
            ]),
          ]),
        ),

        // Student progress
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users')
              .where('role', isEqualTo: 'siswa').snapshots(),
          builder: (ctx, userSnap) {
            if (!userSnap.hasData) return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );

            final allSiswa = userSnap.data!.docs.map((d) => UserAccount.fromFirestore(d)).toList();
            final peserta = allSiswa.where((s) => s.matchJenjang(exam.jenjang)).toList();

            int selesai = 0, mengerjakan = 0, belum = 0;
            for (final s in peserta) {
              final st = s.statusForExam(exam.id);
              if (st == 'selesai') selesai++;
              else if (st == 'mengerjakan') mengerjakan++;
              else belum++;
            }

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('exam').doc(exam.id)
                  .collection('activity_log').get(),
              builder: (ctx, logSnap) {
                int tuntas = 0, tidakTuntas = 0;
                if (logSnap.hasData && exam.kkm > 0) {
                  for (final doc in logSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>?;
                    final nilai = (data?['totalNilai'] as num?)?.toDouble() ?? 0;
                    if (nilai >= exam.kkm) tuntas++;
                    else tidakTuntas++;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    // Progress stats
                    Row(children: [
                      _statMini("Peserta", "${peserta.length}", Colors.blue),
                      const SizedBox(width: 6),
                      _statMini("Selesai", "$selesai", Colors.green),
                      const SizedBox(width: 6),
                      _statMini("Ujian", "$mengerjakan", Colors.indigo),
                      const SizedBox(width: 6),
                      _statMini("Belum", "$belum", Colors.grey),
                      if (exam.kkm > 0) ...[
                        const SizedBox(width: 6),
                        _statMini("Tuntas", "$tuntas", Colors.green),
                        const SizedBox(width: 6),
                        _statMini("Blm Tuntas", "$tidakTuntas", Colors.red),
                      ],
                    ]),
                    if (peserta.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: peserta.isNotEmpty ? selesai / peserta.length : 0,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$selesai dari ${peserta.length} peserta selesai (${peserta.isNotEmpty ? (selesai / peserta.length * 100).toStringAsFixed(0) : 0}%)",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Action buttons
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ExamHistoryScreen(exam: exam),
                        )),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text("Detail", style: TextStyle(fontSize: 12)),
                      )),
                      if (exam.parentExamId != null) ...[
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _navigateToParentExam(exam.parentExamId!),
                          icon: const Icon(Icons.compare_arrows, size: 16),
                          label: const Text("Ujian Induk", style: TextStyle(fontSize: 12)),
                        )),
                      ],
                    ]),
                  ]),
                );
              },
            );
          },
        ),
      ]),
    );
  }

  Widget _statusBadge(ExamData exam) {
    Color c;
    String label;
    if (exam.isDraft) {
      c = Colors.orange; label = 'Draft';
    } else if (exam.isOngoing) {
      c = Colors.green; label = 'Berlangsung';
    } else if (exam.sudahSelesai) {
      c = Colors.grey; label = 'Selesai';
    } else {
      c = Colors.blue; label = 'Terjadwal';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoBadge(IconData icon, String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 11, color: color)),
    ],
  );

  Widget _statMini(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey)),
      ]),
    ),
  );

  Future<void> _navigateToParentExam(String parentId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('exam').doc(parentId).get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ujian induk tidak ditemukan."), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      final exam = ExamData.fromFirestore(doc);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ExamHistoryScreen(exam: exam),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $e"), backgroundColor: Colors.red,
        ));
      }
    }
  }
}
