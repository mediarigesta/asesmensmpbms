const fs = require('fs');
const file = 'lib/main.dart';
let src = fs.readFileSync(file, 'utf8');
let count = 0;

function replace(oldStr, newStr, label) {
  if (!src.includes(oldStr)) {
    console.error('NOT FOUND: ' + label);
    process.exit(1);
  }
  src = src.replace(oldStr, newStr);
  count++;
  console.log('OK: ' + label);
}

// ── 1. Guru breakpoint 1024 → 900 ──────────────────────────────────────────
replace(
  'if (MediaQuery.of(context).size.width >= 1024) return _buildWideLayout(context);',
  'if (MediaQuery.of(context).size.width >= 900) return _buildWideLayout(context);',
  'Guru breakpoint 1024→900'
);

// ── 2. Admin breakpoint 1024 → 900 ─────────────────────────────────────────
replace(
  'if (MediaQuery.of(context).size.width >= 1024) {\n      return _buildAdminWideLayout(context);',
  'if (MediaQuery.of(context).size.width >= 900) {\n      return _buildAdminWideLayout(context);',
  'Admin breakpoint 1024→900'
);

// ── 3. ExamData: add fields ──────────────────────────────────────────────────
replace(
  '  final String status;\n\n  ExamData({',
  '  final String status;\n  final String mode;\n  final DateTime? createdAt;\n  final String kategori;\n  final String creatorName;\n\n  ExamData({',
  'ExamData add fields'
);

// ── 4. ExamData constructor defaults ────────────────────────────────────────
replace(
  '    this.status = \'published\',\n  });',
  '    this.status = \'published\',\n    this.mode = \'form\',\n    this.createdAt,\n    this.kategori = \'\',\n    this.creatorName = \'\',\n  });',
  'ExamData constructor defaults'
);

// ── 5. ExamData.fromFirestore ────────────────────────────────────────────────
replace(
  '      status: data[\'status\'] ?? \'published\',\n    );',
  '      status: data[\'status\'] ?? \'published\',\n      mode: data[\'mode\'] ?? \'form\',\n      createdAt: (data[\'createdAt\'] as Timestamp?)?.toDate(),\n      kategori: data[\'kategori\'] ?? \'\',\n      creatorName: data[\'creatorName\'] ?? \'\',\n    );',
  'ExamData.fromFirestore add fields'
);

// ── 6. ExamCreatorForm widget: add creatorName param ────────────────────────
replace(
  '  final Set<String>? allowedMapel;\n  const ExamCreatorForm({super.key, this.allowedMapel});',
  '  final Set<String>? allowedMapel;\n  final String? creatorName;\n  const ExamCreatorForm({super.key, this.allowedMapel, this.creatorName});',
  'ExamCreatorForm add creatorName param'
);

// ── 7. _ExamCreatorFormState: add _selKategori ──────────────────────────────
replace(
  '  String? _selMapel, _selKelas;',
  '  String? _selMapel, _selKelas, _selKategori;',
  '_ExamCreatorFormState add _selKategori'
);

// ── 8. _stepData(): add kategori dropdown after jenjang ─────────────────────
replace(
  '          _drop("Pilih Jenjang / Kelas", _selKelas,\n              ["Kelas 7", "Kelas 8", "Kelas 9"],\n                  (v) => setState(() => _selKelas = v)),\n          const SizedBox(height: 28),',
  '          _drop("Pilih Jenjang / Kelas", _selKelas,\n              ["Kelas 7", "Kelas 8", "Kelas 9"],\n                  (v) => setState(() => _selKelas = v)),\n          const SizedBox(height: 14),\n          _drop("Kategori Ujian", _selKategori,\n              ["Sumatif", "Formatif", "Harian", "UTS", "UAS"],\n                  (v) => setState(() => _selKategori = v)),\n          const SizedBox(height: 28),',
  '_stepData add kategori dropdown'
);

// ── 9. _saveExam(): save kategori + creatorName to Firestore ─────────────────
replace(
  '        \'createdAt\'  : FieldValue.serverTimestamp(),\n        \'status\'     : asDraft ? \'draft\' : \'published\',',
  '        \'createdAt\'  : FieldValue.serverTimestamp(),\n        \'status\'     : asDraft ? \'draft\' : \'published\',\n        \'kategori\'   : _selKategori ?? \'\',\n        \'creatorName\': widget.creatorName ?? \'\',',
  '_saveExam add kategori+creatorName'
);

// ── 10. Replace _examCardWide with enriched version ─────────────────────────
const oldGuruCard = `  Widget _examCardWide(ExamData e) {
    final isDraft = e.isDraft;
    final isOngoing = e.isOngoing && !isDraft;
    final isSelesai = e.sudahSelesai && !isDraft;
    final Color statusColor = isDraft
        ? Colors.orange
        : isOngoing
            ? Colors.green
            : isSelesai
                ? Colors.grey
                : Colors.blue;
    final String statusLabel = isDraft
        ? 'Draft'
        : isOngoing
            ? 'Berlangsung'
            : isSelesai
                ? 'Selesai'
                : 'Terjadwal';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.quiz_outlined,
              color: statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.judul,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text('' + e.mapel + '  •  ' + e.jenjang,
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11)),
                if (!isDraft) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM, HH:mm').format(e.waktuMulai) + ' — ' + DateFormat('HH:mm').format(e.waktuSelesai),
                    style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10),
                  ),
                ],
              ]),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Text(statusLabel,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        if (isDraft)
          IconButton(
            icon: const Icon(Icons.publish_outlined, size: 18),
            tooltip: 'Terbitkan',
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('exam')
                  .doc(e.id)
                  .update({'status': 'published'});
            },
          ),
      ]),
    );
  }`;

const newGuruCard = `  Widget _examCardWide(ExamData e) {
    final isDraft = e.isDraft;
    final isOngoing = e.isOngoing && !isDraft;
    final isSelesai = e.sudahSelesai && !isDraft;
    final Color statusColor = isDraft
        ? Colors.orange
        : isOngoing ? Colors.green : isSelesai ? Colors.grey : Colors.blue;
    final String statusLabel = isDraft
        ? 'Draft'
        : isOngoing ? 'Berlangsung' : isSelesai ? 'Selesai' : 'Terjadwal';
    final bool isNativeMode = e.mode == 'native';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.quiz_outlined, color: statusColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(e.mapel + '  •  ' + e.jenjang, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ])),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          if (isDraft) ...[
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.publish_outlined, size: 18), tooltip: 'Terbitkan', onPressed: () async {
              await FirebaseFirestore.instance.collection('exam').doc(e.id).update({'status': 'published'});
            }),
          ],
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (e.kategori.isNotEmpty) _examBadge(e.kategori, Colors.purple.shade100, Colors.purple.shade700),
          _examBadge(isNativeMode ? 'Via Aplikasi' : 'Via Google Form', Colors.blue.shade50, Colors.blue.shade600),
          if (!isDraft) _examBadge(DateFormat('dd MMM, HH:mm').format(e.waktuMulai) + ' — ' + DateFormat('HH:mm').format(e.waktuSelesai), Colors.grey.shade100, Colors.grey.shade600),
        ]),
        if (e.creatorName.isNotEmpty || e.createdAt != null) ...[
          const SizedBox(height: 6),
          DefaultTextStyle(
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
            child: Row(children: [
              if (e.creatorName.isNotEmpty) ...[
                const Icon(Icons.person_outline, size: 11, color: Colors.grey),
                const SizedBox(width: 3),
                Text(e.creatorName),
                const SizedBox(width: 10),
              ],
              if (e.createdAt != null) ...[
                const Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey),
                const SizedBox(width: 3),
                Text('Diterbitkan ' + DateFormat('dd MMM yyyy').format(e.createdAt!)),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _examBadge(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w600)),
  );`;

replace(oldGuruCard, newGuruCard, 'Replace _examCardWide with enriched version');

// ── 11. Replace _adminExamCard with enriched version ─────────────────────────
const oldAdminCard = `  Widget _adminExamCard(ExamData e) {
    final isDraft = e.isDraft;
    final isOngoing = e.isOngoing && !isDraft;
    final isSelesai = e.sudahSelesai && !isDraft;
    final Color statusColor = isDraft
        ? Colors.orange
        : isOngoing
            ? Colors.green
            : isSelesai
                ? Colors.grey
                : Colors.blue;
    final String statusLabel = isDraft
        ? 'Draft'
        : isOngoing
            ? 'Berlangsung'
            : isSelesai
                ? 'Selesai'
                : 'Terjadwal';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.quiz_outlined,
              color: statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.judul,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text('' + e.mapel + '  •  ' + e.jenjang,
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11)),
                if (!isDraft) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM, HH:mm').format(e.waktuMulai) + ' — ' + DateFormat('HH:mm').format(e.waktuSelesai),
                    style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10),
                  ),
                ],
              ]),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Text(statusLabel,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        if (isDraft)
          IconButton(
            icon: const Icon(Icons.publish_outlined, size: 18),
            tooltip: 'Terbitkan',
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('exam')
                  .doc(e.id)
                  .update({'status': 'published'});
            },
          ),
      ]),
    );
  }`;

const newAdminCard = `  Widget _adminExamCard(ExamData e) {
    final isDraft = e.isDraft;
    final isOngoing = e.isOngoing && !isDraft;
    final isSelesai = e.sudahSelesai && !isDraft;
    final Color statusColor = isDraft
        ? Colors.orange
        : isOngoing ? Colors.green : isSelesai ? Colors.grey : Colors.blue;
    final String statusLabel = isDraft
        ? 'Draft'
        : isOngoing ? 'Berlangsung' : isSelesai ? 'Selesai' : 'Terjadwal';
    final bool isNativeMode = e.mode == 'native';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.quiz_outlined, color: statusColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(e.mapel + '  •  ' + e.jenjang, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ])),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          if (isDraft) ...[
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.publish_outlined, size: 18), tooltip: 'Terbitkan', onPressed: () async {
              await FirebaseFirestore.instance.collection('exam').doc(e.id).update({'status': 'published'});
            }),
          ],
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (e.kategori.isNotEmpty) _adminExamBadge(e.kategori, Colors.purple.shade100, Colors.purple.shade700),
          _adminExamBadge(isNativeMode ? 'Via Aplikasi' : 'Via Google Form', Colors.blue.shade50, Colors.blue.shade600),
          if (!isDraft) _adminExamBadge(DateFormat('dd MMM, HH:mm').format(e.waktuMulai) + ' — ' + DateFormat('HH:mm').format(e.waktuSelesai), Colors.grey.shade100, Colors.grey.shade600),
        ]),
        if (e.creatorName.isNotEmpty || e.createdAt != null) ...[
          const SizedBox(height: 6),
          DefaultTextStyle(
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
            child: Row(children: [
              if (e.creatorName.isNotEmpty) ...[
                const Icon(Icons.person_outline, size: 11, color: Colors.grey),
                const SizedBox(width: 3),
                Text(e.creatorName),
                const SizedBox(width: 10),
              ],
              if (e.createdAt != null) ...[
                const Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey),
                const SizedBox(width: 3),
                Text('Diterbitkan ' + DateFormat('dd MMM yyyy').format(e.createdAt!)),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _adminExamBadge(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w600)),
  );`;

replace(oldAdminCard, newAdminCard, 'Replace _adminExamCard with enriched version');

// ── Write ────────────────────────────────────────────────────────────────────
fs.writeFileSync(file, src, 'utf8');
console.log('\nDone! ' + count + ' replacements applied.');
