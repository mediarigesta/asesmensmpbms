part of '../main.dart';

// ============================================================
// HISTORY UJIAN — LIST
// ============================================================
class ExamHistoryList extends StatefulWidget {
  /// null = tampilkan semua (admin). Set<String> = filter mapel guru.
  final Set<String>? filterMapel;
  const ExamHistoryList({super.key, this.filterMapel});
  @override
  State<ExamHistoryList> createState() => _ExamHistoryListState();
}

class _ExamHistoryListState extends State<ExamHistoryList> {
  String _filterStatus = "semua";
  String _search = "";

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Cari judul atau mapel...",
                prefixIcon: const Icon(Icons.search),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterStatus,
                items: const [
                  DropdownMenuItem(value: "semua", child: Text("Semua")),
                  DropdownMenuItem(
                      value: "ongoing", child: Text("Berlangsung")),
                  DropdownMenuItem(
                      value: "selesai", child: Text("Selesai")),
                  DropdownMenuItem(
                      value: "belum", child: Text("Belum Mulai")),
                ],
                onChanged: (v) => setState(() => _filterStatus = v!),
              ),
            ),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('exam')
              .orderBy('waktuMulai', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            var exams = snap.data!.docs
                .map((d) => ExamData.fromFirestore(d))
                .toList();

            // Filter berdasarkan mapelRoles guru (jika bukan admin)
            if (widget.filterMapel != null && widget.filterMapel!.isNotEmpty) {
              exams = exams.where((e) => widget.filterMapel!.contains(e.mapel)).toList();
            }

            if (_search.isNotEmpty) {
              exams = exams
                  .where((e) =>
              e.judul
                  .toLowerCase()
                  .contains(_search.toLowerCase()) ||
                  e.mapel
                      .toLowerCase()
                      .contains(_search.toLowerCase()))
                  .toList();
            }
            if (_filterStatus == "ongoing") {
              exams = exams.where((e) => e.isOngoing).toList();
            } else if (_filterStatus == "selesai") {
              exams = exams.where((e) => e.sudahSelesai).toList();
            } else if (_filterStatus == "belum") {
              exams = exams.where((e) => e.belumMulai).toList();
            }

            if (exams.isEmpty) {
              return const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_edu, size: 60, color: Colors.grey),
                      SizedBox(height: 12),
                      Text("Tidak ada data ujian.",
                          style: TextStyle(color: Colors.grey)),
                    ]),
              );
            }

            // Group exams by mapel
            final Map<String, List<ExamData>> byMapel = {};
            for (final e in exams) {
              final key = e.mapel.isNotEmpty ? e.mapel : 'Lainnya';
              byMapel.putIfAbsent(key, () => []).add(e);
            }
            final sortedMapels = byMapel.keys.toList()..sort();

            return ListView(
              padding: const EdgeInsets.all(14),
              children: sortedMapels.map((mapel) {
                final mapelExams = byMapel[mapel]!;
                final ongoingCount = mapelExams.where((e) => e.isOngoing).length;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade50,
                      child: Icon(Icons.folder_rounded, color: Colors.indigo.shade400, size: 22),
                    ),
                    title: Text(mapel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Row(children: [
                      Text('${mapelExams.length} ujian', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (ongoingCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                          child: Text('$ongoingCount aktif', style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ],
                    ]),
                    initiallyExpanded: sortedMapels.length == 1,
                    children: mapelExams.map((e) {
                      Color statusColor;
                      String statusLabel;
                      IconData statusIcon;

                      if (e.isOngoing) {
                        statusColor = Colors.green;
                        statusLabel = "BERLANGSUNG";
                        statusIcon = Icons.play_circle;
                      } else if (e.sudahSelesai) {
                        statusColor = Colors.grey;
                        statusLabel = "SELESAI";
                        statusIcon = Icons.check_circle;
                      } else {
                        statusColor = Colors.orange;
                        statusLabel = "BELUM MULAI";
                        statusIcon = Icons.schedule;
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: statusColor,
                          child: Icon(statusIcon, color: Colors.white, size: 16),
                        ),
                        title: Text(e.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${e.jenjang}  •  ${DateFormat('dd MMM yyyy, HH:mm').format(e.waktuMulai)} — ${DateFormat('HH:mm').format(e.waktuSelesai)}",
                                style: const TextStyle(fontSize: 11)),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                              child: Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 9)),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.bar_chart, color: Colors.blue, size: 20),
                            tooltip: "Lihat Detail",
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => ExamHistoryScreen(exam: e))),
                          ),
                          if (e.sudahSelesai)
                            IconButton(
                              icon: const Icon(Icons.replay, color: Colors.teal, size: 20),
                              tooltip: "Gunakan Ulang",
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => ExamEditScreen(exam: e, isReuse: true))),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                              tooltip: "Edit Ujian",
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => ExamEditScreen(exam: e, isReuse: false))),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            tooltip: "Hapus",
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Hapus Ujian?"),
                                  content: Text("Yakin hapus \"${e.judul}\"?\nAksi tidak bisa dibatalkan."),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text("Batal")),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text("Hapus"),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await FirebaseFirestore.instance
                                    .collection('exam')
                                    .doc(e.id)
                                    .delete();
                              }
                            },
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    ]);
  }
}

