part of '../main.dart';

// ============================================================
// PROFILE PAGE
// ============================================================
class ProfilePage extends StatefulWidget {
  final UserAccount user;
  final bool canEdit; // true if admin editing another user

  const ProfilePage({super.key, required this.user, required this.canEdit});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _namaCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _ruangCtrl = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _namaCtrl.text = widget.user.nama;
    _ruangCtrl.text = widget.user.ruang;
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _passCtrl.dispose();
    _ruangCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_namaCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'nama': _namaCtrl.text.trim(),
        'ruang': _ruangCtrl.text.trim(),
      };
      if (_passCtrl.text.trim().isNotEmpty) {
        updates['password'] = _passCtrl.text.trim();
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .update(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profil berhasil disimpan!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final roleColors = {
      'admin1': Colors.purple,
      'guru': Colors.teal,
      'siswa': Colors.blue,
    };
    final roleLabels = {
      'admin1': 'Administrator',
      'guru': 'Guru',
      'siswa': 'Siswa',
    };
    final roleColor = roleColors[u.role] ?? Colors.grey;
    final roleLabel = roleLabels[u.role] ?? u.role;

    return Scaffold(
      backgroundColor: context.bm.surface,
      appBar: AppBar(
        backgroundColor: context.bm.primary,
        foregroundColor: Colors.white,
        title: Text(widget.canEdit ? 'Edit Profil: ${u.nama}' : 'Profil Saya'),
        actions: [
          if (widget.canEdit)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white),
              label: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: context.bm.primary,
                      child: Text(u.initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    Text(u.nama,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('@${u.username}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(roleLabel,
                          style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informasi Akun',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Divider(height: 20),
                    _infoRow(Icons.person, 'Username', u.username),
                    _infoRow(Icons.badge, 'Role', roleLabel),
                    if (u.role == 'siswa') ...[
                      _infoRow(Icons.class_, 'Kelas', u.kode),
                      _infoRow(Icons.meeting_room, 'Ruang', u.ruang),
                    ],
                    if (u.role == 'guru') ...[
                      _mapelSection(u.id),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Edit Form (if canEdit)
            if (widget.canEdit) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Data',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const Divider(height: 20),
                      TextField(
                        controller: _namaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nama Lengkap',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ruangCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ruang',
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password Baru (kosongkan jika tidak diubah)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.bm.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save),
                          label: const Text('SIMPAN PERUBAHAN'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ),
      ],
    ),
  );

  Widget _mapelSection(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final data = snap.data!.data() as Map<String, dynamic>?;
        final rawMapel = data?['mapelRoles'];
        final mapels = rawMapel is List
            ? List<String>.from(rawMapel.map((e) => e.toString()))
            : <String>[];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.book_outlined, size: 18, color: Colors.grey),
              SizedBox(width: 12),
              Text('Mata Pelajaran', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            if (mapels.isEmpty)
              const Text('Belum ada mapel', style: TextStyle(color: Colors.orange))
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: mapels.map((m) => Chip(
                  label: Text(m, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.teal.withValues(alpha: 0.1),
                  side: const BorderSide(color: Colors.teal),
                )).toList(),
              ),
          ]),
        );
      },
    );
  }
}

