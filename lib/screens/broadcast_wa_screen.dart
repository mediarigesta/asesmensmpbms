part of '../main.dart';

// ============================================================================
// HALAMAN BROADCAST WA (GURU: SINGLE, SISWA: MULTI-TARGET)
// ============================================================================
class BroadcastWaScreen extends StatefulWidget {
  const BroadcastWaScreen({Key? key}) : super(key: key);

  @override
  State<BroadcastWaScreen> createState() => _BroadcastWaScreenState();
}

class _BroadcastWaScreenState extends State<BroadcastWaScreen> {
  final TextEditingController _pesanController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedRuang = 'Semua';
  bool _kirimKeAnak = true;
  bool _kirimKeAyah = false;
  bool _kirimKeIbu = false;
  bool _kirimKeWali = false;

  bool _isLoading = false;
  List<Map<String, dynamic>> _allUsers = [];
  Map<String, bool> _selectedUserIds = {};

  final String _fonnteToken = 'ExpRMDG5Kd4fm5sSd9wV';

  static const List<Map<String, String>> _templates = [
    {'label': 'Mulai Ujian', 'text': 'Ujian akan segera dimulai. Mohon siapkan alat tulis dan tenang di tempat duduk.'},
    {'label': 'Tunda Ujian', 'text': 'Pengumuman: Ujian hari ini ditunda. Informasi lebih lanjut akan menyusul.'},
    {'label': 'Hadir Tepat Waktu', 'text': 'Mohon pastikan siswa hadir tepat waktu dan membawa perlengkapan ujian.'},
    {'label': 'Hasil Ujian', 'text': 'Hasil ujian sudah dapat dilihat. Silakan hubungi sekolah untuk informasi lebih lanjut.'},
  ];

  static const List<String> _ruangOptions = [
    'Semua',
    '7A', '7B', '7C', '7D',
    '8A', '8B', '8C', '8D',
    '9A', '9B', '9C', '9D',
    'GURU',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetchUsers();
  }

  @override
  void dispose() {
    _pesanController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _searchController.text.toLowerCase();
    return _allUsers.where((u) {
      if (q.isEmpty) return true;
      return (u['nama'] ?? '').toLowerCase().contains(q) ||
          (u['ruang'] ?? '').toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        // users with numbers first
        final aN = _userPunyaNomor(a) ? 0 : 1;
        final bN = _userPunyaNomor(b) ? 0 : 1;
        if (aN != bN) return aN - bN;
        return (a['nama'] ?? '').compareTo(b['nama'] ?? '');
      });
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance.collection('users');
      if (_selectedRuang == 'GURU') {
        query = query.where('role', isEqualTo: 'guru');
      } else if (_selectedRuang != 'Semua') {
        query = query.where('kode', isEqualTo: _selectedRuang);
      }
      final snapshot = await query.get();
      setState(() {
        _allUsers = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        })
        // Eksklusi admin dari daftar broadcast
        .where((u) => u['role'] != 'admin1')
        .toList();

        _selectedUserIds.clear();
        for (var user in _allUsers) {
          _selectedUserIds[user['id']] = true;
        }
      });
    } catch (e) {
      _showSnackBar('Gagal load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatNomor(String nomor) {
    final clean = nomor.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) return '62${clean.substring(1)}';
    return clean;
  }

  Future<void> _sendToFonnte(String target, String message) async {
    final response = await http.post(
      Uri.parse('https://api.fonnte.com/send'),
      headers: {'Authorization': _fonnteToken},
      body: {'target': target, 'message': message, 'delay': '2'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
  }

  bool _userPunyaNomor(Map<String, dynamic> user) {
    final isGuru = user['role']?.toString().toLowerCase() == 'guru';
    if (isGuru) return user['no_telp_anak']?.isNotEmpty == true;
    return (_kirimKeAnak && user['no_telp_anak']?.isNotEmpty == true) ||
        (_kirimKeAyah && user['no_telp_ayah']?.isNotEmpty == true) ||
        (_kirimKeIbu && user['no_telp_ibu']?.isNotEmpty == true) ||
        (_kirimKeWali && user['no_telp_wali']?.isNotEmpty == true);
  }

  void _selectAll() => setState(() {
        for (var user in _filteredUsers) _selectedUserIds[user['id']] = true;
      });

  void _deselectAll() => setState(() {
        for (var user in _filteredUsers) _selectedUserIds[user['id']] = false;
      });

  Set<String> _collectTargetNumbers() {
    final Set<String> nums = {};
    for (var user in _filteredUsers) {
      if (_selectedUserIds[user['id']] != true) continue;
      final isGuru = user['role']?.toString().toLowerCase() == 'guru';
      if (isGuru) {
        if (user['no_telp_anak']?.isNotEmpty == true) nums.add(_formatNomor(user['no_telp_anak']));
      } else {
        if (_kirimKeAnak && user['no_telp_anak']?.isNotEmpty == true) nums.add(_formatNomor(user['no_telp_anak']));
        if (_kirimKeAyah && user['no_telp_ayah']?.isNotEmpty == true) nums.add(_formatNomor(user['no_telp_ayah']));
        if (_kirimKeIbu && user['no_telp_ibu']?.isNotEmpty == true) nums.add(_formatNomor(user['no_telp_ibu']));
        if (_kirimKeWali && user['no_telp_wali']?.isNotEmpty == true) nums.add(_formatNomor(user['no_telp_wali']));
      }
    }
    return nums;
  }

  Future<void> _kirimTestKeSaya() async {
    if (_pesanController.text.isEmpty) {
      _showSnackBar('Ketik pesan test dulu!');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
      final adminPhone = doc.data()?['admin_phone']?.toString() ?? '';
      if (adminPhone.isEmpty) {
        _showSnackBar('Nomor WA Admin belum diatur. Isi di Settings → Nomor WA Admin.');
        return;
      }
      final formatted = _formatNomor(adminPhone);
      await _sendToFonnte(formatted, '[TEST BROADCAST]\n${_pesanController.text}');
      _showSnackBar('Test terkirim ke $formatted', isSuccess: true);
    } catch (e) {
      _showSnackBar('Gagal: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _kirimBroadcastMassal() async {
    if (_pesanController.text.trim().isEmpty) {
      _showSnackBar('Pesan tidak boleh kosong!');
      return;
    }
    final targetNumbers = _collectTargetNumbers();
    if (targetNumbers.isEmpty) {
      _showSnackBar('Tidak ada nomor tujuan yang terdeteksi!');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final bm = Theme.of(ctx).extension<BMColors>()!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bm.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.campaign_rounded, color: bm.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Konfirmasi Kirim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bm.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.people_alt_rounded, size: 18, color: bm.primary),
                  const SizedBox(width: 8),
                  Text('${targetNumbers.length} nomor WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.bold, color: bm.primary)),
                ]),
              ),
              const SizedBox(height: 12),
              const Text('Pesan:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Text(_pesanController.text.trim(),
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: bm.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kirim Sekarang'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _sendToFonnte(targetNumbers.join(','), _pesanController.text.trim());
      _showSnackBar('Berhasil terkirim ke ${targetNumbers.length} nomor!', isSuccess: true);
      _pesanController.clear();
    } catch (e) {
      _showSnackBar('Gagal kirim: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  String _initials(String nama) {
    final parts = nama.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bm = context.bm;
    final previewNumbers = _collectTargetNumbers();
    final users = _filteredUsers;
    final selectedCount = users.where((u) => _selectedUserIds[u['id']] == true).length;

    return Scaffold(
      backgroundColor: bm.surface,
      appBar: AppBar(
        title: const Text('Broadcast WhatsApp',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: bm.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Panel Pesan ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bm.primary, bm.gradient2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Template cepat
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _templates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) => ActionChip(
                      avatar: const Icon(Icons.bolt, size: 12, color: Colors.white70),
                      label: Text(_templates[i]['label']!,
                          style: const TextStyle(fontSize: 11, color: Colors.white)),
                      onPressed: () =>
                          setState(() => _pesanController.text = _templates[i]['text']!),
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Text field pesan + tombol test dalam Row
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _pesanController,
                        maxLines: 2,
                        minLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tulis pengumuman...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol test compact
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: _isLoading ? null : _kirimTestKeSaya,
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.send_to_mobile_outlined, size: 18),
                        SizedBox(height: 2),
                        Text('Test', style: TextStyle(fontSize: 10)),
                      ]),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          // ── Panel Filter ──
          Container(
            color: bm.cardBg,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              children: [
                Row(children: [
                  // Dropdown filter kelas
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: bm.surface,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRuang,
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: bm.primary),
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                              fontFamily: 'Poppins'),
                          items: _ruangOptions
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedRuang = val!);
                            _fetchUsers();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search field
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: bm.surface,
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari nama...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => _searchController.clear(),
                                  padding: EdgeInsets.zero,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                // Checkbox target nomor (hanya jika bukan filter GURU)
                if (_selectedRuang != 'GURU')
                  Row(children: [
                    const Text('Kirim ke:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    _chip('Siswa/Anak', _kirimKeAnak, (v) => setState(() => _kirimKeAnak = v), bm),
                    const SizedBox(width: 4),
                    _chip('Ayah', _kirimKeAyah, (v) => setState(() => _kirimKeAyah = v), bm),
                    const SizedBox(width: 4),
                    _chip('Ibu', _kirimKeIbu, (v) => setState(() => _kirimKeIbu = v), bm),
                    const SizedBox(width: 4),
                    _chip('Wali', _kirimKeWali, (v) => setState(() => _kirimKeWali = v), bm),
                  ]),
                const SizedBox(height: 8),
                // Toolbar: pilih semua + info count
                Row(children: [
                  _toolbarBtn(Icons.check_box_outlined, 'Pilih Semua', _selectAll, bm.primary),
                  const SizedBox(width: 4),
                  _toolbarBtn(Icons.check_box_outline_blank, 'Batal Semua', _deselectAll, Colors.grey.shade600),
                  const Spacer(),
                  if (!_isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: previewNumbers.isNotEmpty ? bm.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${previewNumbers.length} nomor · $selectedCount dipilih',
                        style: TextStyle(
                            color: previewNumbers.isNotEmpty ? Colors.white : Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),
                const Divider(height: 1),
              ],
            ),
          ),

          // ── Daftar User ──
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: bm.primary))
                : users.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'Tidak ada hasil untuk "${_searchController.text}"'
                                : 'Tidak ada data untuk filter ini',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ]),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: users.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
                        itemBuilder: (context, i) {
                          final u = users[i];
                          final punyaNomor = _userPunyaNomor(u);
                          final isSelected = _selectedUserIds[u['id']] == true;
                          final isGuru = u['role']?.toString() == 'guru';
                          final nama = u['nama'] ?? '-';
                          final kode = u['kode']?.toString() ?? '';
                          final ruang = u['ruang']?.toString() ?? '';
                          final roleLabel = isGuru
                              ? 'GURU'
                              : (kode.isNotEmpty ? 'Kelas $kode' : (ruang.isNotEmpty ? 'Ruang $ruang' : '-'));

                          return InkWell(
                            onTap: () => setState(() => _selectedUserIds[u['id']] = !isSelected),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(children: [
                                // Avatar
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: isSelected
                                          ? bm.primary.withOpacity(0.15)
                                          : Colors.grey.shade100,
                                      child: Text(
                                        _initials(nama),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? bm.primary : Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: bm.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          child: const Icon(Icons.check, size: 9, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nama,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: punyaNomor ? null : Colors.grey.shade400,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isGuru
                                                ? Colors.purple.shade50
                                                : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            roleLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isGuru
                                                  ? Colors.purple.shade700
                                                  : Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                        if (!punyaNomor) ...[
                                          const SizedBox(width: 6),
                                          Row(children: [
                                            Icon(Icons.phone_disabled_outlined,
                                                size: 11, color: Colors.grey.shade400),
                                            const SizedBox(width: 2),
                                            Text('Tidak ada nomor',
                                                style: TextStyle(
                                                    fontSize: 10, color: Colors.grey.shade400)),
                                          ]),
                                        ],
                                      ]),
                                    ],
                                  ),
                                ),
                                // Checkbox visual
                                Checkbox(
                                  value: isSelected,
                                  activeColor: bm.primary,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  onChanged: (val) =>
                                      setState(() => _selectedUserIds[u['id']] = val!),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
          ),

          // ── Tombol Kirim ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: bm.cardBg,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: previewNumbers.isNotEmpty ? bm.primary : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: (_isLoading || previewNumbers.isEmpty) ? null : _kirimBroadcastMassal,
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.send_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          previewNumbers.isEmpty
                              ? 'Pilih penerima terlebih dahulu'
                              : 'Kirim ke ${previewNumbers.length} Nomor',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, Function(bool) onTap, BMColors bm) {
    return GestureDetector(
      onTap: () => onTap(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? bm.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? bm.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _toolbarBtn(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
