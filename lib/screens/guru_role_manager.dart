part of '../main.dart';

// ============================================================
// GURU ROLE MANAGER — Manajemen Role & Mapel Guru (Admin1 only)
// ============================================================
// Firestore schema tambahan di dokumen user guru:
//   roles: List<String>  — ['guru', 'admin1'] (bisa keduanya)
//   mapelRoles: List<String> — ['IPA', 'Matematika'] (mapel yang boleh diakses)
// ============================================================
class GuruRoleManager extends StatefulWidget {
  const GuruRoleManager({super.key});

  static const availableRoles = [
    _RoleOption('admin1', 'Admin', Icons.admin_panel_settings, Colors.purple,
        'Akses penuh: buat ujian, kelola siswa, kelola guru, lihat semua nilai'),
    _RoleOption('guru', 'Guru', Icons.school, Colors.blue,
        'Upload soal & ujian, lihat nilai, akses sesuai mata pelajaran'),
  ];

  @override
  State<GuruRoleManager> createState() => _GuruRoleManagerState();
}

class _GuruRoleManagerState extends State<GuruRoleManager> {
  String _search = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.manage_accounts, color: Color(0xFF0F172A), size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Manajemen Role Guru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Atur hak akses dan mata pelajaran setiap guru',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
        ]),
      ),

      // Search bar
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: TextField(
          onChanged: (v) => setState(() => _search = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Cari nama guru...',
            prefixIcon: const Icon(Icons.search, size: 18),
            filled: true, fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),

      const Divider(height: 1),

      // Info banner
      Container(
        width: double.infinity,
        color: Colors.amber.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Perubahan role langsung tersimpan ke akun guru. '
                'Guru perlu logout & login ulang agar perubahan berlaku.',
            style: TextStyle(color: Colors.amber.shade900, fontSize: 11),
          )),
        ]),
      ),

      // Daftar guru
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users')
              .where('role', whereIn: ['guru', 'admin1']).snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final gurus = snap.data!.docs
                .map((d) => UserAccount.fromFirestore(d))
                .where((g) => _search.isEmpty ||
                g.nama.toLowerCase().contains(_search) ||
                g.username.toLowerCase().contains(_search))
                .toList()
              ..sort((a, b) => a.nama.compareTo(b.nama));

            if (gurus.isEmpty) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.person_off, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                const Text('Tidak ada guru ditemukan', style: TextStyle(color: Colors.grey)),
              ]));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: gurus.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _GuruRoleCard(guru: gurus[i]),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Model untuk pilihan role ──
class _RoleOption {
  final String value, label, description;
  final IconData icon;
  final Color color;
  const _RoleOption(this.value, this.label, this.icon, this.color, this.description);
}

// ── Card untuk setiap guru di GuruRoleManager ──
class _GuruRoleCard extends StatefulWidget {
  final UserAccount guru;
  const _GuruRoleCard({required this.guru});
  @override
  State<_GuruRoleCard> createState() => _GuruRoleCardState();
}

class _GuruRoleCardState extends State<_GuruRoleCard> {
  Set<String> _roles = {};
  Set<String> _mapelRoles = {};
  List<String> _allMapel = [];
  bool _saving = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _roles = {widget.guru.role};
    _loadFromFirestore();
    _loadAllMapel();
  }

  void _loadFromFirestore() async {
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(widget.guru.id).get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    if (!mounted) return;
    setState(() {
      // roles: list dari Firestore, fallback ke role saat ini
      final rawRoles = data['roles'];
      if (rawRoles is List) {
        _roles = Set<String>.from(rawRoles.map((e) => e.toString()));
      } else {
        _roles = {widget.guru.role};
      }
      // mapelRoles: list mata pelajaran yang boleh diakses guru ini
      final rawMapel = data['mapelRoles'];
      if (rawMapel is List) {
        _mapelRoles = Set<String>.from(rawMapel.map((e) => e.toString()));
      } else {
        _mapelRoles = {};
      }
    });
  }

  void _loadAllMapel() async {
    final snap = await FirebaseFirestore.instance.collection('subjects').get();
    if (!mounted) return;
    setState(() {
      _allMapel = snap.docs.map((d) => d['name'].toString()).toList()..sort();
    });
  }

  // Simpan perubahan role & mapel ke Firestore
  Future<void> _save() async {
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih minimal satu role!'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _saving = true);
    try {
      // Primary role = admin1 jika ada, else guru
      final primaryRole = _roles.contains('admin1') ? 'admin1' : 'guru';
      await FirebaseFirestore.instance.collection('users').doc(widget.guru.id).update({
        'role': primaryRole,
        'roles': _roles.toList(),
        'mapelRoles': _mapelRoles.toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('Role ${widget.guru.nama} berhasil diperbarui'),
        ]),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal simpan: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan warna berdasarkan role
    Color cardAccent = _roles.contains('admin1')
        ? Colors.purple
        : Colors.blue;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardAccent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(
            color: cardAccent.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // ── Header card ──
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: cardAccent.withValues(alpha: 0.12),
                child: Text(widget.guru.initials,
                    style: TextStyle(color: cardAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 14),

              // Info guru
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.guru.nama,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text('@${widget.guru.username}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                // Role badges
                Wrap(spacing: 5, runSpacing: 4, children: [
                  ..._roles.map((r) {
                    final opt = GuruRoleManager.availableRoles
                        .firstWhere((o) => o.value == r,
                        orElse: () => _RoleOption(r, r, Icons.person, Colors.grey, ''));
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: opt.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(opt.icon, size: 11, color: opt.color),
                        const SizedBox(width: 4),
                        Text(opt.label,
                            style: TextStyle(color: opt.color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ]),
                    );
                  }),
                  // Mapel badges
                  ..._mapelRoles.map((m) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.book, size: 11, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text(m, style: const TextStyle(color: Colors.teal, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  )),
                  if (_mapelRoles.isEmpty && _roles.contains('guru'))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Belum ada mapel',
                          style: TextStyle(color: Colors.orange, fontSize: 10)),
                    ),
                ]),
              ])),

              // Expand arrow + save button
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (_saving)
                  const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: cardAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _save,
                    icon: const Icon(Icons.save, size: 14),
                    label: const Text('Simpan', style: TextStyle(fontSize: 12)),
                  ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  onSelected: (val) async {
                    if (val == 'reset') {
                      const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
                      final t = DateTime.now().microsecondsSinceEpoch;
                      final newPass = List.generate(8, (i) => chars[(t ~/ (i + 1)) % chars.length]).join()
                          + DateTime.now().millisecond.toString().padLeft(2, '0');
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.guru.id)
                          .update({'password': newPass});
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Password Baru'),
                            content: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Text('Password berhasil direset:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 12),
                              _credRow(context, 'Username', widget.guru.username),
                              const SizedBox(height: 8),
                              _credRow(context, 'Password', newPass),
                            ]),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
                            ],
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'reset', child: Row(children: [
                      Icon(Icons.lock_reset_outlined, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Reset Password', style: TextStyle(fontSize: 13)),
                    ])),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey),
              ]),
            ]),
          ),
        ),

        // ── Expanded: role & mapel editor ──
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Section: Role ──
              const Row(children: [
                Icon(Icons.admin_panel_settings_outlined, size: 15, color: Color(0xFF0F172A)),
                SizedBox(width: 6),
                Text('Role & Hak Akses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              ...GuruRoleManager.availableRoles.map((opt) {
                final isChecked = _roles.contains(opt.value);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isChecked ? opt.color.withValues(alpha: 0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChecked ? opt.color.withValues(alpha: 0.4) : Colors.grey.shade200,
                      width: isChecked ? 1.5 : 1,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: isChecked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _roles.add(opt.value);
                        } else {
                          _roles.remove(opt.value);
                        }
                      });
                    },
                    activeColor: opt.color,
                    title: Row(children: [
                      Icon(opt.icon, color: opt.color, size: 16),
                      const SizedBox(width: 8),
                      Text(opt.label,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isChecked ? opt.color : Colors.black87,
                              fontSize: 13)),
                    ]),
                    subtitle: Text(opt.description,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // ── Section: Mata Pelajaran ──
              Row(children: [
                const Icon(Icons.book_outlined, size: 15, color: Colors.teal),
                const SizedBox(width: 6),
                const Text('Mata Pelajaran yang Diajarkan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                if (_roles.contains('admin1'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Admin: akses semua mapel',
                        style: TextStyle(color: Colors.purple, fontSize: 10)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(
                _roles.contains('admin1')
                    ? 'Sebagai Admin, guru ini dapat mengakses semua mata pelajaran.'
                    : 'Centang mata pelajaran yang boleh diupload dan dikelola oleh guru ini.',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 10),

              if (_allMapel.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Belum ada mata pelajaran. Tambah di menu Mapel.',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allMapel.map((m) {
                    final isChecked = _mapelRoles.contains(m);
                    final isAdmin = _roles.contains('admin1');
                    return FilterChip(
                      label: Text(m, style: const TextStyle(fontSize: 12)),
                      selected: isChecked || isAdmin,
                      onSelected: isAdmin ? null : (val) {
                        setState(() {
                          if (val) _mapelRoles.add(m);
                          else _mapelRoles.remove(m);
                        });
                      },
                      selectedColor: Colors.teal.withValues(alpha: 0.15),
                      checkmarkColor: Colors.teal,
                      side: BorderSide(
                          color: (isChecked || isAdmin)
                              ? Colors.teal.withValues(alpha: 0.5)
                              : Colors.grey.shade300),
                      avatar: Icon(Icons.book,
                          size: 13,
                          color: (isChecked || isAdmin) ? Colors.teal : Colors.grey),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // ── Ringkasan akses ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0F172A).withValues(alpha: 0.1)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.summarize_outlined, size: 13, color: Color(0xFF0F172A)),
                    SizedBox(width: 6),
                    Text('Ringkasan Hak Akses',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                            color: Color(0xFF0F172A))),
                  ]),
                  const SizedBox(height: 8),
                  ..._buildAccessSummary(),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  // Ringkasan hak akses berdasarkan role & mapel yang dipilih
  List<Widget> _buildAccessSummary() {
    final items = <_SummaryItem>[];
    final isAdmin = _roles.contains('admin1');
    final isGuru = _roles.contains('guru');

    if (isAdmin) {
      items.addAll([
        _SummaryItem(Icons.check, 'Buat & kelola semua ujian', true),
        _SummaryItem(Icons.check, 'Kelola akun siswa & guru', true),
        _SummaryItem(Icons.check, 'Lihat semua nilai & rekap', true),
        _SummaryItem(Icons.check, 'Broadcast pesan ke siswa', true),
        _SummaryItem(Icons.check, 'Akses semua mata pelajaran', true),
        _SummaryItem(Icons.check, 'Setting PIN proktor', true),
      ]);
    } else if (isGuru) {
      items.add(_SummaryItem(Icons.check,
          'Buat ujian untuk: ${_mapelRoles.isEmpty ? "(pilih mapel dulu)" : _mapelRoles.join(", ")}',
          _mapelRoles.isNotEmpty));
      items.add(_SummaryItem(Icons.check,
          'Upload soal untuk mapel yang ditentukan', _mapelRoles.isNotEmpty));
      items.add(_SummaryItem(Icons.check, 'Lihat nilai siswa', true));
      items.add(_SummaryItem(Icons.close, 'Kelola akun siswa/guru', false));
      items.add(_SummaryItem(Icons.close, 'Akses setting & broadcast', false));
    }

    if (items.isEmpty) {
      return [const Text('Pilih role terlebih dahulu.',
          style: TextStyle(color: Colors.grey, fontSize: 12))];
    }

    return items.map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(item.icon, size: 13, color: item.ok ? Colors.green : Colors.red),
        const SizedBox(width: 6),
        Expanded(child: Text(item.label,
            style: TextStyle(fontSize: 11,
                color: item.ok ? Colors.black87 : Colors.grey))),
      ]),
    )).toList();
  }

  Widget _credRow(BuildContext ctx, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
        ])),
        IconButton(
          icon: const Icon(Icons.copy_outlined, size: 18, color: Colors.blue),
          tooltip: 'Salin',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('$label disalin!'), duration: const Duration(seconds: 1)));
          },
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      ]),
    );
  }
}

class _SummaryItem {
  final IconData icon;
  final String label;
  final bool ok;
  const _SummaryItem(this.icon, this.label, this.ok);
}

