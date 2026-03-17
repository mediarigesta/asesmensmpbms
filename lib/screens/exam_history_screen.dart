part of '../main.dart';

class _PdfSiswaRow {
  final String nama, kode, kelas, ruang, status;
  final double nilai;
  final int benar, totalSoal, violations;
  const _PdfSiswaRow({
    required this.nama, required this.kode, required this.kelas,
    required this.ruang, required this.status, required this.nilai,
    required this.benar, required this.totalSoal, required this.violations,
  });
}

class ExamHistoryScreen extends StatefulWidget {
  final ExamData exam;
  const ExamHistoryScreen({super.key, required this.exam});
  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  String _filterStatus = "semua";
  String _search = "";
  int _tabIndex = 0; // 0=Peserta, 1=Statistik, 2=Analisis Butir Soal

  ExamData get exam => widget.exam;

  // Analisis butir soal data (loaded on demand)
  List<Map<String, dynamic>>? _itemAnalysis;
  bool _loadingAnalysis = false;
  double? _avgNilai;
  int? _totalMaxSkor;

  // Score data for Statistik tab (loaded on demand)
  Map<String, Map<String, dynamic>>? _scoreData; // siswaId -> {totalNilai, totalBenar, ...}
  bool _loadingScores = false;

  @override
  void initState() {
    super.initState();
    _loadScores();
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
      case 'melanggar': return Icons.warning;
      case 'mengerjakan': return Icons.edit;
      default: return Icons.schedule;
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

  Widget _filterChip(String value, String label, Color color) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusBadge(ExamData e) {
    Color c;
    String label;
    if (e.isOngoing) {
      c = Colors.green;
      label = "BERLANGSUNG";
    } else if (e.sudahSelesai) {
      c = Colors.grey;
      label = "SELESAI";
    } else {
      c = Colors.orange;
      label = "BELUM MULAI";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.grey),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Expanded(child: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
      ]),
    );
  }

  Widget _statCard(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value.toString(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ── Show Export Dialog with class selection ──
  Future<void> _showExportDialog(List<UserAccount> peserta) async {
    // Ensure scores are loaded
    if (_scoreData == null) await _loadScores();

    // Collect available classes from peserta
    final Map<String, List<UserAccount>> grouped = {};
    for (var s in peserta) {
      grouped.putIfAbsent(s.classFolder, () => []).add(s);
    }
    final sortedClasses = grouped.keys.toList()..sort();
    if (sortedClasses.isEmpty) return;

    final selected = <String>{sortedClasses.first};

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.download_rounded, color: context.bm.primary, size: 22),
            const SizedBox(width: 8),
            const Text('Export Excel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih kelas yang ingin dicetak:',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              ...sortedClasses.map((kelas) {
                final count = grouped[kelas]!.length;
                return CheckboxListTile(
                  value: selected.contains(kelas),
                  onChanged: (v) {
                    setLocal(() {
                      if (v == true) {
                        selected.add(kelas);
                      } else {
                        selected.remove(kelas);
                      }
                    });
                  },
                  title: Text('Kelas $kelas', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('$count siswa', style: const TextStyle(fontSize: 12)),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                );
              }),
              const SizedBox(height: 8),
              Row(children: [
                TextButton(
                  onPressed: () => setLocal(() {
                    selected.addAll(sortedClasses);
                  }),
                  child: const Text('Pilih Semua', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => setLocal(() => selected.clear()),
                  child: const Text('Hapus Semua', style: TextStyle(fontSize: 12)),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.bm.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, Set<String>.from(selected)),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;

    // Build one XLSX with one sheet per selected class
    await _exportExcel(grouped, result.toList()..sort());
  }

  // ── Export XLSX: one file, one sheet per class ──
  Future<void> _exportExcel(Map<String, List<UserAccount>> grouped, List<String> selectedClasses) async {
    try {
      // Determine semester from exam date
      final month = exam.waktuMulai.month;
      final semester = (month >= 7) ? '1' : '2';

      // Determine tahun pelajaran
      final year = exam.waktuMulai.year;
      final tahunPelajaran = (month >= 7)
          ? '$year-${year + 1}'
          : '${year - 1}-$year';

      // Determine jenis ujian from exam title/category
      String jenisUjian = 'Tengah';
      final judulLower = exam.judul.toLowerCase();
      final katLower = exam.kategori.toLowerCase();
      if (judulLower.contains('akhir') || katLower.contains('akhir') ||
          judulLower.contains('uas') || katLower.contains('uas') ||
          judulLower.contains('pat') || katLower.contains('pat')) {
        jenisUjian = 'Akhir';
      } else if (judulLower.contains('tengah') || katLower.contains('tengah') ||
          judulLower.contains('uts') || katLower.contains('uts') ||
          judulLower.contains('pts') || katLower.contains('pts')) {
        jenisUjian = 'Tengah';
      }

      final now = DateTime.now();
      final dicetakPada = DateFormat('dd MMMM, yyyy | HH:mm').format(now);

      // Create Excel workbook
      final excelFile = xl.Excel.createExcel();

      // ── Styles (shared across sheets) ──
      final darkBlue = xl.ExcelColor.fromHexString('FF0F172A');
      final headerBlue = xl.ExcelColor.fromHexString('FF1E3A5F');
      final labelColor = xl.ExcelColor.fromHexString('FF334155');
      final valueColor = xl.ExcelColor.fromHexString('FF1E293B');
      final borderColor = xl.ExcelColor.fromHexString('FFD1D5DB');
      final legerBlue = xl.ExcelColor.fromHexString('FF3B82F6');
      final sumatifBg = xl.ExcelColor.fromHexString('FFDBEAFE');
      final sumatifFg = xl.ExcelColor.fromHexString('FF1E40AF');

      final titleStyle = xl.CellStyle(
        bold: true, fontSize: 16,
        fontColorHex: xl.ExcelColor.white, backgroundColorHex: darkBlue,
        horizontalAlign: xl.HorizontalAlign.Left, verticalAlign: xl.VerticalAlign.Center,
      );
      final labelStyle = xl.CellStyle(bold: true, fontSize: 11, fontColorHex: labelColor);
      final valueStyle = xl.CellStyle(fontSize: 11, fontColorHex: valueColor);
      final thinBorder = xl.Border(borderStyle: xl.BorderStyle.Thin, borderColorHex: borderColor);
      final colHeaderStyle = xl.CellStyle(
        bold: true, fontSize: 11, fontColorHex: xl.ExcelColor.white, backgroundColorHex: headerBlue,
        horizontalAlign: xl.HorizontalAlign.Center, verticalAlign: xl.VerticalAlign.Center,
        leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
      );
      final legerStyle = xl.CellStyle(
        bold: true, fontSize: 10, fontColorHex: xl.ExcelColor.white, backgroundColorHex: legerBlue,
        horizontalAlign: xl.HorizontalAlign.Center, verticalAlign: xl.VerticalAlign.Center,
        leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
      );
      final sumatifStyle = xl.CellStyle(
        bold: true, fontSize: 11, horizontalAlign: xl.HorizontalAlign.Center,
        backgroundColorHex: sumatifBg, fontColorHex: sumatifFg,
        leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
      );
      final dataCellCenter = xl.CellStyle(
        fontSize: 11, horizontalAlign: xl.HorizontalAlign.Center, verticalAlign: xl.VerticalAlign.Center,
        leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
      );
      final dataCellLeft = xl.CellStyle(
        fontSize: 11, horizontalAlign: xl.HorizontalAlign.Left, verticalAlign: xl.VerticalAlign.Center,
        leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
      );
      final dataCellBold = xl.CellStyle(
        fontSize: 11, bold: true, horizontalAlign: xl.HorizontalAlign.Center, verticalAlign: xl.VerticalAlign.Center,
        leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
      );

      // Build one sheet per selected class
      bool isFirst = true;
      for (final kelas in selectedClasses) {
        final peserta = grouped[kelas];
        if (peserta == null || peserta.isEmpty) continue;

        // First sheet: rename default, subsequent: create new
        final sheetName = kelas;
        if (isFirst) {
          excelFile.rename(excelFile.getDefaultSheet()!, sheetName);
          isFirst = false;
        }
        final sheet = excelFile[sheetName];

        // Sort students by kode (absen number)
        final sorted = List<UserAccount>.from(peserta)..sort((a, b) => a.kode.compareTo(b.kode));

        // Helpers for this sheet
        void setCell(int row, int col, String text, [xl.CellStyle? style]) {
          final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          cell.value = xl.TextCellValue(text);
          if (style != null) cell.cellStyle = style;
        }
        void setIntCell(int row, int col, int val, [xl.CellStyle? style]) {
          final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          cell.value = xl.IntCellValue(val);
          if (style != null) cell.cellStyle = style;
        }

        // Row 3: Title
        sheet.merge(xl.CellIndex.indexByString('B4'), xl.CellIndex.indexByString('D4'),
            customValue: xl.TextCellValue('BUKU NILAI SISWA'));
        for (int c = 1; c <= 3; c++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3)).cellStyle = titleStyle;
        }

        // Row 5: Sekolah / Kelas / Dicetak
        setCell(5, 1, 'Sekolah', labelStyle);
        setCell(5, 2, ': SMP Budi Mulia', valueStyle);
        setCell(5, 4, 'Kelas', labelStyle);
        setCell(5, 5, ': $kelas', valueStyle);
        setCell(5, 7, 'Dicetak', labelStyle);
        setCell(5, 8, ': $dicetakPada', valueStyle);

        // Row 6: Tahun Pelajaran / Mata Pelajaran
        setCell(6, 1, 'Tahun Pelajaran', labelStyle);
        setCell(6, 2, ': $tahunPelajaran', valueStyle);
        setCell(6, 4, 'Mata Pelajaran', labelStyle);
        setCell(6, 5, ': ${exam.mapel}', valueStyle);

        // Row 7: Semester / Guru Mapel
        setCell(7, 1, 'Semester', labelStyle);
        setCell(7, 2, ': $semester', valueStyle);
        setCell(7, 4, 'Guru Mapel', labelStyle);
        setCell(7, 5, ': ${exam.creatorName}', valueStyle);

        // Row 10: "Sumatif" header
        setCell(10, 3, 'Sumatif', sumatifStyle);

        // Row 11: Column headers
        setCell(11, 1, 'No Absen', colHeaderStyle);
        setCell(11, 2, 'Nama', colHeaderStyle);
        setCell(11, 3, jenisUjian, colHeaderStyle);

        // Row 14: Dipilih untuk Leger
        setCell(14, 1, 'Dipilih untuk Leger:', legerStyle);
        setCell(14, 2, '', legerStyle);
        setCell(14, 3, jenisUjian, legerStyle);

        // Data rows starting at row 15
        int absen = 0;
        for (final s in sorted) {
          absen++;
          final rowIdx = 14 + absen;
          setIntCell(rowIdx, 1, absen, dataCellCenter);
          setCell(rowIdx, 2, s.nama, dataCellLeft);
          final sd = _scoreData?[s.id];
          if (sd != null) {
            final nilai = ((sd['totalNilai'] as num?)?.toDouble() ?? 0).round();
            setIntCell(rowIdx, 3, nilai, dataCellBold);
          } else {
            setCell(rowIdx, 3, '', dataCellCenter);
          }
        }

        // Column widths
        sheet.setColumnWidth(0, 3);
        sheet.setColumnWidth(1, 15);
        sheet.setColumnWidth(2, 35);
        sheet.setColumnWidth(3, 15);
        sheet.setColumnWidth(4, 15);
        sheet.setColumnWidth(5, 25);
        sheet.setColumnWidth(6, 5);
        sheet.setColumnWidth(7, 12);
        sheet.setColumnWidth(8, 30);
      }

      // Use encode() to get raw bytes WITHOUT triggering web auto-download
      final fileBytes = excelFile.encode();
      if (fileBytes == null) throw Exception('Failed to generate Excel file');

      final classLabel = selectedClasses.length == 1 ? selectedClasses.first : '${selectedClasses.first}-${selectedClasses.last}';
      final fileName = 'Gradebook (${exam.kategori.isNotEmpty ? exam.kategori : 'KM'}) $classLabel ${exam.mapel}.xlsx';

      if (kIsWeb) {
        _downloadBytesForWeb(Uint8List.fromList(fileBytes), fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Excel berhasil diunduh! (${selectedClasses.length} kelas)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ));
        }
      } else {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Simpan Excel',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(fileBytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Excel berhasil disimpan! (${selectedClasses.length} kelas)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving Excel: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Reset semua siswa ──
  Future<void> _resetSemua(List<UserAccount> peserta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text("Reset Semua Status?"),
        ]),
        content: Text(
          "Reset status ${peserta.length} siswa ke Belum Mulai?\n\nSiswa yang sudah selesai juga akan direset.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reset Semua"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final s in peserta) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(s.id),
        {
          'exam_status.${exam.id}.status': 'belum mulai',
          'exam_status.${exam.id}.violationCount': 0,
        },
      );
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Semua status berhasil direset!"),
        backgroundColor: Colors.green,
      ));
    }
  }

  // ── Edit Soal bottom sheet ──
  void _showEditSoalSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text("Edit Soal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("Pilih cara menambahkan soal", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 20),

          // Option 1: Manual
          _editSoalOption(
            icon: Icons.edit_note,
            color: Colors.blue,
            title: "Tambah / Edit Manual",
            subtitle: "Buat soal satu per satu langsung di editor",
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ExamEditScreen(exam: exam, isReuse: false, soalOnly: true),
              ));
            },
          ),
          const SizedBox(height: 10),

          // Option 2: Upload Otomatis dari Word
          _editSoalOption(
            icon: Icons.upload_file,
            color: Colors.teal,
            title: "Upload dari Word (Otomatis)",
            subtitle: "Upload .docx format apapun — soal, pilihan, gambar, kunci jawaban dideteksi otomatis",
            onTap: () {
              Navigator.pop(ctx);
              _pickDocxLocal();
            },
          ),
          
        ]),
      ),
    );
  }

  Widget _editSoalOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ])),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  // ── Upload docx otomatis ──
  Future<void> _pickDocxLocal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['docx'], withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal membaca file"), backgroundColor: Colors.red));
        return;
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mengekstrak soal..."), duration: Duration(seconds: 10)));

      final drafts = DocxLocalParser.parseLocal(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (drafts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tidak ada soal ditemukan. Pastikan soal bernomor (1. 2. 3.) dengan pilihan A-D."),
                backgroundColor: Colors.orange));
        return;
      }

      final withKey = drafts.where((d) => d.kunciJawaban.isNotEmpty).length;
      final withImg = drafts.where((d) => d.gambarBase64 != null).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${drafts.length} soal ditemukan ($withKey kunci, $withImg gambar). Cek & edit sebelum upload."),
          backgroundColor: Colors.green));
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ExamEditScreen(exam: exam, isReuse: false, soalOnly: true, initialSoals: drafts),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // ── Extend waktu ujian ──
  Future<void> _extendWaktu() async {
    int menitTambah = 15;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.timer, color: Colors.blue),
            SizedBox(width: 8),
            Text("Tambah Waktu Ujian"),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Waktu selesai saat ini: ${DateFormat('HH:mm, dd MMM').format(exam.waktuSelesai)}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            const Text("Tambah waktu:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32),
                onPressed: menitTambah > 5 ? () => setSt(() => menitTambah -= 5) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("$menitTambah menit",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                onPressed: () => setSt(() => menitTambah += 5),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              "Waktu baru: ${DateFormat('HH:mm').format(exam.waktuSelesai.add(Duration(minutes: menitTambah)))}",
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Tambahkan"),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final newSelesai = exam.waktuSelesai.add(Duration(minutes: menitTambah));
    await FirebaseFirestore.instance
        .collection('exam')
        .doc(exam.id)
        .update({'waktuSelesai': Timestamp.fromDate(newSelesai)});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("✅ Waktu diperpanjang hingga ${DateFormat('HH:mm').format(newSelesai)}"),
        backgroundColor: Colors.blue,
      ));
    }
  }

  // ── Tab Statistik ──
  Widget _buildStatistikTab(List<UserAccount> peserta) {
    final selesai = peserta.where((s) => _statusForExam(s) == 'selesai').length;
    final melanggar = peserta.where((s) => _statusForExam(s) == 'melanggar').length;
    final mengerjakan = peserta.where((s) => _statusForExam(s) == 'mengerjakan').length;
    final belum = peserta.where((s) => _statusForExam(s) == 'belum mulai').length;

    // Grup per kelas untuk bar chart
    final Map<String, List<UserAccount>> grouped = {};
    for (var s in peserta) {
      grouped.putIfAbsent(s.classFolder, () => []).add(s);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Donut Chart
        const Text("Distribusi Status",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: Row(children: [
            Expanded(
              child: PieChart(PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 45,
                sections: [
                  if (selesai > 0) PieChartSectionData(
                    color: Colors.green,
                    value: selesai.toDouble(),
                    title: "$selesai",
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    radius: 55,
                  ),
                  if (mengerjakan > 0) PieChartSectionData(
                    color: Colors.indigo,
                    value: mengerjakan.toDouble(),
                    title: "$mengerjakan",
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    radius: 55,
                  ),
                  if (melanggar > 0) PieChartSectionData(
                    color: Colors.red,
                    value: melanggar.toDouble(),
                    title: "$melanggar",
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    radius: 55,
                  ),
                  if (belum > 0) PieChartSectionData(
                    color: Colors.grey,
                    value: belum.toDouble(),
                    title: "$belum",
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    radius: 55,
                  ),
                ],
              )),
            ),
            const SizedBox(width: 16),
            // Legend
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _legendItem(Colors.green, "Selesai", selesai),
              _legendItem(Colors.indigo, "Mengerjakan", mengerjakan),
              _legendItem(Colors.red, "Melanggar", melanggar),
              _legendItem(Colors.grey, "Belum Mulai", belum),
            ]),
          ]),
        ),

        // Progress overall
        const SizedBox(height: 20),
        const Text("Progress Keseluruhan",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        if (peserta.isNotEmpty) ...[
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: selesai / peserta.length,
                  minHeight: 14,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(Colors.green),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text("${(selesai / peserta.length * 100).toStringAsFixed(0)}%",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ]),
          const SizedBox(height: 4),
          Text("$selesai dari ${peserta.length} siswa selesai",
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],

        // Bar chart per kelas
        if (sortedKeys.length > 1) ...[
          const SizedBox(height: 24),
          const Text("Status per Kelas",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ...sortedKeys.map((kelas) {
            final list = grouped[kelas]!;
            final s = list.where((x) => _statusForExam(x) == 'selesai').length;
            final m = list.where((x) => _statusForExam(x) == 'mengerjakan').length;
            final l = list.where((x) => _statusForExam(x) == 'melanggar').length;
            final b = list.where((x) => _statusForExam(x) == 'belum mulai').length;
            final total = list.length;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF0F172A),
                      child: Text(kelas,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text("Kelas $kelas", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text("$total siswa", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                  const SizedBox(height: 10),
                  // Stacked bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 12,
                      child: Row(children: [
                        if (s > 0) Expanded(flex: s, child: Container(color: Colors.green)),
                        if (m > 0) Expanded(flex: m, child: Container(color: Colors.indigo)),
                        if (l > 0) Expanded(flex: l, child: Container(color: Colors.red)),
                        if (b > 0) Expanded(flex: b, child: Container(color: Colors.grey.shade300)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (s > 0) _miniChip("$s selesai", Colors.green),
                    if (s > 0) const SizedBox(width: 4),
                    if (m > 0) _miniChip("$m ujian", Colors.indigo),
                    if (m > 0) const SizedBox(width: 4),
                    if (l > 0) _miniChip("$l langgar", Colors.red),
                    if (l > 0) const SizedBox(width: 4),
                    if (b > 0) _miniChip("$b belum", Colors.grey),
                  ]),
                ]),
              ),
            );
          }),
        ],

        // ── Score Distribution Section ──
        const SizedBox(height: 24),
        Row(children: [
          const Text("Distribusi Nilai",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          if (_scoreData == null && !_loadingScores)
            TextButton.icon(
              onPressed: _loadScores,
              icon: const Icon(Icons.download, size: 16),
              label: const Text("Muat Nilai", style: TextStyle(fontSize: 12)),
            ),
          if (_loadingScores)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 8),
        if (_scoreData != null) _buildScoreDistribution(peserta),
        if (_scoreData == null && !_loadingScores)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text("Tekan 'Muat Nilai' untuk melihat distribusi nilai.",
                  style: TextStyle(color: Colors.grey, fontSize: 12))),
            ),
          ),
      ]),
    );
  }

  // ── Score Distribution Widget ──
  Widget _buildScoreDistribution(List<UserAccount> peserta) {
    final scores = <double>[];
    final Map<String, double> scorePerSiswa = {};
    for (final s in peserta) {
      final d = _scoreData?[s.id];
      if (d != null) {
        final val = (d['totalNilai'] as num?)?.toDouble() ?? 0;
        scores.add(val);
        scorePerSiswa[s.id] = val;
      }
    }
    if (scores.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text("Belum ada data nilai.",
              style: TextStyle(color: Colors.grey, fontSize: 12))),
        ),
      );
    }

    scores.sort();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final median = scores.length.isOdd
        ? scores[scores.length ~/ 2]
        : (scores[scores.length ~/ 2 - 1] + scores[scores.length ~/ 2]) / 2;
    final minVal = scores.first;
    final maxVal = scores.last;
    final stdDev = scores.length > 1
        ? sqrt(scores.map((s) => (s - avg) * (s - avg)).reduce((a, b) => a + b) / scores.length)
        : 0.0;

    // Histogram buckets (0-10, 10-20, ..., 90-100)
    final buckets = List.filled(10, 0);
    final maxScore = maxVal > 0 ? maxVal : 100;
    for (final s in scores) {
      int idx = maxScore > 0 ? ((s / maxScore) * 9.99).floor().clamp(0, 9) : 0;
      buckets[idx]++;
    }
    final maxBucket = buckets.reduce((a, b) => a > b ? a : b);

    // Top 5 / Bottom 5
    final sorted = scorePerSiswa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    final bottom5 = sorted.reversed.take(5).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Summary stats
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              _scoreStat("Rata-rata", avg.toStringAsFixed(1), Colors.blue),
              const SizedBox(width: 8),
              _scoreStat("Median", median.toStringAsFixed(1), Colors.teal),
              const SizedBox(width: 8),
              _scoreStat("Std Dev", stdDev.toStringAsFixed(1), Colors.purple),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _scoreStat("Min", minVal.toStringAsFixed(0), Colors.red),
              const SizedBox(width: 8),
              _scoreStat("Max", maxVal.toStringAsFixed(0), Colors.green),
              const SizedBox(width: 8),
              _scoreStat("Peserta", "${scores.length}", Colors.blueGrey),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 14),

      // Histogram
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Histogram Nilai",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(10, (i) {
                  final h = maxBucket > 0 ? (buckets[i] / maxBucket * 100) : 0.0;
                  final pctLabel = "${i * 10}-${(i + 1) * 10}";
                  return Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (buckets[i] > 0) Text("${buckets[i]}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      Container(
                        height: h.clamp(4.0, 100.0),
                        decoration: BoxDecoration(
                          color: i < 3 ? Colors.red.shade300 : i < 7 ? Colors.blue.shade400 : Colors.green.shade400,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(pctLabel, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                    ]),
                  ));
                }),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),

      // Top 5 performers
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              const Text("Top 5 Nilai Tertinggi",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            ...top5.asMap().entries.map((e) {
              final idx = e.key;
              final entry = e.value;
              final siswa = peserta.where((s) => s.id == entry.key).firstOrNull;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: idx == 0 ? Colors.amber : idx == 1 ? Colors.grey.shade400 : Colors.brown.shade300,
                    child: Text("${idx + 1}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(siswa?.nama ?? entry.key, style: const TextStyle(fontSize: 12))),
                  Text(entry.value.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                ]),
              );
            }),
          ]),
        ),
      ),
      const SizedBox(height: 10),

      // Bottom 5 performers
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.trending_down, color: Colors.red.shade400, size: 18),
              const SizedBox(width: 6),
              const Text("5 Nilai Terendah",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            ...bottom5.asMap().entries.map((e) {
              final entry = e.value;
              final siswa = peserta.where((s) => s.id == entry.key).firstOrNull;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const SizedBox(width: 8),
                  Expanded(child: Text(siswa?.nama ?? entry.key, style: const TextStyle(fontSize: 12))),
                  Text(entry.value.toStringAsFixed(0),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade400)),
                ]),
              );
            }),
          ]),
        ),
      ),

      // KKM Summary
      if (exam.kkm > 0) ...[
        const SizedBox(height: 14),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.verified, color: Colors.teal, size: 18),
                const SizedBox(width: 6),
                Text("KKM: ${exam.kkm}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              Builder(builder: (_) {
                final tuntas = scorePerSiswa.values.where((v) => v >= exam.kkm).length;
                final tidakTuntas = scorePerSiswa.values.where((v) => v < exam.kkm).length;
                final pctTuntas = scorePerSiswa.isNotEmpty ? (tuntas / scorePerSiswa.length * 100) : 0.0;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _scoreStat("Tuntas", "$tuntas", Colors.green),
                    const SizedBox(width: 8),
                    _scoreStat("Tidak Tuntas", "$tidakTuntas", Colors.red),
                    const SizedBox(width: 8),
                    _scoreStat("% Tuntas", "${pctTuntas.toStringAsFixed(1)}%", Colors.teal),
                  ]),
                  const SizedBox(height: 10),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: scorePerSiswa.isNotEmpty ? tuntas / scorePerSiswa.length : 0,
                      minHeight: 10,
                      backgroundColor: Colors.red.shade100,
                      valueColor: AlwaysStoppedAnimation(Colors.green.shade400),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tuntas == scorePerSiswa.length
                        ? "Semua siswa tuntas!"
                        : "$tidakTuntas siswa perlu remedial",
                    style: TextStyle(
                      fontSize: 11,
                      color: tuntas == scorePerSiswa.length ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (tidakTuntas > 0) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event_repeat, size: 16),
                        label: const Text("Buat Ujian Remedial", style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange,
                          side: const BorderSide(color: Colors.deepOrange),
                        ),
                        onPressed: () => _createRemedialExam(peserta, scorePerSiswa),
                      ),
                    ),
                  ],
                ]);
              }),
            ]),
          ),
        ),
      ],
    ]);
  }

  Widget _scoreStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _legendItem(Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text("$label: $count", style: const TextStyle(fontSize: 12)),
      ]),
    );
  }

  // ── Load Scores from activity_log ──
  Future<void> _loadScores() async {
    if (_loadingScores || _scoreData != null) return;
    setState(() => _loadingScores = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('exam').doc(exam.id).collection('activity_log').get();
      final Map<String, Map<String, dynamic>> data = {};
      for (final doc in snap.docs) {
        data[doc.id] = doc.data();
      }
      if (mounted) setState(() { _scoreData = data; _loadingScores = false; });
    } catch (e) {
      debugPrint('loadScores error: $e');
      if (mounted) setState(() => _loadingScores = false);
    }
  }

  // ── Load Analisis Butir Soal ──
  Future<void> _loadItemAnalysis() async {
    if (_loadingAnalysis) return;
    setState(() => _loadingAnalysis = true);
    try {
      // Load soal
      final soalSnap = await FirebaseFirestore.instance
          .collection('exam').doc(exam.id).collection('soal')
          .orderBy('nomor').get();
      final soals = soalSnap.docs.map((d) => SoalModel.fromMap(d.data(), d.id)).toList();

      // Load jawaban
      final jwbSnap = await FirebaseFirestore.instance
          .collection('exam').doc(exam.id).collection('jawaban').get();

      // Group jawaban by soalId
      final Map<String, List<Map<String, dynamic>>> jawabanPerSoal = {};
      final Map<String, int> nilaiPerSiswa = {};
      for (final doc in jwbSnap.docs) {
        final d = doc.data();
        final soalId = d['soalId']?.toString() ?? '';
        final siswaId = d['siswaId']?.toString() ?? '';
        jawabanPerSoal.putIfAbsent(soalId, () => []).add(d);
        nilaiPerSiswa[siswaId] = (nilaiPerSiswa[siswaId] ?? 0) + ((d['nilaiDapat'] as int?) ?? 0);
      }

      // Sort siswa by total score for upper/lower group
      final sortedSiswa = nilaiPerSiswa.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final n = sortedSiswa.length;
      final groupSize = (n * 0.27).ceil().clamp(1, n);
      final upperGroup = sortedSiswa.take(groupSize).map((e) => e.key).toSet();
      final lowerGroup = sortedSiswa.skip(n - groupSize).take(groupSize).map((e) => e.key).toSet();

      // Calculate per-item stats
      int totalMax = 0;
      double sumNilai = 0;
      final List<Map<String, dynamic>> analysis = [];
      for (final soal in soals) {
        final jwbList = jawabanPerSoal[soal.id] ?? [];
        final totalJawab = jwbList.length;
        final benarCount = jwbList.where((j) => j['benar'] == true).length;
        totalMax += soal.skor;

        // Difficulty index (P) = benar / total
        final difficulty = totalJawab > 0 ? benarCount / totalJawab : 0.0;

        // Discrimination index (D) = (upper correct - lower correct) / group size
        final upperCorrect = jwbList.where((j) =>
            upperGroup.contains(j['siswaId']?.toString()) && j['benar'] == true).length;
        final lowerCorrect = jwbList.where((j) =>
            lowerGroup.contains(j['siswaId']?.toString()) && j['benar'] == true).length;
        final discrimination = groupSize > 0
            ? (upperCorrect - lowerCorrect) / groupSize : 0.0;

        // Distractor analysis (PG only)
        Map<String, int> optionCounts = {};
        if (soal.tipe == TipeSoal.pilihanGanda) {
          for (final j in jwbList) {
            final ans = j['jawaban']?.toString().toUpperCase() ?? '';
            if (ans.isNotEmpty) optionCounts[ans] = (optionCounts[ans] ?? 0) + 1;
          }
        }

        // Quality classification
        String diffLabel;
        Color diffColor;
        if (difficulty < 0.3) {
          diffLabel = 'Sulit'; diffColor = Colors.red;
        } else if (difficulty < 0.7) {
          diffLabel = 'Sedang'; diffColor = Colors.green;
        } else {
          diffLabel = 'Mudah'; diffColor = Colors.orange;
        }

        String discLabel;
        Color discColor;
        if (discrimination >= 0.4) {
          discLabel = 'Sangat Baik'; discColor = Colors.green;
        } else if (discrimination >= 0.3) {
          discLabel = 'Baik'; discColor = Colors.blue;
        } else if (discrimination >= 0.2) {
          discLabel = 'Cukup'; discColor = Colors.orange;
        } else {
          discLabel = 'Buruk'; discColor = Colors.red;
        }

        analysis.add({
          'soal': soal,
          'totalJawab': totalJawab,
          'benarCount': benarCount,
          'difficulty': difficulty,
          'diffLabel': diffLabel,
          'diffColor': diffColor,
          'discrimination': discrimination,
          'discLabel': discLabel,
          'discColor': discColor,
          'optionCounts': optionCounts,
        });
      }

      // Average score
      if (nilaiPerSiswa.isNotEmpty) {
        sumNilai = nilaiPerSiswa.values.fold(0, (a, b) => a + b).toDouble();
      }

      if (mounted) {
        setState(() {
          _itemAnalysis = analysis;
          _loadingAnalysis = false;
          _totalMaxSkor = totalMax;
          _avgNilai = nilaiPerSiswa.isNotEmpty ? sumNilai / nilaiPerSiswa.length : 0;
        });
      }
    } catch (e) {
      debugPrint('loadItemAnalysis error: $e');
      if (mounted) setState(() => _loadingAnalysis = false);
    }
  }

  // ── Tab Analisis Butir Soal ──
  Widget _buildAnalisisTab() {
    if (_loadingAnalysis) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text("Menganalisis butir soal...", style: TextStyle(color: Colors.grey)),
        ],
      ));
    }
    if (_itemAnalysis == null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          const Text("Analisis butir soal belum dimuat.",
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: _loadItemAnalysis,
            icon: const Icon(Icons.play_arrow),
            label: const Text("Muat Analisis"),
          ),
        ],
      ));
    }

    final items = _itemAnalysis!;
    final goodCount = items.where((i) => (i['discrimination'] as double) >= 0.3).length;
    final poorCount = items.where((i) => (i['discrimination'] as double) < 0.2).length;
    final easyCount = items.where((i) => (i['difficulty'] as double) >= 0.7).length;
    final hardCount = items.where((i) => (i['difficulty'] as double) < 0.3).length;
    final medCount = items.length - easyCount - hardCount;

    // Recommendations
    int keepCount = 0, reviseCount = 0, discardCount = 0;
    for (final item in items) {
      final rec = _getRecommendation(item['difficulty'] as double, item['discrimination'] as double);
      if (rec == 'pertahankan') keepCount++;
      else if (rec == 'revisi') reviseCount++;
      else discardCount++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary cards
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.analytics, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                const Text("Ringkasan Analisis",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                _analysisSummaryCard("Total Soal", "${items.length}", Colors.blue, Icons.quiz),
                const SizedBox(width: 8),
                _analysisSummaryCard("Rata-rata", _avgNilai != null
                    ? "${_avgNilai!.toStringAsFixed(1)}/${_totalMaxSkor ?? 0}" : "-",
                    Colors.teal, Icons.score),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _analysisSummaryCard("Soal Baik", "$goodCount", Colors.green, Icons.thumb_up),
                const SizedBox(width: 8),
                _analysisSummaryCard("Soal Buruk", "$poorCount", Colors.red, Icons.thumb_down),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _analysisSummaryCard("Pertahankan", "$keepCount", Colors.green, Icons.check_circle),
                const SizedBox(width: 8),
                _analysisSummaryCard("Revisi", "$reviseCount", Colors.orange, Icons.edit_note),
                const SizedBox(width: 8),
                _analysisSummaryCard("Buang", "$discardCount", Colors.red, Icons.delete_outline),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // Difficulty distribution
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Distribusi Tingkat Kesulitan",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 24,
                  child: Row(children: [
                    if (hardCount > 0) Expanded(flex: hardCount, child: Container(
                      color: Colors.red,
                      alignment: Alignment.center,
                      child: Text("$hardCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )),
                    if (medCount > 0) Expanded(flex: medCount, child: Container(
                      color: Colors.green,
                      alignment: Alignment.center,
                      child: Text("$medCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )),
                    if (easyCount > 0) Expanded(flex: easyCount, child: Container(
                      color: Colors.orange,
                      alignment: Alignment.center,
                      child: Text("$easyCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _legendItem(Colors.red, "Sulit", hardCount),
                const SizedBox(width: 12),
                _legendItem(Colors.green, "Sedang", medCount),
                const SizedBox(width: 12),
                _legendItem(Colors.orange, "Mudah", easyCount),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // Per-item detail list
        const Text("Detail Per Soal",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...items.map((item) {
          final soal = item['soal'] as SoalModel;
          final difficulty = item['difficulty'] as double;
          final discrimination = item['discrimination'] as double;
          final diffLabel = item['diffLabel'] as String;
          final diffColor = item['diffColor'] as Color;
          final discLabel = item['discLabel'] as String;
          final discColor = item['discColor'] as Color;
          final benar = item['benarCount'] as int;
          final total = item['totalJawab'] as int;
          final optCounts = item['optionCounts'] as Map<String, int>;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF0F172A),
                    child: Text("${soal.nomor}",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    soal.pertanyaan.length > 80
                        ? "${soal.pertanyaan.substring(0, 80)}..." : soal.pertanyaan,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(diffLabel,
                        style: TextStyle(fontSize: 10, color: diffColor, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 10),

                // Stats row
                Row(children: [
                  _itemStatChip("P = ${difficulty.toStringAsFixed(2)}", diffColor),
                  const SizedBox(width: 6),
                  _itemStatChip("D = ${discrimination.toStringAsFixed(2)}", discColor),
                  const SizedBox(width: 6),
                  _itemStatChip("$benar/$total benar", Colors.blueGrey),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: discColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(discLabel,
                        style: TextStyle(fontSize: 10, color: discColor, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 6),
                // Recommendation badge
                Row(children: [
                  _buildRecommendationBadge(difficulty, discrimination),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _saveSoalToBank(soal),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.save_alt, size: 12, color: Colors.teal),
                        SizedBox(width: 4),
                        Text("Simpan ke Bank", style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),

                // Distractor analysis for PG
                if (soal.tipe == TipeSoal.pilihanGanda && optCounts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Text("Distribusi Jawaban:",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: soal.pilihan.map((p) {
                    final key = p.split('.').first.trim().toUpperCase();
                    final count = optCounts[key] ?? 0;
                    final pct = total > 0 ? (count / total * 100) : 0;
                    final isCorrect = key == soal.kunciJawaban.toUpperCase();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCorrect ? Colors.green : Colors.grey.shade300,
                          width: isCorrect ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        "$key: $count (${pct.toStringAsFixed(0)}%)",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                          color: isCorrect ? Colors.green.shade800 : Colors.grey.shade700,
                        ),
                      ),
                    );
                  }).toList()),
                ],
              ]),
            ),
          );
        }),

        // Export analisis button
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _exportAnalisisCSV,
            icon: const Icon(Icons.download),
            label: const Text("Export CSV"),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _saveAllGoodToBank(items),
            icon: const Icon(Icons.save_alt, color: Colors.teal),
            label: const Text("Simpan Soal Baik ke Bank"),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
          )),
        ]),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _analysisSummaryCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }

  Widget _itemStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ── Recommendation logic ──
  String _getRecommendation(double difficulty, double discrimination) {
    if (discrimination >= 0.3 && difficulty >= 0.2 && difficulty <= 0.8) return 'pertahankan';
    if (discrimination < 0.1 || difficulty < 0.1 || difficulty > 0.95) return 'buang';
    return 'revisi';
  }

  Widget _buildRecommendationBadge(double difficulty, double discrimination) {
    final rec = _getRecommendation(difficulty, discrimination);
    Color c;
    IconData icon;
    String label;
    switch (rec) {
      case 'pertahankan':
        c = Colors.green; icon = Icons.check_circle; label = 'PERTAHANKAN';
        break;
      case 'buang':
        c = Colors.red; icon = Icons.delete_outline; label = 'BUANG';
        break;
      default:
        c = Colors.orange; icon = Icons.edit_note; label = 'REVISI';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Future<void> _saveSoalToBank(SoalModel soal) async {
    String topik = '';
    String tingkat = 'sedang';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.save_alt, color: Colors.teal),
            SizedBox(width: 8),
            Text("Simpan ke Bank Soal", style: TextStyle(fontSize: 16)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Soal No. ${soal.nomor}: ${soal.pertanyaan.length > 60 ? '${soal.pertanyaan.substring(0, 60)}...' : soal.pertanyaan}",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: "Topik / Bab", isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => topik = v,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: tingkat,
              decoration: const InputDecoration(labelText: "Tingkat Kesulitan", isDense: true, border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'mudah', child: Text("Mudah")),
                DropdownMenuItem(value: 'sedang', child: Text("Sedang")),
                DropdownMenuItem(value: 'sulit', child: Text("Sulit")),
              ],
              onChanged: (v) => setSt(() => tingkat = v ?? 'sedang'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance.collection('bank_soal').add({
      'mapel': exam.mapel,
      'topik': topik.trim().isNotEmpty ? topik.trim() : exam.judul,
      'tingkatKesulitan': tingkat,
      'tipe': soal.tipe.name,
      'pertanyaan': soal.pertanyaan,
      'gambar': soal.gambar,
      'pilihan': soal.pilihan,
      'kunciJawaban': soal.kunciJawaban,
      'skor': soal.skor,
      'createdAt': FieldValue.serverTimestamp(),
      'sourceExamId': exam.id,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Soal berhasil disimpan ke Bank Soal!"), backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _saveAllGoodToBank(List<Map<String, dynamic>> items) async {
    final goodItems = items.where((i) {
      final d = i['difficulty'] as double;
      final disc = i['discrimination'] as double;
      return _getRecommendation(d, disc) == 'pertahankan';
    }).toList();

    if (goodItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Tidak ada soal dengan rekomendasi 'Pertahankan'."), backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    String topik = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.save_alt, color: Colors.teal),
          SizedBox(width: 8),
          Text("Simpan Soal Baik ke Bank", style: TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("${goodItems.length} soal dengan rekomendasi 'Pertahankan' akan disimpan ke Bank Soal.",
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(labelText: "Topik / Bab", isDense: true, border: OutlineInputBorder()),
            onChanged: (v) => topik = v,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Simpan ${goodItems.length} Soal"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final item in goodItems) {
      final soal = item['soal'] as SoalModel;
      final difficulty = item['difficulty'] as double;
      String tingkat = 'sedang';
      if (difficulty >= 0.7) tingkat = 'mudah';
      else if (difficulty < 0.3) tingkat = 'sulit';

      batch.set(FirebaseFirestore.instance.collection('bank_soal').doc(), {
        'mapel': exam.mapel,
        'topik': topik.trim().isNotEmpty ? topik.trim() : exam.judul,
        'tingkatKesulitan': tingkat,
        'tipe': soal.tipe.name,
        'pertanyaan': soal.pertanyaan,
        'gambar': soal.gambar,
        'pilihan': soal.pilihan,
        'kunciJawaban': soal.kunciJawaban,
        'skor': soal.skor,
        'createdAt': FieldValue.serverTimestamp(),
        'sourceExamId': exam.id,
      });
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${goodItems.length} soal berhasil disimpan ke Bank Soal!"),
        backgroundColor: Colors.green,
      ));
    }
  }

  // ── Export Analisis CSV ──
  void _exportAnalisisCSV() {
    if (_itemAnalysis == null) return;
    final buf = StringBuffer();
    buf.writeln("No,Pertanyaan,Tipe,Kunci,Skor,Tingkat Kesulitan (P),Klasifikasi,Daya Pembeda (D),Klasifikasi D,Benar,Total,Distribusi Jawaban");
    for (final item in _itemAnalysis!) {
      final soal = item['soal'] as SoalModel;
      final d = item['difficulty'] as double;
      final disc = item['discrimination'] as double;
      final benar = item['benarCount'] as int;
      final total = item['totalJawab'] as int;
      final optCounts = item['optionCounts'] as Map<String, int>;
      final distrib = optCounts.entries.map((e) => "${e.key}:${e.value}").join("|");
      final pertanyaan = soal.pertanyaan.replaceAll('"', '""').replaceAll('\n', ' ');
      buf.writeln('"${soal.nomor}","$pertanyaan","${soal.tipe.name}","${soal.kunciJawaban}","${soal.skor}","${d.toStringAsFixed(3)}","${item['diffLabel']}","${disc.toStringAsFixed(3)}","${item['discLabel']}","$benar","$total","$distrib"');
    }
    buf.writeln('');
    buf.writeln('"RINGKASAN ANALISIS"');
    buf.writeln('"Rata-rata Nilai","${_avgNilai?.toStringAsFixed(1) ?? "-"} / ${_totalMaxSkor ?? 0}"');
    buf.writeln('"Total Soal","${_itemAnalysis!.length}"');
    buf.writeln('"Soal Baik (D>=0.3)","${_itemAnalysis!.where((i) => (i['discrimination'] as double) >= 0.3).length}"');
    buf.writeln('"Soal Buruk (D<0.2)","${_itemAnalysis!.where((i) => (i['discrimination'] as double) < 0.2).length}"');
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Data analisis butir soal disalin ke clipboard!"),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 4),
    ));
  }

  // ── Export PDF Rapor Ujian ──
  Future<void> _exportPDF(List<UserAccount> peserta) async {
    print("DEBUG: Starting PDF export...");
    
    // Ensure scores loaded
    if (_scoreData == null) {
      print("DEBUG: Loading scores...");
      await _loadScores();
      print("DEBUG: Scores loaded: ${_scoreData?.keys.length ?? 0} entries");
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Menyiapkan PDF..."),
      backgroundColor: Colors.blue,
      duration: Duration(seconds: 2),
    ));

    print("DEBUG: Creating PDF document...");
    final pdf = pw.Document();
    final dateStr = DateFormat('dd MMMM yyyy, HH:mm', 'id').format(DateTime.now());

    print("DEBUG: Collecting score data...");
    // Collect score list for summary
    final List<_PdfSiswaRow> rows = [];
    for (final s in peserta) {
      final status = _statusForExam(s);
      final sd = _scoreData?[s.id];
      final nilai = sd != null ? ((sd['totalNilai'] as num?)?.toDouble() ?? 0) : 0.0;
      final benar = sd != null ? ((sd['totalBenar'] as num?)?.toInt() ?? 0) : 0;
      final totalSoal = sd != null ? ((sd['totalSoal'] as num?)?.toInt() ?? 0) : 0;
      final vCount = s.violationForExam(exam.id);
      rows.add(_PdfSiswaRow(
        nama: s.nama, kode: s.kode, kelas: s.classFolder, ruang: s.ruang,
        status: status, nilai: nilai, benar: benar, totalSoal: totalSoal, violations: vCount,
      ));
    }
    rows.sort((a, b) => b.nilai.compareTo(a.nilai));
    print("DEBUG: Processed ${rows.length} students");

    final selesai = rows.where((r) => r.status == 'selesai').length;
    final scores = rows.where((r) => r.nilai > 0).map((r) => r.nilai).toList()..sort();
    final avg = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0;
    final maxScore = scores.isNotEmpty ? scores.last : 0.0;
    final minScore = scores.isNotEmpty ? scores.first : 0.0;

    print("DEBUG: Building PDF pages...");
    try {
      // Page 1: Summary
      print("DEBUG: Creating summary page...");
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('LAPORAN HASIL UJIAN', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ]),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 8),
        ]),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Asesment SMP BMS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        pw.Text('Hal ${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
      ]),
      build: (ctx) => [
        // Exam info
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(exam.judul, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Row(children: [
              pw.Text('Mapel: ${exam.mapel}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 20),
              pw.Text('Jenjang: ${exam.jenjang}', style: const pw.TextStyle(fontSize: 10)),
            ]),
            pw.Row(children: [
              pw.Text('Waktu: ${DateFormat('dd/MM/yyyy HH:mm').format(exam.waktuMulai)} - ${DateFormat('HH:mm').format(exam.waktuSelesai)}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 20),
              pw.Text('Durasi: ${exam.waktuSelesai.difference(exam.waktuMulai).inMinutes} menit', style: const pw.TextStyle(fontSize: 10)),
            ]),
            if (exam.kkm > 0 || exam.spiType != 'reguler')
              pw.Row(children: [
                if (exam.kkm > 0) pw.Text('KKM: ${exam.kkm}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                if (exam.kkm > 0 && exam.spiType != 'reguler') pw.SizedBox(width: 20),
                if (exam.spiType != 'reguler') pw.Text('Tipe: ${exam.spiType[0].toUpperCase()}${exam.spiType.substring(1)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: exam.spiType == 'remedial' ? PdfColors.deepOrange : PdfColors.indigo)),
              ]),
          ]),
        ),
        pw.SizedBox(height: 16),

        // Stats summary
        pw.Row(children: [
          _pdfStatBox('Total Peserta', '${peserta.length}', PdfColors.blue),
          pw.SizedBox(width: 8),
          _pdfStatBox('Selesai', '$selesai', PdfColors.green),
          pw.SizedBox(width: 8),
          _pdfStatBox('Rata-rata', avg.toStringAsFixed(1), PdfColors.teal),
          pw.SizedBox(width: 8),
          _pdfStatBox('Tertinggi', maxScore.toStringAsFixed(0), PdfColors.green800),
          pw.SizedBox(width: 8),
          _pdfStatBox('Terendah', minScore.toStringAsFixed(0), PdfColors.red),
        ]),
        pw.SizedBox(height: 16),

        // Table
        pw.Text('Daftar Nilai Peserta', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          headerAlignments: {
            0: pw.Alignment.center, 1: pw.Alignment.centerLeft,
            2: pw.Alignment.center, 3: pw.Alignment.center,
            4: pw.Alignment.center, 5: pw.Alignment.center,
            6: pw.Alignment.center, 7: pw.Alignment.center,
            if (exam.kkm > 0) 8: pw.Alignment.center,
          },
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FixedColumnWidth(50),
            3: const pw.FixedColumnWidth(35),
            4: const pw.FixedColumnWidth(35),
            5: const pw.FixedColumnWidth(50),
            6: const pw.FixedColumnWidth(55),
            7: const pw.FixedColumnWidth(50),
            if (exam.kkm > 0) 8: const pw.FixedColumnWidth(45),
          },
          headers: ['No', 'Nama', 'Kode', 'Kelas', 'Ruang', 'Nilai', 'Benar/Total', 'Status', if (exam.kkm > 0) 'KKM'],
          data: rows.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            return [
              '${i + 1}',
              r.nama,
              r.kode,
              r.kelas,
              r.ruang,
              r.nilai.toStringAsFixed(0),
              '${r.benar}/${r.totalSoal}',
              r.status == 'selesai' ? 'Selesai' : r.status == 'melanggar' ? 'Melanggar' : r.status == 'mengerjakan' ? 'Ujian' : 'Belum',
              if (exam.kkm > 0) r.nilai >= exam.kkm ? 'Tuntas' : 'BT',
            ];
          }).toList(),
        ),
      ],
    ));
    } catch (e) {
      print("DEBUG: Error creating PDF page: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error creating PDF: $e"),
          backgroundColor: Colors.red,
        ));
      }
    }

    try {
      print("DEBUG: Saving PDF document...");
      final bytes = await pdf.save();
      print("DEBUG: PDF saved successfully, size: ${bytes.length} bytes");
      
      if (kIsWeb) {
        // Web platform - trigger download
        final fileName = 'Rapor_${exam.judul.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
        _downloadBytesForWeb(bytes, fileName, 'application/pdf');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("File PDF berhasil diunduh!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ));
        }
      } else {
        // Desktop/Mobile platform - use file picker
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save PDF File',
          fileName: 'Rapor_${exam.judul.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          print("DEBUG: PDF file saved to: $outputFile");
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("File PDF berhasil disimpan!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ));
          }
        } else {
          // If user cancels save dialog, show print preview instead
          await Printing.layoutPdf(
            onLayout: (format) => bytes,
            name: 'Rapor_${exam.judul.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
          );
          print("DEBUG: PDF layout opened successfully");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error exporting PDF: $e"),
          backgroundColor: Colors.red,
        ));
      }
      print("DEBUG: PDF export error: $e");
    }
  }

  pw.Widget _pdfStatBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        ]),
      ),
    );
  }

  // ── Laporan Proktor (rekap pelanggaran) ──
  Future<void> _exportProktorReport(List<UserAccount> peserta) async {
    final pelanggar = <Map<String, dynamic>>[];
    for (final s in peserta) {
      final vCount = s.violationForExam(exam.id);
      if (vCount <= 0) continue;
      final rawExam = s.examStatus[exam.id];
      final lastReason = (rawExam is Map && rawExam['lastViolationReason'] != null)
          ? rawExam['lastViolationReason'].toString() : '';
      final proktorCount = (rawExam is Map && rawExam['proktorUnlockCount'] is int)
          ? rawExam['proktorUnlockCount'] as int : 0;
      pelanggar.add({
        'siswa': s,
        'violations': vCount,
        'lastReason': lastReason,
        'proktorUnlock': proktorCount,
      });
    }
    pelanggar.sort((a, b) => (b['violations'] as int).compareTo(a['violations'] as int));

    if (pelanggar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Tidak ada pelanggaran ditemukan."),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final pdf = pw.Document();
    final dateStr = DateFormat('dd MMMM yyyy, HH:mm', 'id').format(DateTime.now());

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (ctx) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('LAPORAN PROKTOR - REKAP PELANGGARAN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ]),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 8),
      ]),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Asesment SMP BMS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        pw.Text('Hal ${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
      ]),
      build: (ctx) => [
        // Exam info
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: PdfColors.red50, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Ujian: ${exam.judul}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text('Mapel: ${exam.mapel} | Jenjang: ${exam.jenjang}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Total Pelanggar: ${pelanggar.length} dari ${peserta.length} peserta', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.SizedBox(height: 14),

        pw.Text('Daftar Pelanggaran', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FixedColumnWidth(45),
            3: const pw.FixedColumnWidth(35),
            4: const pw.FixedColumnWidth(35),
            5: const pw.FixedColumnWidth(55),
            6: const pw.FlexColumnWidth(2.5),
          },
          headers: ['No', 'Nama', 'Kode', 'Kelas', 'Langgar', 'Proktor PIN', 'Alasan Terakhir'],
          data: pelanggar.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            final s = p['siswa'] as UserAccount;
            return [
              '${i + 1}',
              s.nama,
              s.kode,
              s.classFolder,
              '${p['violations']}',
              '${p['proktorUnlock']}x',
              (p['lastReason'] as String).isEmpty ? '-' : p['lastReason'] as String,
            ];
          }).toList(),
        ),
      ],
    ));

    try {
      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name: 'Proktor_${exam.judul.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error exporting proktor PDF: $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Fitur Darurat: Pause / Resume Ujian ──
  Future<void> _togglePauseExam() async {
    final willPause = !exam.isPaused;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(willPause ? Icons.pause_circle : Icons.play_arrow, color: willPause ? Colors.red : Colors.green),
          const SizedBox(width: 8),
          Text(willPause ? "Pause Ujian?" : "Resume Ujian?"),
        ]),
        content: Text(willPause
            ? "Semua siswa akan dihentikan sementara dari ujian ini.\nGunakan fitur ini hanya untuk keadaan darurat (listrik mati, masalah teknis, dll)."
            : "Siswa akan dapat melanjutkan ujian dari soal terakhir yang dikerjakan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willPause ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willPause ? "Pause Sekarang" : "Resume Sekarang"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('exam').doc(exam.id).update({
      'isPaused': willPause,
      if (willPause) 'pausedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(willPause ? "Ujian dijeda! Semua siswa akan dihentikan." : "Ujian dilanjutkan!"),
        backgroundColor: willPause ? Colors.red : Colors.green,
      ));
    }
  }

  // ── Fitur Darurat: Extend Waktu Per Siswa ──
  Future<void> _extendWaktuPerSiswa(List<UserAccount> peserta) async {
    final mengerjakan = peserta.where((s) => _statusForExam(s) == 'mengerjakan' || _statusForExam(s) == 'melanggar').toList();
    if (mengerjakan.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Tidak ada siswa yang sedang mengerjakan."), backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    final selected = <UserAccount>{};
    int menitTambah = 15;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.person_add_alt_1, color: Colors.teal),
            SizedBox(width: 8),
            Text("Tambah Waktu Per Siswa", style: TextStyle(fontSize: 16)),
          ]),
          content: SizedBox(
            width: 400,
            height: 400,
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 28),
                  onPressed: menitTambah > 5 ? () => setSt(() => menitTambah -= 5) : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text("$menitTambah menit", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                  onPressed: () => setSt(() => menitTambah += 5),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text("${selected.length} siswa dipilih", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => setSt(() {
                    if (selected.length == mengerjakan.length) {
                      selected.clear();
                    } else {
                      selected.addAll(mengerjakan);
                    }
                  }),
                  child: Text(selected.length == mengerjakan.length ? "Batal Pilih" : "Pilih Semua", style: const TextStyle(fontSize: 12)),
                ),
              ]),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: mengerjakan.length,
                  itemBuilder: (c, i) {
                    final s = mengerjakan[i];
                    return CheckboxListTile(
                      dense: true,
                      value: selected.contains(s),
                      onChanged: (v) => setSt(() => v! ? selected.add(s) : selected.remove(s)),
                      title: Text(s.nama, style: const TextStyle(fontSize: 13)),
                      subtitle: Text("${s.kode} • ${s.classFolder}", style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text("Tambahkan"),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selected.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final s in selected) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(s.id),
        {
          'exam_status.${exam.id}.extraMinutes': FieldValue.increment(menitTambah),
          'exam_status.${exam.id}.extendedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$menitTambah menit ditambahkan untuk ${selected.length} siswa!"),
        backgroundColor: Colors.teal,
      ));
    }
  }

  // ── Fitur Darurat: Reset Siswa & Lanjutkan dari Soal Terakhir ──
  Future<void> _resetResumeSiswa(List<UserAccount> peserta) async {
    final crashedOrViolated = peserta.where((s) {
      final st = _statusForExam(s);
      return st == 'melanggar' || st == 'mengerjakan';
    }).toList();

    if (crashedOrViolated.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Tidak ada siswa yang perlu direset."), backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    final selected = <UserAccount>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.replay, color: Colors.purple),
            SizedBox(width: 8),
            Text("Reset & Lanjutkan", style: TextStyle(fontSize: 16)),
          ]),
          content: SizedBox(
            width: 400,
            height: 400,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  "Siswa yang dipilih akan direset ke status 'belum mulai' tetapi jawaban yang sudah disimpan akan dipertahankan. "
                  "Saat masuk kembali, siswa akan melanjutkan dari soal terakhir.",
                  style: TextStyle(fontSize: 12, color: Colors.purple),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text("${selected.length} dipilih", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => setSt(() {
                    if (selected.length == crashedOrViolated.length) selected.clear();
                    else selected.addAll(crashedOrViolated);
                  }),
                  child: Text(selected.length == crashedOrViolated.length ? "Batal Pilih" : "Pilih Semua", style: const TextStyle(fontSize: 12)),
                ),
              ]),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: crashedOrViolated.length,
                  itemBuilder: (c, i) {
                    final s = crashedOrViolated[i];
                    final st = _statusForExam(s);
                    return CheckboxListTile(
                      dense: true,
                      value: selected.contains(s),
                      onChanged: (v) => setSt(() => v! ? selected.add(s) : selected.remove(s)),
                      title: Text(s.nama, style: const TextStyle(fontSize: 13)),
                      subtitle: Text("${s.kode} • Status: $st", style: const TextStyle(fontSize: 11)),
                      secondary: Icon(
                        st == 'melanggar' ? Icons.warning : Icons.edit,
                        color: st == 'melanggar' ? Colors.red : Colors.indigo,
                        size: 18,
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text("Reset & Lanjutkan"),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selected.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final s in selected) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(s.id),
        {
          'exam_status.${exam.id}.status': 'belum mulai',
          'exam_status.${exam.id}.resumeFromLast': true,
          'exam_status.${exam.id}.violationCount': 0,
          'exam_status.${exam.id}.resetAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${selected.length} siswa direset! Mereka dapat melanjutkan dari soal terakhir."),
        backgroundColor: Colors.purple,
      ));
    }
  }

  // ── Remedial Otomatis dari Bank Soal ──
  Future<void> _createRemedialFromBank(List<UserAccount> peserta) async {
    if (_scoreData == null) await _loadScores();
    final Map<String, double> scores = {};
    for (final s in peserta) {
      final sd = _scoreData?[s.id];
      if (sd != null) scores[s.id] = (sd['totalNilai'] as num?)?.toDouble() ?? 0;
    }

    final tidakTuntas = peserta.where((s) => (scores[s.id] ?? 0) < exam.kkm).toList();
    if (tidakTuntas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Semua siswa sudah tuntas!"), backgroundColor: Colors.green,
        ));
      }
      return;
    }

    // Check if bank soal has questions for this mapel
    final bankSnap = await FirebaseFirestore.instance.collection('bank_soal')
        .where('mapel', isEqualTo: exam.mapel).get();

    if (bankSnap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Tidak ada soal di Bank Soal untuk mapel '${exam.mapel}'. Tambahkan soal terlebih dahulu."),
          backgroundColor: Colors.orange, duration: const Duration(seconds: 4),
        ));
      }
      return;
    }

    int jumlahSoal = 10;
    int propMudah = 40, propSedang = 40, propSulit = 20;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.healing, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text("Remedial dari Bank Soal", style: TextStyle(fontSize: 16)),
          ]),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.deepOrange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  "${tidakTuntas.length} siswa belum tuntas (KKM: ${exam.kkm}).\n"
                  "Soal remedial akan diambil acak dari Bank Soal mapel '${exam.mapel}' "
                  "(${bankSnap.docs.length} soal tersedia).",
                  style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Text("Jumlah Soal: ", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 80, child: TextFormField(
                  initialValue: jumlahSoal.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  onChanged: (v) => jumlahSoal = int.tryParse(v) ?? 10,
                )),
              ]),
              const SizedBox(height: 12),
              const Text("Proporsi Tingkat Kesulitan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _propSlider("Mudah", Colors.green, propMudah, (v) => setSt(() { propMudah = v; propSedang = (100 - propMudah - propSulit).clamp(0, 100); })),
              _propSlider("Sedang", Colors.orange, propSedang, (v) => setSt(() { propSedang = v; propSulit = (100 - propMudah - propSedang).clamp(0, 100); })),
              _propSlider("Sulit", Colors.red, propSulit, (v) => setSt(() { propSulit = v; propSedang = (100 - propMudah - propSulit).clamp(0, 100); })),
              Text("Total: ${propMudah + propSedang + propSulit}%",
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: (propMudah + propSedang + propSulit) == 100 ? Colors.green : Colors.red)),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Buat Remedial"),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      // Pick random questions from bank
      final countMudah = (jumlahSoal * propMudah / 100).round();
      final countSulit = (jumlahSoal * propSulit / 100).round();
      final countSedang = jumlahSoal - countMudah - countSulit;

      List<QueryDocumentSnapshot> pickRandom(String tingkat, int count) {
        final filtered = bankSnap.docs.where((d) => (d.data() as Map)['tingkatKesulitan'] == tingkat).toList()..shuffle(Random());
        return filtered.take(count).toList();
      }

      final soalDocs = [...pickRandom('mudah', countMudah), ...pickRandom('sedang', countSedang), ...pickRandom('sulit', countSulit)]..shuffle(Random());

      if (soalDocs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Tidak cukup soal di bank untuk membuat remedial!"), backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      // Pick date
      if (!mounted) return;
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (pickedDate == null || !mounted) return;
      final pickedStart = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(exam.waktuMulai));
      if (pickedStart == null || !mounted) return;
      final pickedEnd = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(exam.waktuSelesai));
      if (pickedEnd == null || !mounted) return;

      final newStart = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedStart.hour, pickedStart.minute);
      final newEnd = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedEnd.hour, pickedEnd.minute);

      // Create exam
      final newDoc = await FirebaseFirestore.instance.collection('exam').add({
        'judul': '[Remedial] ${exam.judul}',
        'mapel': exam.mapel, 'jenjang': exam.jenjang,
        'antiCurang': exam.antiCurang, 'maxCurang': exam.maxCurang,
        'kameraAktif': exam.kameraAktif, 'autoSubmit': exam.autoSubmit,
        'waktuMulai': Timestamp.fromDate(newStart), 'waktuSelesai': Timestamp.fromDate(newEnd),
        'instruksi': exam.instruksi, 'link': '', 'mode': 'native',
        'jumlahSoal': soalDocs.length,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'draft', 'kategori': exam.kategori,
        'creatorName': exam.creatorName,
        'targetKelas': exam.targetKelas,
        'kkm': exam.kkm, 'spiType': 'remedial', 'parentExamId': exam.id,
      });

      // Upload soal
      final batch = FirebaseFirestore.instance.batch();
      for (int i = 0; i < soalDocs.length; i++) {
        final d = soalDocs[i].data() as Map<String, dynamic>;
        batch.set(
          FirebaseFirestore.instance.collection('exam').doc(newDoc.id).collection('soal').doc(),
          {
            'nomor': i + 1,
            'tipe': d['tipe'] ?? 'pilihanGanda',
            'pertanyaan': d['pertanyaan'] ?? '',
            'gambar': d['gambar'] ?? '',
            'pilihan': d['pilihan'] ?? [],
            'kunciJawaban': d['kunciJawaban'] ?? '',
            'skor': d['skor'] ?? 1,
          },
        );
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Ujian remedial berhasil dibuat dengan ${soalDocs.length} soal dari Bank Soal!"),
          backgroundColor: Colors.green, duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Gagal membuat remedial: $e"), backgroundColor: Colors.red,
        ));
      }
    }
  }

  Widget _propSlider(String label, Color color, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 55, child: Text("$label:", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
        Expanded(child: Slider(value: value.toDouble(), min: 0, max: 100, divisions: 20, activeColor: color, label: "$value%",
            onChanged: (v) => onChanged(v.round()))),
        SizedBox(width: 35, child: Text("$value%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
      ]),
    );
  }

  // ── Buat Ujian Remedial / Susulan ──
  Future<void> _createRemedialExam(List<UserAccount> peserta, Map<String, double> scores) async {
    final exam = widget.exam;
    final tidakTuntas = <UserAccount>[];
    for (final s in peserta) {
      final nilai = scores[s.id] ?? 0;
      if (nilai < exam.kkm) tidakTuntas.add(s);
    }

    if (tidakTuntas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Semua siswa sudah tuntas!"),
          backgroundColor: Colors.green,
        ));
      }
      return;
    }

    // Show confirmation dialog
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Buat Ujian Lanjutan"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("${tidakTuntas.length} siswa belum tuntas (KKM: ${exam.kkm})."),
          const SizedBox(height: 12),
          const Text("Pilih tipe sesi:", style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.event_repeat, size: 16),
              label: const Text("Remedial"),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.deepOrange),
              onPressed: () => Navigator.pop(ctx, 'remedial'),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.schedule, size: 16),
              label: const Text("Susulan"),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
              onPressed: () => Navigator.pop(ctx, 'susulan'),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
        ],
      ),
    );

    if (result == null || !mounted) return;

    // Pick date and time for new exam
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedStart = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(exam.waktuMulai),
    );
    if (pickedStart == null || !mounted) return;

    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(exam.waktuSelesai),
    );
    if (pickedEnd == null || !mounted) return;

    final newStart = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
        pickedStart.hour, pickedStart.minute);
    final newEnd = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
        pickedEnd.hour, pickedEnd.minute);

    if (newEnd.isBefore(newStart)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Waktu selesai harus setelah waktu mulai!"),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    try {
      // Create new exam document
      final newExamData = {
        'judul': '${result == 'remedial' ? '[Remedial]' : '[Susulan]'} ${exam.judul}',
        'mapel': exam.mapel,
        'jenjang': exam.jenjang,
        'antiCurang': exam.antiCurang,
        'maxCurang': exam.maxCurang,
        'kameraAktif': exam.kameraAktif,
        'autoSubmit': exam.autoSubmit,
        'waktuMulai': Timestamp.fromDate(newStart),
        'waktuSelesai': Timestamp.fromDate(newEnd),
        'instruksi': exam.instruksi,
        'link': exam.link,
        'mode': exam.mode,
        'jumlahSoal': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'draft',
        'kategori': exam.kategori,
        'creatorName': exam.creatorName,
        'targetKelas': exam.targetKelas,
        'kkm': exam.kkm,
        'spiType': result,
        'parentExamId': exam.id,
      };

      final newDoc = await FirebaseFirestore.instance.collection('exam').add(newExamData);

      // Copy soal from parent exam
      if (exam.mode == 'native') {
        final soalSnap = await FirebaseFirestore.instance
            .collection('exam').doc(exam.id).collection('soal')
            .orderBy('nomor').get();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in soalSnap.docs) {
          batch.set(
            FirebaseFirestore.instance.collection('exam').doc(newDoc.id).collection('soal').doc(d.id),
            d.data(),
          );
        }
        await batch.commit();
        await FirebaseFirestore.instance.collection('exam').doc(newDoc.id).update({
          'jumlahSoal': soalSnap.docs.length,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Ujian ${result == 'remedial' ? 'remedial' : 'susulan'} berhasil dibuat untuk ${tidakTuntas.length} siswa!"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Gagal membuat ujian: $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          if (exam.spiType == 'remedial') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(6)),
              child: const Text("R", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ] else if (exam.spiType == 'susulan') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(6)),
              child: const Text("S", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
          Flexible(child: Text(exam.judul, overflow: TextOverflow.ellipsis)),
        ]),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          if (exam.link.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: "Buka Soal",
              onPressed: () async {
                final uri = Uri.tryParse(exam.link.trim());
                if (uri != null && uri.hasScheme) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'siswa')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final all = snap.data!.docs.map((d) => UserAccount.fromFirestore(d)).toList();
          final peserta = all.where((s) => s.matchJenjang(exam.jenjang)).toList();
          final selesai = peserta.where((s) => _statusForExam(s) == 'selesai').toList();
          final melanggar = peserta.where((s) => _statusForExam(s) == 'melanggar').toList();
          final mengerjakan = peserta.where((s) => _statusForExam(s) == 'mengerjakan').toList();
          final belum = peserta.where((s) => _statusForExam(s) == 'belum mulai').toList();

          var filtered = peserta.where((s) {
            final matchSearch = _search.isEmpty ||
                s.nama.toLowerCase().contains(_search.toLowerCase()) ||
                s.kode.toLowerCase().contains(_search.toLowerCase());
            final matchStatus = _filterStatus == 'semua' ||
                (_filterStatus == 'belum' && _statusForExam(s) == 'belum mulai') ||
                _statusForExam(s) == _filterStatus;
            return matchSearch && matchStatus;
          }).toList();

          final Map<String, List<UserAccount>> grouped = {};
          for (var s in filtered) {
            grouped.putIfAbsent(s.classFolder, () => []).add(s);
          }
          final sortedKeys = grouped.keys.toList()..sort();

          return Column(children: [
            // Action bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                // Stat summary chips
                _miniChip("${peserta.length} total", Colors.blueGrey),
                const SizedBox(width: 4),
                _miniChip("${selesai.length} selesai", Colors.green),
                const SizedBox(width: 4),
                _miniChip("${mengerjakan.length} ujian", Colors.indigo),
                if (melanggar.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  _miniChip("${melanggar.length} langgar", Colors.red),
                ],
                const Spacer(),
                // Live Monitoring button
                IconButton(
                  icon: Icon(Icons.monitor_heart,
                      color: exam.isOngoing ? Colors.green : Colors.blueGrey),
                  tooltip: "Live Monitoring",
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => LiveMonitoringScreen(exam: exam),
                  )),
                ),
                // Edit Soal button
                IconButton(
                  icon: const Icon(Icons.quiz_outlined, color: Colors.deepPurple),
                  tooltip: "Edit Soal",
                  onPressed: () => _showEditSoalSheet(),
                ),
                // Export button
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.teal),
                  tooltip: "Export CSV",
                  onPressed: () => _showExportDialog(peserta),
                ),
                // Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) {
                    if (v == 'extend') _extendWaktu();
                    if (v == 'extend_student') _extendWaktuPerSiswa(peserta);
                    if (v == 'pause') _togglePauseExam();
                    if (v == 'reset') _resetSemua(peserta);
                    if (v == 'reset_resume') _resetResumeSiswa(peserta);
                    if (v == 'pdf_rapor') _exportPDF(peserta);
                    if (v == 'pdf_proktor') _exportProktorReport(peserta);
                    if (v == 'remedial_bank') _createRemedialFromBank(peserta);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'pdf_rapor', child: Row(children: [
                      Icon(Icons.picture_as_pdf, color: Colors.red), SizedBox(width: 8), Text("Export PDF Rapor"),
                    ])),
                    const PopupMenuItem(value: 'pdf_proktor', child: Row(children: [
                      Icon(Icons.security, color: Colors.orange), SizedBox(width: 8), Text("Laporan Proktor"),
                    ])),
                    const PopupMenuDivider(),
                    // ── Fitur Darurat ──
                    PopupMenuItem(value: 'pause', child: Row(children: [
                      Icon(exam.isPaused ? Icons.play_arrow : Icons.pause_circle,
                          color: exam.isPaused ? Colors.green : Colors.red),
                      const SizedBox(width: 8),
                      Text(exam.isPaused ? "Resume Ujian" : "Pause Ujian (Darurat)"),
                    ])),
                    const PopupMenuItem(value: 'extend', child: Row(children: [
                      Icon(Icons.timer, color: Colors.blue), SizedBox(width: 8), Text("Tambah Waktu (Semua)"),
                    ])),
                    const PopupMenuItem(value: 'extend_student', child: Row(children: [
                      Icon(Icons.person_add_alt_1, color: Colors.teal), SizedBox(width: 8), Text("Tambah Waktu (Per Siswa)"),
                    ])),
                    const PopupMenuItem(value: 'reset', child: Row(children: [
                      Icon(Icons.refresh, color: Colors.orange), SizedBox(width: 8), Text("Reset Semua Status"),
                    ])),
                    const PopupMenuItem(value: 'reset_resume', child: Row(children: [
                      Icon(Icons.replay, color: Colors.purple), SizedBox(width: 8), Text("Reset & Lanjutkan (Per Siswa)"),
                    ])),
                    if (exam.kkm > 0) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'remedial_bank', child: Row(children: [
                        Icon(Icons.healing, color: Colors.deepOrange), SizedBox(width: 8), Text("Remedial dari Bank Soal"),
                      ])),
                    ],
                  ],
                ),
              ]),
            ),

            // Manual Tab Switcher
            Container(
              color: Colors.white,
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(
                          color: _tabIndex == 0 ? const Color(0xFF0F172A) : Colors.transparent,
                          width: 2,
                        )),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.groups,
                            color: _tabIndex == 0 ? const Color(0xFF0F172A) : Colors.grey,
                            size: 18),
                        const SizedBox(width: 6),
                        Text("Peserta",
                            style: TextStyle(
                                color: _tabIndex == 0 ? const Color(0xFF0F172A) : Colors.grey,
                                fontWeight: _tabIndex == 0 ? FontWeight.bold : FontWeight.normal)),
                      ]),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(
                          color: _tabIndex == 1 ? const Color(0xFF0F172A) : Colors.transparent,
                          width: 2,
                        )),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.bar_chart,
                            color: _tabIndex == 1 ? const Color(0xFF0F172A) : Colors.grey,
                            size: 18),
                        const SizedBox(width: 6),
                        Text("Statistik",
                            style: TextStyle(
                                color: _tabIndex == 1 ? const Color(0xFF0F172A) : Colors.grey,
                                fontWeight: _tabIndex == 1 ? FontWeight.bold : FontWeight.normal)),
                      ]),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _tabIndex = 2);
                      if (_itemAnalysis == null && !_loadingAnalysis) _loadItemAnalysis();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(
                          color: _tabIndex == 2 ? const Color(0xFF0F172A) : Colors.transparent,
                          width: 2,
                        )),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.analytics,
                            color: _tabIndex == 2 ? const Color(0xFF0F172A) : Colors.grey,
                            size: 18),
                        const SizedBox(width: 6),
                        Text("Analisis",
                            style: TextStyle(
                                color: _tabIndex == 2 ? const Color(0xFF0F172A) : Colors.grey,
                                fontWeight: _tabIndex == 2 ? FontWeight.bold : FontWeight.normal)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),

            // Tab content
            Expanded(
              child: _tabIndex == 2
                  ? _buildAnalisisTab()
                  : _tabIndex == 1
                  ? _buildStatistikTab(peserta)
                  : Column(children: [
                // Filter bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Column(children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Cari nama atau kode siswa...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _filterChip("semua", "Semua (${peserta.length})", Colors.blueGrey),
                        const SizedBox(width: 6),
                        _filterChip("belum", "Belum (${belum.length})", Colors.grey),
                        const SizedBox(width: 6),
                        _filterChip("mengerjakan", "Ujian (${mengerjakan.length})", Colors.indigo),
                        const SizedBox(width: 6),
                        _filterChip("selesai", "Selesai (${selesai.length})", Colors.green),
                        const SizedBox(width: 6),
                        _filterChip("melanggar", "Langgar (${melanggar.length})", Colors.red),
                      ]),
                    ),
                  ]),
                ),

                // Peserta list
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      // Progress bar
                      if (peserta.isNotEmpty) ...[
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(children: [
                              Row(children: [
                                _statCard("Total", peserta.length, Colors.blue, Icons.groups),
                                const SizedBox(width: 8),
                                _statCard("Selesai", selesai.length, Colors.green, Icons.check_circle),
                                const SizedBox(width: 8),
                                _statCard("Ujian", mengerjakan.length, Colors.indigo, Icons.edit),
                                const SizedBox(width: 8),
                                _statCard("Langgar", melanggar.length, Colors.red, Icons.warning),
                              ]),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: selesai.length / peserta.length,
                                  minHeight: 10,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: const AlwaysStoppedAnimation(Colors.green),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${selesai.length} dari ${peserta.length} siswa selesai (${(selesai.length / peserta.length * 100).toStringAsFixed(0)}%)",
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Grouped by class
                      if (filtered.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(children: [
                              Icon(Icons.search_off, size: 50, color: Colors.grey),
                              SizedBox(height: 10),
                              Text("Tidak ada siswa ditemukan.",
                                  style: TextStyle(color: Colors.grey)),
                            ]),
                          ),
                        )
                      else
                        ...sortedKeys.map((kelas) {
                          final siswaKelas = grouped[kelas]!;
                          final sK = siswaKelas.where((s) => _statusForExam(s) == 'selesai').length;
                          final lK = siswaKelas.where((s) => _statusForExam(s) == 'melanggar').length;
                          final mK = siswaKelas.where((s) => _statusForExam(s) == 'mengerjakan').length;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0F172A),
                                child: Text(kelas,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              title: Text("Kelas $kelas",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Wrap(spacing: 4, children: [
                                _miniChip("${siswaKelas.length} siswa", Colors.blueGrey),
                                if (mK > 0) _miniChip("$mK ujian", Colors.indigo),
                                if (sK > 0) _miniChip("$sK selesai", Colors.green),
                                if (lK > 0) _miniChip("$lK langgar", Colors.red),
                              ]),
                              children: siswaKelas.map((s) {
                                final sc = _statusColor(s.statusMengerjakan);
                                final si = _statusIcon(s.statusMengerjakan);
                                final sl = _statusLabel(s.statusMengerjakan);
                                // Get violation data for this exam
                                final vCount = s.violationForExam(exam.id);
                                final rawExam = s.examStatus[exam.id];
                                final proktorCount = (rawExam is Map && rawExam['proktorUnlockCount'] is int)
                                    ? rawExam['proktorUnlockCount'] as int : 0;
                                final lastReason = (rawExam is Map && rawExam['lastViolationReason'] != null)
                                    ? rawExam['lastViolationReason'].toString() : '';
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                      backgroundColor: sc,
                                      child: const Icon(Icons.person, color: Colors.white, size: 16)),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(s.nama, style: const TextStyle(fontSize: 13)),
                                      ),
                                      // Violation badges next to name
                                      if (vCount > 0)
                                        Container(
                                          margin: const EdgeInsets.only(left: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.red.shade300),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.warning, size: 10, color: Colors.red.shade700),
                                              const SizedBox(width: 2),
                                              Text('$vCount', style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      if (proktorCount > 0)
                                        Container(
                                          margin: const EdgeInsets.only(left: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.orange.shade300),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.vpn_key, size: 10, color: Colors.orange.shade700),
                                              const SizedBox(width: 2),
                                              Text('$proktorCount', style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Builder(builder: (_) {
                                    final sd = _scoreData?[s.id];
                                    final nilai = sd != null ? ((sd['totalNilai'] as num?)?.toDouble() ?? 0) : 0.0;
                                    final hasScore = sd != null && nilai > 0;
                                    final isTuntas = hasScore && exam.kkm > 0 && nilai >= exam.kkm;
                                    final isTidakTuntas = hasScore && exam.kkm > 0 && nilai < exam.kkm;
                                    return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(child: Text("Kode: ${s.kode}  •  Ruang: ${s.ruang}",
                                            style: const TextStyle(fontSize: 11))),
                                        if (hasScore) ...[
                                          Text("${nilai.toStringAsFixed(0)}",
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                                  color: isTidakTuntas ? Colors.red : Colors.green.shade700)),
                                          if (exam.kkm > 0) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: isTuntas ? Colors.green.shade50 : Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: isTuntas ? Colors.green.shade300 : Colors.red.shade300),
                                              ),
                                              child: Text(isTuntas ? "T" : "BT",
                                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                                                      color: isTuntas ? Colors.green.shade700 : Colors.red.shade700)),
                                            ),
                                          ],
                                        ],
                                      ]),
                                      // Show last violation reason if any
                                      if (lastReason.isNotEmpty)
                                        Text(
                                          "Alasan: $lastReason",
                                          style: TextStyle(fontSize: 10, color: Colors.red.shade600, fontStyle: FontStyle.italic),
                                        ),
                                    ],
                                  );
                                  }),
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: sc, borderRadius: BorderRadius.circular(20)),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(si, color: Colors.white, size: 11),
                                        const SizedBox(width: 4),
                                        Text(sl,
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                      ]),
                                    ),
                                    if (s.statusMengerjakan != 'belum mulai')
                                      IconButton(
                                        icon: const Icon(Icons.refresh, size: 16, color: Colors.orange),
                                        tooltip: "Reset status",
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text("Reset Status?"),
                                              content: Text("Reset status \${s.nama} ke Belum Mulai?"),
                                              actions: [
                                                TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: const Text("Batal")),
                                                ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.orange,
                                                        foregroundColor: Colors.white),
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: const Text("Reset")),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(s.id)
                                                .update({'status_mengerjakan': 'belum mulai'});
                                          }
                                        },
                                      ),
                                  ]),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                    ]),
                  ),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

