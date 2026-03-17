part of '../main.dart';

// ============================================================
// BANK SOAL — Manajemen Bank Soal Guru/Admin
// ============================================================
class BankSoalScreen extends StatefulWidget {
  final Set<String>? filterMapel; // null = admin (semua mapel)
  const BankSoalScreen({super.key, this.filterMapel});
  @override
  State<BankSoalScreen> createState() => _BankSoalScreenState();
}

class _BankSoalScreenState extends State<BankSoalScreen> {
  String? _selMapel;
  String? _selTopik;
  String? _selTingkat;
  String _search = '';
  bool _importing = false;

  static const _tingkatList = ['mudah', 'sedang', 'sulit'];
  static const _tingkatLabels = {'mudah': 'Mudah', 'sedang': 'Sedang', 'sulit': 'Sulit'};
  static const _tingkatColors = {
    'mudah': Colors.green,
    'sedang': Colors.orange,
    'sulit': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.library_books, color: Color(0xFF0F172A), size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text("Bank Soal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
            _buildActionButton(Icons.file_upload_outlined, "Import dari Ujian", Colors.teal, _showImportFromExamDialog),
            const SizedBox(width: 6),
            _buildActionButton(Icons.add_circle_outline, "Tambah Soal", const Color(0xFF0F172A), _showAddSoalDialog),
          ]),
          const SizedBox(height: 10),
          // Filter row
          Row(children: [
            Expanded(child: _buildFilterDropdown()),
            const SizedBox(width: 8),
            Expanded(child: _buildTopikFilter()),
            const SizedBox(width: 8),
            Expanded(child: _buildTingkatFilter()),
          ]),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: "Cari pertanyaan...",
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _search = v),
          ),
        ]),
      ),
      // Body
      Expanded(
        child: _buildBankSoalList(),
      ),
    ]);
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('mapel').snapshots(),
      builder: (ctx, snap) {
        final mapelList = <String>[];
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final name = doc['nama']?.toString() ?? doc.id;
            if (widget.filterMapel == null || widget.filterMapel!.contains(name)) {
              mapelList.add(name);
            }
          }
        }
        return DropdownButtonFormField<String>(
          value: _selMapel,
          decoration: InputDecoration(
            labelText: "Mapel",
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items: [
            const DropdownMenuItem(value: null, child: Text("Semua Mapel", style: TextStyle(fontSize: 12))),
            ...mapelList.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))),
          ],
          onChanged: (v) => setState(() { _selMapel = v; _selTopik = null; }),
        );
      },
    );
  }

  Widget _buildTopikFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: _selMapel != null
          ? FirebaseFirestore.instance.collection('bank_soal').where('mapel', isEqualTo: _selMapel).snapshots()
          : FirebaseFirestore.instance.collection('bank_soal').snapshots(),
      builder: (ctx, snap) {
        final topikSet = <String>{};
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final t = (doc.data() as Map)['topik']?.toString() ?? '';
            if (t.isNotEmpty) topikSet.add(t);
          }
        }
        final topikList = topikSet.toList()..sort();
        return DropdownButtonFormField<String>(
          value: _selTopik,
          decoration: InputDecoration(
            labelText: "Topik",
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items: [
            const DropdownMenuItem(value: null, child: Text("Semua Topik", style: TextStyle(fontSize: 12))),
            ...topikList.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))),
          ],
          onChanged: (v) => setState(() => _selTopik = v),
        );
      },
    );
  }

  Widget _buildTingkatFilter() {
    return DropdownButtonFormField<String>(
      value: _selTingkat,
      decoration: InputDecoration(
        labelText: "Tingkat",
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      style: const TextStyle(fontSize: 12, color: Colors.black87),
      items: [
        const DropdownMenuItem(value: null, child: Text("Semua Tingkat", style: TextStyle(fontSize: 12))),
        ..._tingkatList.map((t) => DropdownMenuItem(value: t, child: Text(_tingkatLabels[t]!, style: const TextStyle(fontSize: 12)))),
      ],
      onChanged: (v) => setState(() => _selTingkat = v),
    );
  }

  Widget _buildBankSoalList() {
    Query query = FirebaseFirestore.instance.collection('bank_soal').orderBy('createdAt', descending: true);
    if (_selMapel != null) query = query.where('mapel', isEqualTo: _selMapel);
    if (_selTopik != null) query = query.where('topik', isEqualTo: _selTopik);
    if (_selTingkat != null) query = query.where('tingkatKesulitan', isEqualTo: _selTingkat);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snap.data!.docs;

        // Client-side search filter
        if (_search.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final pertanyaan = (data['pertanyaan'] ?? '').toString().toLowerCase();
            return pertanyaan.contains(_search.toLowerCase());
          }).toList();
        }

        // Client-side mapel filter for non-admin
        if (widget.filterMapel != null) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return widget.filterMapel!.contains(data['mapel']?.toString() ?? '');
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.library_books_outlined, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text("Belum ada soal di bank.", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              const Text("Tambah soal baru atau import dari ujian yang sudah ada.",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ));
        }

        // Group by mapel + topik
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final key = "${data['mapel'] ?? 'Lainnya'} — ${data['topik'] ?? 'Tanpa Topik'}";
          grouped.putIfAbsent(key, () => []).add(doc);
        }
        final sortedKeys = grouped.keys.toList()..sort();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Stats
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  _bankStatCard("Total Soal", "${docs.length}", Colors.blue, Icons.quiz),
                  const SizedBox(width: 8),
                  _bankStatCard("Topik", "${grouped.length}", Colors.teal, Icons.topic),
                  const SizedBox(width: 8),
                  _bankStatCard("Mudah", "${docs.where((d) => (d.data() as Map)['tingkatKesulitan'] == 'mudah').length}", Colors.green, Icons.sentiment_satisfied),
                  const SizedBox(width: 8),
                  _bankStatCard("Sulit", "${docs.where((d) => (d.data() as Map)['tingkatKesulitan'] == 'sulit').length}", Colors.red, Icons.sentiment_very_dissatisfied),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            ...sortedKeys.map((key) {
              final items = grouped[key]!;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  initiallyExpanded: sortedKeys.length <= 3,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0F172A),
                    radius: 16,
                    child: Text("${items.length}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Wrap(spacing: 4, children: [
                    _bankBadge("${items.where((d) => (d.data() as Map)['tingkatKesulitan'] == 'mudah').length} mudah", Colors.green),
                    _bankBadge("${items.where((d) => (d.data() as Map)['tingkatKesulitan'] == 'sedang').length} sedang", Colors.orange),
                    _bankBadge("${items.where((d) => (d.data() as Map)['tingkatKesulitan'] == 'sulit').length} sulit", Colors.red),
                  ]),
                  children: items.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final tingkat = data['tingkatKesulitan']?.toString() ?? 'sedang';
                    final tColor = _tingkatColors[tingkat] ?? Colors.orange;
                    final tipe = data['tipe']?.toString() ?? 'pilihanGanda';
                    return ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_tingkatLabels[tingkat] ?? 'Sedang',
                            style: TextStyle(fontSize: 9, color: tColor, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        (data['pertanyaan'] ?? '').toString(),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Wrap(spacing: 4, children: [
                        _bankBadge(tipe == 'pilihanGanda' ? 'PG' : tipe == 'benarSalah' ? 'B/S' : 'Uraian', Colors.blueGrey),
                        if ((data['kunciJawaban'] ?? '').toString().isNotEmpty)
                          _bankBadge("Kunci: ${data['kunciJawaban']}", Colors.purple),
                        _bankBadge("Skor: ${data['skor'] ?? 1}", Colors.teal),
                      ]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                          tooltip: "Edit",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showEditSoalDialog(doc.id, data),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          tooltip: "Hapus",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmDelete(doc.id),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              );
            }),
          ]),
        );
      },
    );
  }

  Widget _bankStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _bankBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
  );

  // ── Dialog: Tambah Soal Manual ──
  void _showAddSoalDialog() {
    String mapel = _selMapel ?? '';
    String topik = '';
    String tingkat = 'sedang';
    String tipe = 'pilihanGanda';
    String pertanyaan = '';
    List<String> pilihan = ['', '', '', '', ''];
    String kunciJawaban = '';
    int skor = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.add_circle, color: Color(0xFF0F172A)),
            SizedBox(width: 8),
            Text("Tambah Soal ke Bank", style: TextStyle(fontSize: 16)),
          ]),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Mapel
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('mapel').snapshots(),
                builder: (c, s) {
                  final list = <String>[];
                  if (s.hasData) {
                    for (final d in s.data!.docs) {
                      final n = d['nama']?.toString() ?? d.id;
                      if (widget.filterMapel == null || widget.filterMapel!.contains(n)) list.add(n);
                    }
                  }
                  return DropdownButtonFormField<String>(
                    value: mapel.isNotEmpty ? mapel : null,
                    decoration: const InputDecoration(labelText: "Mata Pelajaran *", isDense: true, border: OutlineInputBorder()),
                    items: list.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setSt(() => mapel = v ?? ''),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: topik,
                decoration: const InputDecoration(labelText: "Topik / Bab *", isDense: true, border: OutlineInputBorder()),
                onChanged: (v) => topik = v,
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: tingkat,
                  decoration: const InputDecoration(labelText: "Tingkat Kesulitan", isDense: true, border: OutlineInputBorder()),
                  items: _tingkatList.map((t) => DropdownMenuItem(value: t, child: Text(_tingkatLabels[t]!))).toList(),
                  onChanged: (v) => setSt(() => tingkat = v ?? 'sedang'),
                )),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<String>(
                  value: tipe,
                  decoration: const InputDecoration(labelText: "Tipe Soal", isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'pilihanGanda', child: Text("Pilihan Ganda")),
                    DropdownMenuItem(value: 'benarSalah', child: Text("Benar/Salah")),
                    DropdownMenuItem(value: 'uraian', child: Text("Uraian")),
                  ],
                  onChanged: (v) => setSt(() => tipe = v ?? 'pilihanGanda'),
                )),
              ]),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: pertanyaan,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Pertanyaan *", isDense: true, border: OutlineInputBorder()),
                onChanged: (v) => pertanyaan = v,
              ),
              if (tipe == 'pilihanGanda') ...[
                const SizedBox(height: 10),
                ...List.generate(5, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextFormField(
                    initialValue: pilihan[i],
                    decoration: InputDecoration(
                      labelText: "Pilihan ${String.fromCharCode(65 + i)}",
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => pilihan[i] = v,
                  ),
                )),
                DropdownButtonFormField<String>(
                  value: kunciJawaban.isNotEmpty ? kunciJawaban : null,
                  decoration: const InputDecoration(labelText: "Kunci Jawaban *", isDense: true, border: OutlineInputBorder()),
                  items: List.generate(5, (i) => DropdownMenuItem(
                    value: String.fromCharCode(65 + i),
                    child: Text(String.fromCharCode(65 + i)),
                  )),
                  onChanged: (v) => kunciJawaban = v ?? '',
                ),
              ] else if (tipe == 'benarSalah') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: kunciJawaban.isNotEmpty ? kunciJawaban : null,
                  decoration: const InputDecoration(labelText: "Kunci Jawaban *", isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'BENAR', child: Text("Benar")),
                    DropdownMenuItem(value: 'SALAH', child: Text("Salah")),
                  ],
                  onChanged: (v) => kunciJawaban = v ?? '',
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                initialValue: skor.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Skor", isDense: true, border: OutlineInputBorder()),
                onChanged: (v) => skor = int.tryParse(v) ?? 1,
              ),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () async {
                if (mapel.isEmpty || topik.isEmpty || pertanyaan.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lengkapi mapel, topik, dan pertanyaan!"), backgroundColor: Colors.orange),
                  );
                  return;
                }
                final pilihanFormatted = tipe == 'pilihanGanda'
                    ? pilihan.asMap().entries.where((e) => e.value.trim().isNotEmpty)
                        .map((e) => '${String.fromCharCode(65 + e.key)}. ${e.value}').toList()
                    : <String>[];
                await FirebaseFirestore.instance.collection('bank_soal').add({
                  'mapel': mapel,
                  'topik': topik.trim(),
                  'tingkatKesulitan': tingkat,
                  'tipe': tipe,
                  'pertanyaan': pertanyaan.trim(),
                  'gambar': '',
                  'pilihan': pilihanFormatted,
                  'kunciJawaban': kunciJawaban.toUpperCase(),
                  'skor': skor,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Soal berhasil ditambahkan ke bank!"), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialog: Edit Soal ──
  void _showEditSoalDialog(String docId, Map<String, dynamic> data) {
    String topik = data['topik']?.toString() ?? '';
    String tingkat = data['tingkatKesulitan']?.toString() ?? 'sedang';
    String pertanyaan = data['pertanyaan']?.toString() ?? '';
    String kunciJawaban = data['kunciJawaban']?.toString() ?? '';
    int skor = (data['skor'] as num?)?.toInt() ?? 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 8),
            Text("Edit Soal", style: TextStyle(fontSize: 16)),
          ]),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                initialValue: topik,
                decoration: const InputDecoration(labelText: "Topik / Bab", isDense: true, border: OutlineInputBorder()),
                onChanged: (v) => topik = v,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: tingkat,
                decoration: const InputDecoration(labelText: "Tingkat Kesulitan", isDense: true, border: OutlineInputBorder()),
                items: _tingkatList.map((t) => DropdownMenuItem(value: t, child: Text(_tingkatLabels[t]!))).toList(),
                onChanged: (v) => setSt(() => tingkat = v ?? 'sedang'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: pertanyaan,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Pertanyaan", isDense: true, border: OutlineInputBorder()),
                onChanged: (v) => pertanyaan = v,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: kunciJawaban,
                decoration: const InputDecoration(labelText: "Kunci Jawaban", isDense: true, border: OutlineInputBorder()),
                onChanged: (v) => kunciJawaban = v,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: skor.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Skor", isDense: true, border: OutlineInputBorder()),
                onChanged: (v) => skor = int.tryParse(v) ?? 1,
              ),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('bank_soal').doc(docId).update({
                  'topik': topik.trim(),
                  'tingkatKesulitan': tingkat,
                  'pertanyaan': pertanyaan.trim(),
                  'kunciJawaban': kunciJawaban.toUpperCase(),
                  'skor': skor,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Soal berhasil diperbarui!"), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirmation ──
  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Soal?"),
        content: const Text("Soal ini akan dihapus dari bank soal secara permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('bank_soal').doc(docId).delete();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Soal berhasil dihapus!"), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  // ── Dialog: Import dari Ujian ──
  void _showImportFromExamDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.file_upload, color: Colors.teal),
          SizedBox(width: 8),
          Text("Import dari Ujian", style: TextStyle(fontSize: 16)),
        ]),
        content: SizedBox(
          width: 500,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('exam')
                .where('mode', isEqualTo: 'native')
                .snapshots(),
            builder: (c, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final exams = snap.data!.docs.map((d) => ExamData.fromFirestore(d)).toList();
              // Sort by createdAt in memory
              exams.sort((a, b) => b.waktuMulai.compareTo(a.waktuMulai));
              final filtered = widget.filterMapel != null
                  ? exams.where((e) => widget.filterMapel!.contains(e.mapel)).toList()
                  : exams;
              if (filtered.isEmpty) {
                return const Center(child: Text("Tidak ada ujian native ditemukan.", style: TextStyle(color: Colors.grey)));
              }
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final e = filtered[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0F172A),
                      radius: 16,
                      child: const Icon(Icons.quiz, color: Colors.white, size: 14),
                    ),
                    title: Text(e.judul, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text("${e.mapel} • ${e.jenjang} • ${DateFormat('dd MMM yyyy').format(e.waktuMulai)}",
                        style: const TextStyle(fontSize: 11)),
                    trailing: _importing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download, size: 18, color: Colors.teal),
                    onTap: _importing ? null : () => _importFromExam(ctx, e),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tutup")),
        ],
      ),
    );
  }

  Future<void> _importFromExam(BuildContext dialogCtx, ExamData exam) async {
    setState(() => _importing = true);

    // Ask for topik
    String topik = '';
    final topikResult = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Topik Soal"),
          content: TextField(
            decoration: const InputDecoration(
              labelText: "Masukkan topik/bab untuk soal ini",
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => topik = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, topik),
              child: const Text("Import"),
            ),
          ],
        );
      },
    );

    if (topikResult == null) {
      setState(() => _importing = false);
      return;
    }

    try {
      final soalSnap = await FirebaseFirestore.instance
          .collection('exam').doc(exam.id).collection('soal')
          .orderBy('nomor').get();

      final batch = FirebaseFirestore.instance.batch();
      int count = 0;
      for (final doc in soalSnap.docs) {
        final data = doc.data();
        batch.set(FirebaseFirestore.instance.collection('bank_soal').doc(), {
          'mapel': exam.mapel,
          'topik': topikResult.trim().isNotEmpty ? topikResult.trim() : exam.judul,
          'tingkatKesulitan': 'sedang',
          'tipe': data['tipe'] ?? 'pilihanGanda',
          'pertanyaan': data['pertanyaan'] ?? '',
          'gambar': data['gambar'] ?? '',
          'pilihan': data['pilihan'] ?? [],
          'kunciJawaban': data['kunciJawaban'] ?? '',
          'skor': data['skor'] ?? 1,
          'createdAt': FieldValue.serverTimestamp(),
          'sourceExamId': exam.id,
        });
        count++;
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$count soal berhasil diimport dari '${exam.judul}'!"),
          backgroundColor: Colors.green,
        ));
      }
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Gagal import: $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
    setState(() => _importing = false);
  }
}

// ============================================================
// DIALOG: Tarik Soal dari Bank untuk ExamCreatorForm
// ============================================================
Future<List<SoalDraft>?> showBankSoalPickerDialog(BuildContext context, {String? mapel, Set<String>? filterMapel}) async {
  return showDialog<List<SoalDraft>>(
    context: context,
    builder: (ctx) => _BankSoalPickerDialog(mapel: mapel, filterMapel: filterMapel),
  );
}

class _BankSoalPickerDialog extends StatefulWidget {
  final String? mapel;
  final Set<String>? filterMapel;
  const _BankSoalPickerDialog({this.mapel, this.filterMapel});
  @override
  State<_BankSoalPickerDialog> createState() => _BankSoalPickerDialogState();
}

class _BankSoalPickerDialogState extends State<_BankSoalPickerDialog> {
  final Set<String> _selected = {};
  String? _filterTopik;
  String? _filterTingkat;
  String _mode = 'manual'; // manual or auto
  int _autoCount = 10;
  int _autoMudah = 30;
  int _autoSedang = 50;
  int _autoSulit = 20;

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('bank_soal');
    if (widget.mapel != null) query = query.where('mapel', isEqualTo: widget.mapel);
    if (_filterTopik != null) query = query.where('topik', isEqualTo: _filterTopik);
    if (_filterTingkat != null) query = query.where('tingkatKesulitan', isEqualTo: _filterTingkat);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.library_books, color: Color(0xFF0F172A)),
        const SizedBox(width: 8),
        const Expanded(child: Text("Tarik Soal dari Bank", style: TextStyle(fontSize: 16))),
        // Toggle manual/auto
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'manual', label: Text("Manual", style: TextStyle(fontSize: 11))),
            ButtonSegment(value: 'auto', label: Text("Otomatis", style: TextStyle(fontSize: 11))),
          ],
          selected: {_mode},
          onSelectionChanged: (v) => setState(() => _mode = v.first),
          style: ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ]),
      content: SizedBox(
        width: 600,
        height: 500,
        child: _mode == 'auto' ? _buildAutoMode() : _buildManualMode(query),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
        if (_mode == 'manual')
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: _selected.isEmpty ? null : () => _confirmManualSelection(),
            child: Text("Tarik ${_selected.length} Soal"),
          )
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => _confirmAutoSelection(),
            child: Text("Generate $_autoCount Soal"),
          ),
      ],
    );
  }

  Widget _buildManualMode(Query query) {
    return Column(children: [
      // Filters
      Row(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: widget.mapel != null
              ? FirebaseFirestore.instance.collection('bank_soal').where('mapel', isEqualTo: widget.mapel).snapshots()
              : FirebaseFirestore.instance.collection('bank_soal').snapshots(),
          builder: (c, s) {
            final topikSet = <String>{};
            if (s.hasData) {
              for (final d in s.data!.docs) {
                final t = (d.data() as Map)['topik']?.toString() ?? '';
                if (t.isNotEmpty) topikSet.add(t);
              }
            }
            return DropdownButtonFormField<String>(
              value: _filterTopik,
              decoration: const InputDecoration(labelText: "Topik", isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: [
                const DropdownMenuItem(value: null, child: Text("Semua", style: TextStyle(fontSize: 12))),
                ...topikSet.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))),
              ],
              onChanged: (v) => setState(() => _filterTopik = v),
            );
          },
        )),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String>(
          value: _filterTingkat,
          decoration: const InputDecoration(labelText: "Tingkat", isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items: [
            const DropdownMenuItem(value: null, child: Text("Semua", style: TextStyle(fontSize: 12))),
            ...['mudah', 'sedang', 'sulit'].map((t) => DropdownMenuItem(value: t,
                child: Text({'mudah': 'Mudah', 'sedang': 'Sedang', 'sulit': 'Sulit'}[t]!, style: const TextStyle(fontSize: 12)))),
          ],
          onChanged: (v) => setState(() => _filterTingkat = v),
        )),
        const SizedBox(width: 8),
        Text("${_selected.length} dipilih", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Center(child: Text("Tidak ada soal ditemukan.", style: TextStyle(color: Colors.grey)));
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (c, i) {
                final doc = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                final isSelected = _selected.contains(doc.id);
                final tingkat = data['tingkatKesulitan']?.toString() ?? 'sedang';
                final tColor = {'mudah': Colors.green, 'sedang': Colors.orange, 'sulit': Colors.red}[tingkat] ?? Colors.orange;
                return CheckboxListTile(
                  dense: true,
                  value: isSelected,
                  onChanged: (v) => setState(() => v! ? _selected.add(doc.id) : _selected.remove(doc.id)),
                  secondary: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: tColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text({'mudah': 'M', 'sedang': 'S', 'sulit': 'K'}[tingkat] ?? 'S',
                        style: TextStyle(fontSize: 10, color: tColor, fontWeight: FontWeight.bold)),
                  ),
                  title: Text((data['pertanyaan'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                  subtitle: Text("${data['topik'] ?? ''} • Skor: ${data['skor'] ?? 1}",
                      style: const TextStyle(fontSize: 10)),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildAutoMode() {
    return Column(children: [
      Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            const Text("Distribusi Otomatis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text("Soal akan dipilih secara acak dari bank sesuai proporsi tingkat kesulitan.",
                style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        const Text("Jumlah Soal: ", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
          width: 80,
          child: TextFormField(
            initialValue: _autoCount.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            onChanged: (v) => setState(() => _autoCount = int.tryParse(v) ?? 10),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      _proportionSlider("Mudah", Colors.green, _autoMudah, (v) => setState(() {
        _autoMudah = v;
        _autoSedang = (100 - _autoMudah - _autoSulit).clamp(0, 100);
      })),
      _proportionSlider("Sedang", Colors.orange, _autoSedang, (v) => setState(() {
        _autoSedang = v;
        _autoSulit = (100 - _autoMudah - _autoSedang).clamp(0, 100);
      })),
      _proportionSlider("Sulit", Colors.red, _autoSulit, (v) => setState(() {
        _autoSulit = v;
        _autoSedang = (100 - _autoMudah - _autoSulit).clamp(0, 100);
      })),
      const SizedBox(height: 12),
      Text("Total: ${_autoMudah + _autoSedang + _autoSulit}%",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: (_autoMudah + _autoSedang + _autoSulit) == 100 ? Colors.green : Colors.red,
          )),
    ]);
  }

  Widget _proportionSlider(String label, Color color, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 60, child: Text("$label:", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0, max: 100,
            divisions: 20,
            activeColor: color,
            label: "$value%",
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 40, child: Text("$value%", style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Future<void> _confirmManualSelection() async {
    final docs = await Future.wait(
      _selected.map((id) => FirebaseFirestore.instance.collection('bank_soal').doc(id).get()),
    );
    final drafts = <SoalDraft>[];
    for (final doc in docs) {
      if (!doc.exists) continue;
      final d = doc.data()!;
      final tipeStr = d['tipe']?.toString() ?? 'pilihanGanda';
      TipeSoal tipe;
      if (tipeStr == 'benarSalah') {
        tipe = TipeSoal.benarSalah;
      } else if (tipeStr == 'uraian') {
        tipe = TipeSoal.uraian;
      } else {
        tipe = TipeSoal.pilihanGanda;
      }
      final rawPilihan = List<String>.from(d['pilihan'] ?? []);
      // Extract just the text after "A. ", "B. " etc
      final pilihanTexts = rawPilihan.map((p) {
        final match = RegExp(r'^[A-E]\.\s*').firstMatch(p);
        return match != null ? p.substring(match.end) : p;
      }).toList();
      // Pad to 5
      while (pilihanTexts.length < 5) pilihanTexts.add('');

      drafts.add(SoalDraft(
        tipe: tipe,
        pertanyaan: d['pertanyaan']?.toString() ?? '',
        gambarBase64: (d['gambar']?.toString().isNotEmpty ?? false) ? d['gambar'].toString() : null,
        pilihan: pilihanTexts,
        kunciJawaban: d['kunciJawaban']?.toString() ?? '',
        skor: (d['skor'] as num?)?.toInt() ?? 1,
      ));
    }
    if (mounted) Navigator.pop(context, drafts);
  }

  Future<void> _confirmAutoSelection() async {
    if ((_autoMudah + _autoSedang + _autoSulit) != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Proporsi harus berjumlah 100%!"), backgroundColor: Colors.red),
      );
      return;
    }

    final countMudah = (_autoCount * _autoMudah / 100).round();
    final countSulit = (_autoCount * _autoSulit / 100).round();
    final countSedang = _autoCount - countMudah - countSulit;

    Query baseQuery = FirebaseFirestore.instance.collection('bank_soal');
    if (widget.mapel != null) baseQuery = baseQuery.where('mapel', isEqualTo: widget.mapel);

    Future<List<QueryDocumentSnapshot>> getRandomDocs(String tingkat, int count) async {
      final snap = await baseQuery.where('tingkatKesulitan', isEqualTo: tingkat).get();
      final docs = snap.docs.toList()..shuffle(Random());
      return docs.take(count).toList();
    }

    final mudahDocs = await getRandomDocs('mudah', countMudah);
    final sedangDocs = await getRandomDocs('sedang', countSedang);
    final sulitDocs = await getRandomDocs('sulit', countSulit);

    final allDocs = [...mudahDocs, ...sedangDocs, ...sulitDocs]..shuffle(Random());

    final drafts = <SoalDraft>[];
    for (final doc in allDocs) {
      final d = doc.data() as Map<String, dynamic>;
      final tipeStr = d['tipe']?.toString() ?? 'pilihanGanda';
      TipeSoal tipe;
      if (tipeStr == 'benarSalah') {
        tipe = TipeSoal.benarSalah;
      } else if (tipeStr == 'uraian') {
        tipe = TipeSoal.uraian;
      } else {
        tipe = TipeSoal.pilihanGanda;
      }
      final rawPilihan = List<String>.from(d['pilihan'] ?? []);
      final pilihanTexts = rawPilihan.map((p) {
        final match = RegExp(r'^[A-E]\.\s*').firstMatch(p);
        return match != null ? p.substring(match.end) : p;
      }).toList();
      while (pilihanTexts.length < 5) pilihanTexts.add('');

      drafts.add(SoalDraft(
        tipe: tipe,
        pertanyaan: d['pertanyaan']?.toString() ?? '',
        gambarBase64: (d['gambar']?.toString().isNotEmpty ?? false) ? d['gambar'].toString() : null,
        pilihan: pilihanTexts,
        kunciJawaban: d['kunciJawaban']?.toString() ?? '',
        skor: (d['skor'] as num?)?.toInt() ?? 1,
      ));
    }

    if (drafts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak cukup soal di bank!"), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    if (mounted) Navigator.pop(context, drafts);
  }
}
