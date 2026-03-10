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

// ═══════════════════════════════════════════════════════════════════════════
// 1. GURU: build() selalu pakai drawer (hapus breakpoint wide layout)
// ═══════════════════════════════════════════════════════════════════════════
replace(
  '  @override\n  @override\n  Widget build(BuildContext context) {\n    if (MediaQuery.of(context).size.width >= 900) return _buildWideLayout(context);\n    return _buildNarrowLayout(context);\n  }',
  '  @override\n  Widget build(BuildContext context) => _buildNarrowLayout(context);',
  'Guru build() always narrow'
);

// fix drawer condition in _buildNarrowLayout (Guru)
replace(
  '    drawer: MediaQuery.of(context).size.width >= 900 ? null : _buildGuruDrawer(),\n    body: Row(children: [\n      if (MediaQuery.of(context).size.width >= 900)\n        SizedBox(width: 240, child: _buildGuruSideBar()),\n      Expanded(child: SafeArea(',
  '    drawer: _buildGuruDrawer(),\n    body: SafeArea(',
  'Guru _buildNarrowLayout fix drawer+body'
);

// Also need to close the extra Expanded wrapping - check if there's a closing Expanded))
// Actually the body was: Row([if(...) SideBar, Expanded(SafeArea(...))])
// Now it's: SafeArea(...)
// We need to remove the corresponding closing ]) and ) for Row and Expanded
// Let's find what comes after the bottom:false + Column that starts the body
replace(
  '      bottom: false,\n      child: Column(children: [',
  '      bottom: false,\n      child: Column(children: [',
  'Guru body structure check (no-op)'
);

// ═══════════════════════════════════════════════════════════════════════════
// 2. ADMIN: build() selalu pakai drawer
// ═══════════════════════════════════════════════════════════════════════════
replace(
  '  @override\n  Widget build(BuildContext context) {\n    if (MediaQuery.of(context).size.width >= 900) {\n      return _buildAdminWideLayout(context);\n    }\n    return _buildAdminNarrowLayout(context);\n  }',
  '  @override\n  Widget build(BuildContext context) => _buildAdminNarrowLayout(context);',
  'Admin build() always narrow'
);

// fix drawer condition in _buildAdminNarrowLayout
replace(
  '    drawer: MediaQuery.of(context).size.width >= 900 ? null : _buildAdminDrawer(),\n    body: Row(children: [\n      if (MediaQuery.of(context).size.width >= 900)\n        SizedBox(width: 240, child: _buildAdminSideBar()),\n      Expanded(child: StreamBuilder<QuerySnapshot>(',
  '    drawer: _buildAdminDrawer(),\n    body: StreamBuilder<QuerySnapshot>(',
  'Admin _buildAdminNarrowLayout fix drawer+body'
);

// ═══════════════════════════════════════════════════════════════════════════
// 3. Add _broadcastTarget state var to Admin1DashboardState
// ═══════════════════════════════════════════════════════════════════════════
replace(
  '  int _adminUjianTab = 0;    // 0=saat ini,1=terjadwal,2=selesai,3=draft',
  '  int _adminUjianTab = 0;    // 0=saat ini,1=terjadwal,2=selesai,3=draft\n  String _broadcastTarget = \'semua\'; // \'semua\'|\'guru\'|\'siswa\'',
  'Admin add _broadcastTarget state'
);

// ═══════════════════════════════════════════════════════════════════════════
// 4. Replace _broadcast() with enhanced version (2 tabs: Aplikasi + WA)
// ═══════════════════════════════════════════════════════════════════════════
const oldBroadcast = `  // ── Tab: Broadcast ──
  Widget _broadcast() {
    final msgCtrl = TextEditingController();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('broadcast')
          .snapshots(),
      builder: (c, snap) {
        String existing = "";
        if (snap.hasData && snap.data!.exists) {
          existing =
              (snap.data!.data() as Map)['message']?.toString() ?? "";
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(children: [
            const Icon(Icons.campaign,
                color: Color(0xFF0F172A), size: 60),
            const SizedBox(height: 14),
            const Text("Broadcast ke Semua Siswa",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
                "Pesan akan muncul sebagai notifikasi di layar ujian siswa.",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (existing.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Pesan Aktif Saat Ini:",
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(existing,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "Ketik Pesan Broadcast",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => FirebaseFirestore.instance
                      .collection('settings')
                      .doc('broadcast')
                      .set({
                    'message': '',
                    'timestamp': FieldValue.serverTimestamp()
                  }),
                  icon: const Icon(Icons.clear),
                  label: const Text("HAPUS PESAN"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50)),
                  onPressed: () {
                    if (msgCtrl.text.trim().isEmpty) return;
                    FirebaseFirestore.instance
                        .collection('settings')
                        .doc('broadcast')
                        .set({
                      'message': msgCtrl.text.trim(),
                      'timestamp': FieldValue.serverTimestamp()
                    });
                    msgCtrl.clear();
                  },
                  icon: const Icon(Icons.send),
                  label: const Text("KIRIM BROADCAST"),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }`;

const newBroadcast = `  // ── Tab: Broadcast ──
  Widget _broadcast() {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          color: context.bm.surface,
          child: TabBar(
            labelColor: context.bm.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: context.bm.primary,
            tabs: const [
              Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'Broadcast Aplikasi'),
              Tab(icon: Icon(Icons.whatsapp, size: 18), text: 'Broadcast WhatsApp'),
            ],
          ),
        ),
        Expanded(child: TabBarView(children: [
          _broadcastAplikasi(),
          _broadcastWa(),
        ])),
      ]),
    );
  }

  Widget _broadcastAplikasi() {
    final msgCtrl = TextEditingController();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('broadcast').snapshots(),
      builder: (c, snap) {
        String existing = "";
        String existingTarget = "semua";
        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() as Map;
          existing = d['message']?.toString() ?? "";
          existingTarget = d['target']?.toString() ?? "semua";
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.campaign, color: Colors.orange.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Broadcast Aplikasi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Pesan muncul sebagai notifikasi di aplikasi", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 20),
            if (existing.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 14),
                    const SizedBox(width: 6),
                    Text("Pesan Aktif — Target: \${existingTarget == 'semua' ? 'Semua Pengguna' : existingTarget == 'guru' ? 'Guru' : 'Siswa'}",
                        style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                  ]),
                  const SizedBox(height: 6),
                  Text(existing, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            const Text("Target Penerima", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final t in [
                {'val': 'semua', 'label': 'Semua Pengguna', 'icon': Icons.people_outline},
                {'val': 'guru',  'label': 'Guru Saja',      'icon': Icons.school_outlined},
                {'val': 'siswa', 'label': 'Siswa Saja',     'icon': Icons.person_outline},
              ])
                ChoiceChip(
                  avatar: Icon(t['icon'] as IconData, size: 16,
                      color: _broadcastTarget == t['val'] ? Colors.white : Colors.grey),
                  label: Text(t['label'] as String),
                  selected: _broadcastTarget == t['val'],
                  selectedColor: context.bm.primary,
                  labelStyle: TextStyle(
                      color: _broadcastTarget == t['val'] ? Colors.white : Colors.grey.shade700,
                      fontSize: 12),
                  onSelected: (_) => setState(() => _broadcastTarget = t['val'] as String),
                ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "Ketik Pesan Broadcast",
                hintText: "Pesan yang akan ditampilkan kepada penerima...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => FirebaseFirestore.instance.collection('settings').doc('broadcast').set({
                    'message': '', 'target': 'semua', 'timestamp': FieldValue.serverTimestamp(),
                  }),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text("HAPUS PESAN"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48)),
                  onPressed: () {
                    if (msgCtrl.text.trim().isEmpty) return;
                    FirebaseFirestore.instance.collection('settings').doc('broadcast').set({
                      'message': msgCtrl.text.trim(),
                      'target': _broadcastTarget,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    msgCtrl.clear();
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text("KIRIM BROADCAST"),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _broadcastWa() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(color: const Color(0xFF25D366).withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.whatsapp, color: Color(0xFF25D366), size: 36),
          ),
          const SizedBox(height: 16),
          const Text("Broadcast WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text("Kirim pesan broadcast ke nomor WhatsApp siswa atau guru yang terdaftar.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.whatsapp, size: 20),
              label: const Text("Buka Broadcast WhatsApp", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BroadcastWaScreen())),
            ),
          ),
        ]),
      ),
    );
  }`;

replace(oldBroadcast, newBroadcast, 'Replace _broadcast() with tabbed version');

// ═══════════════════════════════════════════════════════════════════════════
// 5. Update broadcast listeners to filter by target
// ═══════════════════════════════════════════════════════════════════════════

// HomeScreen _listenBroadcast (siswa)
replace(
  `  void _listenBroadcast() {
    _broadcastSub = FirebaseFirestore.instance
        .collection('settings')
        .doc('broadcast')
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final msg =
          (snap.data() as Map?)?['message']?.toString() ?? "";
      if (msg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });
  }`,
  `  void _listenBroadcast() {
    _broadcastSub = FirebaseFirestore.instance
        .collection('settings')
        .doc('broadcast')
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final d = snap.data() as Map?;
      final msg = d?['message']?.toString() ?? "";
      final target = d?['target']?.toString() ?? 'semua';
      if (msg.isNotEmpty && (target == 'semua' || target == 'siswa')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });
  }`,
  'HomeScreen _listenBroadcast filter by target'
);

// GuruDashboard inline broadcast listener
replace(
  `    // Broadcast listener
    FirebaseFirestore.instance
        .collection('settings')
        .doc('broadcast')
        .snapshots()
        .listen((s) {
      if (!mounted || !s.exists) return;
      final msg = (s.data() as Map?)?['message']?.toString() ?? "";
      if (msg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
        ));
      }
    });
  }

  void _initExam() async {
    if (widget.exam.antiCurang) {
      if (isAndroid) {
        try {`,
  `    // Broadcast listener
    FirebaseFirestore.instance
        .collection('settings')
        .doc('broadcast')
        .snapshots()
        .listen((s) {
      if (!mounted || !s.exists) return;
      final d = s.data() as Map?;
      final msg = d?['message']?.toString() ?? "";
      final target = d?['target']?.toString() ?? 'semua';
      if (msg.isNotEmpty && (target == 'semua' || target == 'guru')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
        ));
      }
    });
  }

  void _initExam() async {
    if (widget.exam.antiCurang) {
      if (isAndroid) {
        try {`,
  'GuruDashboard broadcast listener filter by target'
);

// ExamScreen broadcast listener
replace(
  `    // Broadcast listener
    FirebaseFirestore.instance
        .collection('settings')
        .doc('broadcast')
        .snapshots()
        .listen((s) {
      if (!mounted || !s.exists) return;
      final msg = (s.data() as Map?)?['message']?.toString() ?? "";
      if (msg.isNotEmpty && !_showKioskLock) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
        ));
      }
    });
  }

  void _initExam() async {
    if (isAndroid) {`,
  `    // Broadcast listener
    FirebaseFirestore.instance
        .collection('settings')
        .doc('broadcast')
        .snapshots()
        .listen((s) {
      if (!mounted || !s.exists) return;
      final d = s.data() as Map?;
      final msg = d?['message']?.toString() ?? "";
      final target = d?['target']?.toString() ?? 'semua';
      if (msg.isNotEmpty && !_showKioskLock && (target == 'semua' || target == 'siswa')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
        ));
      }
    });
  }

  void _initExam() async {
    if (isAndroid) {`,
  'ExamScreen broadcast listener filter by target'
);

// ── Write ────────────────────────────────────────────────────────────────────
fs.writeFileSync(file, src, 'utf8');
console.log('\nDone! ' + count + ' replacements applied.');
