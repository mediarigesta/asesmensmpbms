part of '../main.dart';

// ============================================================
// JadwalScreen
// ============================================================
class JadwalScreen extends StatefulWidget {
  final String role; // 'admin1', 'guru', 'siswa'
  final String userKode; // for siswa: kode like "7A01" → kelas 7
  const JadwalScreen({super.key, required this.role, this.userKode = ''});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  List<Map<String, dynamic>> _ujianRows = [];
  List<Map<String, dynamic>> _mengawasRows = [];
  bool _loading = true;
  String? _ujianUpdatedAt;
  String? _mengawasUpdatedAt;

  bool get _isSiswa => widget.role == 'siswa';

  // Extract kelas number from kode: "7A01" → "7", "9B" → "9"
  String get _kelasNum {
    if (widget.userKode.isEmpty) return '';
    final m = RegExp(r'(\d)').firstMatch(widget.userKode);
    return m?.group(1) ?? '';
  }

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: _isSiswa ? 1 : 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final db = FirebaseFirestore.instance;
      // Jadwal Ujian
      final ujianDoc = await db.collection('jadwal').doc('ujian').get();
      if (ujianDoc.exists && ujianDoc.data() != null) {
        _ujianRows = List<Map<String, dynamic>>.from(
            ujianDoc.data()!['rows'] as List? ?? []);
        _ujianUpdatedAt = ujianDoc.data()!['updatedAt']?.toString();
      }
      // Jadwal Mengawas (admin/guru only)
      if (!_isSiswa) {
        final mDoc = await db.collection('jadwal').doc('mengawas').get();
        if (mDoc.exists && mDoc.data() != null) {
          _mengawasRows = List<Map<String, dynamic>>.from(
              mDoc.data()!['rows'] as List? ?? []);
          _mengawasUpdatedAt = mDoc.data()!['updatedAt']?.toString();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bm = context.bm;
    return Column(children: [
      // ── Tab header (admin/guru only) ──
      if (!_isSiswa)
        Container(
          color: bm.primary,
          child: TabBar(
            controller: _tc,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(
                fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.event_note_outlined, size: 18), text: 'Jadwal Ujian'),
              Tab(icon: Icon(Icons.supervisor_account_outlined, size: 18), text: 'Jadwal Mengawas'),
            ],
          ),
        ),
      // ── Body ──
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _isSiswa
                ? _ujianView(forSiswa: true)
                : TabBarView(
                    controller: _tc,
                    children: [
                      _ujianView(forSiswa: false),
                      _mengawasView(),
                    ],
                  ),
      ),
    ]);
  }

  // ── Jadwal Ujian view ──
  Widget _ujianView({required bool forSiswa}) {
    if (_ujianRows.isEmpty) {
      return _emptyState(
        icon: Icons.calendar_today_outlined,
        message: 'Belum ada jadwal ujian.',
        subtitle: 'Admin perlu sinkronisasi dari Google Sheets.',
        updatedAt: _ujianUpdatedAt,
      );
    }

    final List<String> headers;
    final List<List<String>> rows;

    if (forSiswa) {
      final k = _kelasNum;
      final kelasKey = 'kelas$k';
      headers = ['Hari / Tanggal', 'Pukul', 'Mata Pelajaran'];
      rows = _ujianRows
          .map((r) => [
                r['hari']?.toString() ?? '',
                r['pukul']?.toString() ?? '',
                r[kelasKey]?.toString() ?? '-',
              ])
          .toList();
    } else {
      headers = ['Hari / Tanggal', 'Pukul', 'Kelas 7', 'Kelas 8', 'Kelas 9'];
      rows = _ujianRows
          .map((r) => [
                r['hari']?.toString() ?? '',
                r['pukul']?.toString() ?? '',
                r['kelas7']?.toString() ?? '-',
                r['kelas8']?.toString() ?? '-',
                r['kelas9']?.toString() ?? '-',
              ])
          .toList();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _infoBar(Icons.event_note_outlined, 'Jadwal Ujian', _ujianUpdatedAt),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildTable(headers, rows),
          ),
        ]),
      ),
    );
  }

  // ── Jadwal Mengawas view ──
  Widget _mengawasView() {
    if (_mengawasRows.isEmpty) {
      return _emptyState(
        icon: Icons.person_search_outlined,
        message: 'Belum ada jadwal mengawas.',
        subtitle: 'Admin perlu sinkronisasi dari Google Sheets.',
        updatedAt: _mengawasUpdatedAt,
      );
    }

    // Determine number of ruang columns from first row
    final numRuang = _mengawasRows.first.keys
        .where((k) => k.startsWith('ruang'))
        .length;
    final headers = <String>[
      'Hari / Tanggal',
      'Pukul',
      ...List.generate(numRuang, (i) => 'Ruang ${i + 1}'),
    ];
    final rows = _mengawasRows
        .map((r) => <String>[
              r['hari']?.toString() ?? '',
              r['pukul']?.toString() ?? '',
              ...List.generate(
                  numRuang, (i) => r['ruang${i + 1}']?.toString() ?? '-'),
            ])
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _infoBar(Icons.supervisor_account_outlined, 'Jadwal Mengawas', _mengawasUpdatedAt),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildTable(headers, rows),
          ),
        ]),
      ),
    );
  }

  // ── Reusable table ──
  Widget _buildTable(List<String> headers, List<List<String>> rows) {
    final bm = context.bm;
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(color: bm.primary),
          children: headers
              .map((h) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    child: Text(h,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                        textAlign: TextAlign.center),
                  ))
              .toList(),
        ),
        // Data rows
        ...rows.asMap().entries.map((e) => TableRow(
              decoration: BoxDecoration(
                  color: e.key.isEven ? Colors.white : const Color(0xFFF8FAFC)),
              children: e.value
                  .map((cell) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        child: Text(
                          cell.isEmpty ? '-' : cell,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ))
                  .toList(),
            )),
      ],
    );
  }

  // ── Info bar showing last sync time ──
  Widget _infoBar(IconData icon, String title, String? updatedAt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155))),
            if (updatedAt != null && updatedAt.isNotEmpty)
              Text('Diperbarui: $updatedAt',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF94A3B8))),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF64748B)),
          tooltip: 'Perbarui',
          onPressed: _load,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  // ── Empty state ──
  Widget _emptyState(
      {required IconData icon,
      required String message,
      String? subtitle,
      String? updatedAt}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                textAlign: TextAlign.center),
          ],
          if (updatedAt != null && updatedAt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Terakhir: $updatedAt',
                style:
                    TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba Lagi'),
          ),
        ]),
      ),
    );
  }
}
