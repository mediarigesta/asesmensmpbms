import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const firebaseOptions = FirebaseOptions(
    apiKey: "AIzaSyA5s6Tmpipn46IIzttpSNbeeVwTjo2jkp8",
    authDomain: "bm-exam.firebaseapp.com",
    projectId: "bm-exam",
    storageBucket: "bm-exam.firebasestorage.app",
    messagingSenderId: "671937779798",
    appId: "1:671937779798:web:e1fa8628d83839f2b643f7",
    measurementId: "G-6NQD3GXVXF",
  );
  try {
    if (kIsWeb) { await Firebase.initializeApp(options: firebaseOptions); }
    else { await Firebase.initializeApp(); }
  } catch (e) { debugPrint("Firebase Error: $e"); }

  if (!kIsWeb) {
    WebViewPlatform.instance = AndroidWebViewPlatform();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const BMExamApp());
}

// --- DATA MODELS ---
class UserAccount {
  final String id, kode, nama, username, password, role, ruang, statusMengerjakan, statusAktif, photo, liveFrame;
  final int battery;
  UserAccount({required this.id, required this.kode, required this.nama, required this.username, required this.password, required this.role, required this.ruang, required this.statusMengerjakan, required this.statusAktif, required this.battery, required this.photo, required this.liveFrame});

  factory UserAccount.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserAccount(
      id: doc.id, kode: data['kode']?.toString() ?? "",
      nama: data['nama'] ?? "", username: data['username'] ?? "",
      password: data['password']?.toString() ?? "",
      role: (data['role'] ?? "siswa").toString().toLowerCase(),
      ruang: data['ruang']?.toString() ?? "",
      statusMengerjakan: data['status_mengerjakan'] ?? "belum mulai",
      statusAktif: data['status_aktif'] ?? "aktif",
      battery: data['battery'] ?? 100,
      photo: data['photo'] ?? "",
      liveFrame: data['liveFrame'] ?? "",
    );
  }
  String get classFolder => RegExp(r'^\d+[A-Z]+').stringMatch(kode) ?? "Lainnya";
}

class ExamData {
  final String id, kode, namaMapel, kelas, link;
  final DateTime waktuMulai, waktuSelesai;
  ExamData({required this.id, required this.kode, required this.namaMapel, required this.kelas, required this.link, required this.waktuMulai, required this.waktuSelesai});
  factory ExamData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ExamData(
      id: doc.id, kode: data['kode'] ?? "",
      namaMapel: data['namaMapel'] ?? "",
      kelas: data['kelas']?.toString() ?? "",
      link: data['link'] ?? "",
      waktuMulai: (data['waktuMulai'] as Timestamp?)?.toDate() ?? DateTime.now(),
      waktuSelesai: (data['waktuSelesai'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 2)),
    );
  }
  bool get isOngoing => DateTime.now().isAfter(waktuMulai) && DateTime.now().isBefore(waktuSelesai);
}

class BMExamApp extends StatelessWidget {
  const BMExamApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'BM-Exam Pro',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A))),
    home: const SplashScreen(),
  );
}

// --- DASHBOARD GURU ---
class GuruDashboard extends StatefulWidget {
  final UserAccount guru;
  const GuruDashboard({super.key, required this.guru});
  @override State<GuruDashboard> createState() => _GuruDashboardState();
}
class _GuruDashboardState extends State<GuruDashboard> {
  int _tabIndex = 0; String? _selectedRuang;
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1F5F9),
    body: Row(children: [
      NavigationRail(
        selectedIndex: _tabIndex, onDestinationSelected: (i) => setState(() => _tabIndex = i),
        labelType: NavigationRailLabelType.all, backgroundColor: const Color(0xFF0F172A),
        unselectedIconTheme: const IconThemeData(color: Colors.white60), selectedIconTheme: const IconThemeData(color: Colors.white),
        destinations: const [
          NavigationRailDestination(icon: Icon(Icons.group_work_rounded), label: Text('Pantauan')),
          NavigationRailDestination(icon: Icon(Icons.campaign_rounded), label: Text('Pesan')),
        ],
      ),
      Expanded(child: Column(children: [
        Container(padding: const EdgeInsets.all(20), color: Colors.white, child: Row(children: [Text(_selectedRuang == null ? "Guru: ${widget.guru.nama}" : "Monitoring Ruang $_selectedRuang", style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())))])) ,
        Expanded(child: _tabIndex == 0 ? (_selectedRuang == null ? _buildRoomSelector() : _buildStudentGrid()) : _buildBroadcastView()),
      ])),
    ]),
  );
  Widget _buildRoomSelector() => FutureBuilder<QuerySnapshot>(future: FirebaseFirestore.instance.collection('users').get(), builder: (context, snap) {
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final rooms = snap.data!.docs.map((d) => d['ruang']?.toString() ?? "").toSet().toList()..removeWhere((r) => r.isEmpty)..sort((a,b) {
      int getInt(String s) => int.tryParse(RegExp(r'\d+').stringMatch(s) ?? '0') ?? 0;
      return getInt(a).compareTo(getInt(b));
    });
    return ListView(padding: const EdgeInsets.all(20), children: rooms.map((r) => Card(child: ListTile(title: Text("Ruang $r"), trailing: const Icon(Icons.chevron_right), onTap: () => setState(() => _selectedRuang = r)))).toList());
  });
  Widget _buildStudentGrid() => Column(children: [ListTile(tileColor: Colors.blue.withValues(alpha: 0.1), leading: const Icon(Icons.arrow_back), title: const Text("Kembali"), onTap: () => setState(() => _selectedRuang = null)), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').where('ruang', isEqualTo: _selectedRuang).where('role', isEqualTo: 'siswa').snapshots(), builder: (context, snap) {
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final siswa = snap.data!.docs.map((d) => UserAccount.fromFirestore(d)).toList();
    return GridView.builder(padding: const EdgeInsets.all(15), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8), itemCount: siswa.length, itemBuilder: (c, i) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(children: [Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), child: siswa[i].liveFrame.isEmpty ? const Icon(Icons.videocam_off) : Image.memory(base64Decode(siswa[i].liveFrame), fit: BoxFit.cover, width: double.infinity))), Padding(padding: const EdgeInsets.all(10), child: Column(children: [Text(siswa[i].nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), overflow: TextOverflow.ellipsis), Text(siswa[i].statusMengerjakan.toUpperCase(), style: TextStyle(fontSize: 8, color: siswa[i].statusMengerjakan == 'melanggar' ? Colors.red : Colors.blue))]))])));
  }))]);
  Widget _buildBroadcastView() => StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('settings').doc('broadcast').snapshots(), builder: (c, snap) => Center(child: Card(margin: const EdgeInsets.all(40), child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.campaign, size: 50, color: Colors.red), const SizedBox(height: 20), Text(snap.hasData ? snap.data!['message'] : "Tidak ada pesan", textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))])))));
}

// --- ADMIN 1 DASHBOARD ---
class Admin1Dashboard extends StatefulWidget {
  final UserAccount admin;
  const Admin1Dashboard({super.key, required this.admin});
  @override State<Admin1Dashboard> createState() => _Admin1DashboardState();
}
class _Admin1DashboardState extends State<Admin1Dashboard> {
  int _tabIndex = 0; String _search = ""; String _filter = "semua";
  final _msgCtrl = TextEditingController();

  void _massStatus(bool active) async {
    final snap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'siswa').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var d in snap.docs) { batch.update(d.reference, {'status_aktif': active ? 'aktif' : 'terblokir'}); }
    await batch.commit();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(active ? "Semua Siswa Diaktifkan" : "Semua Siswa Diblokir")));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(children: [
        NavigationRail(
          selectedIndex: _tabIndex, onDestinationSelected: (i) => setState(() => _tabIndex = i),
          labelType: NavigationRailLabelType.all, backgroundColor: const Color(0xFF0F172A),
          unselectedIconTheme: const IconThemeData(color: Colors.white60), selectedIconTheme: const IconThemeData(color: Colors.white),
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.dashboard_rounded), label: Text('Statistik')),
            NavigationRailDestination(icon: Icon(Icons.videocam_rounded), label: Text('Live')),
            NavigationRailDestination(icon: Icon(Icons.campaign_rounded), label: Text('Broadcast')),
            NavigationRailDestination(icon: Icon(Icons.groups_rounded), label: Text('Siswa')),
            NavigationRailDestination(icon: Icon(Icons.settings_suggest_rounded), label: Text('Pengaturan')),
          ],
        ),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final users = snap.data!.docs.map((d) => UserAccount.fromFirestore(d)).toList();
            return Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20), color: Colors.white, child: Row(children: [Text("Admin: ${widget.admin.nama}", style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())))])) ,
              Expanded(child: _buildTab(users)),
            ]);
          },
        )),
      ]),
    );
  }

  Widget _buildTab(List<UserAccount> users) {
    switch (_tabIndex) {
      case 0: return _buildPerformance(users);
      case 1: return _buildLive(users.where((u) => u.role == 'siswa').toList());
      case 2: return _buildBroadcastPanel();
      case 3: return _buildStudentList(users);
      default: return _buildSettingsView(users);
    }
  }

  Widget _buildPerformance(List<UserAccount> users) {
    final siswa = users.where((u) => u.role == 'siswa').toList();
    int mng = siswa.where((s) => s.statusMengerjakan == 'mengerjakan').length;
    int mlg = siswa.where((s) => s.statusMengerjakan == 'melanggar').length;
    int sls = siswa.where((s) => s.statusMengerjakan == 'selesai').length;
    return SingleChildScrollView(padding: const EdgeInsets.all(25), child: Column(children: [
      Wrap(spacing: 20, runSpacing: 20, children: [
        _proStat("Total Siswa", siswa.length.toString(), Icons.people, Colors.blue),
        _proStat("Pengerjaan", mng.toString(), Icons.play_arrow, Colors.indigo),
        _proStat("Pelanggaran", mlg.toString(), Icons.warning, Colors.red),
        _proStat("Selesai", sls.toString(), Icons.check_circle, Colors.green),
      ]),
      const SizedBox(height: 30),
      Row(children: [_proPie(mng, mlg, sls, siswa.length - (mng+mlg+sls)), const SizedBox(width: 30), Expanded(child: _proTokenPanel())]),
    ]));
  }

  Widget _buildStudentList(List<UserAccount> users) {
    final siswa = users.where((u) => u.role == 'siswa').toList();
    final filt = siswa.where((s) {
      bool search = s.nama.toLowerCase().contains(_search.toLowerCase());
      bool filter = true;
      if (_filter == "aktif") filter = s.statusAktif == 'aktif';
      else if (_filter == "terblokir") filter = s.statusAktif == 'terblokir';
      else if (_filter == "belum mulai") filter = s.statusMengerjakan == 'belum mulai';
      else if (_filter == "sedang mengerjakan") filter = s.statusMengerjakan == 'mengerjakan';
      else if (_filter == "selesai") filter = s.statusMengerjakan == 'selesai';
      else if (_filter == "pelanggaran") filter = s.statusMengerjakan == 'melanggar';
      return search && filter;
    }).toList();
    Map<String, List<UserAccount>> grp = {};
    for (var s in filt) { grp.putIfAbsent(s.classFolder, () => []).add(s); }
    var keys = grp.keys.toList()..sort();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(15), child: Row(children: [
        Expanded(child: TextField(decoration: InputDecoration(hintText: "Cari nama siswa...", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)), onChanged: (v) => setState(() => _search = v))),
        const SizedBox(width: 10),
        DropdownButton<String>(value: _filter, items: const [DropdownMenuItem(value: "semua", child: Text("Semua")), DropdownMenuItem(value: "aktif", child: Text("Aktif")), DropdownMenuItem(value: "terblokir", child: Text("Terblokir")), DropdownMenuItem(value: "belum mulai", child: Text("Belum Mulai")), DropdownMenuItem(value: "sedang mengerjakan", child: Text("Ujian")), DropdownMenuItem(value: "selesai", child: Text("Selesai")), DropdownMenuItem(value: "pelanggaran", child: Text("Pelanggaran"))], onChanged: (v) => setState(() => _filter = v!)),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: Row(children: [
        ElevatedButton.icon(icon: const Icon(Icons.check_circle), label: const Text("AKTIFKAN SEMUA"), onPressed: () => _massStatus(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white)),
        const SizedBox(width: 10),
        ElevatedButton.icon(icon: const Icon(Icons.block), label: const Text("BLOKIR SEMUA"), onPressed: () => _massStatus(false), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white)),
      ])),
      Expanded(child: ListView.builder(itemCount: keys.length, itemBuilder: (c, i) => Card(margin: const EdgeInsets.all(15), child: ExpansionTile(title: Text("Kelas ${keys[i]}", style: const TextStyle(fontWeight: FontWeight.bold)), children: grp[keys[i]]!.map((s) => ListTile(leading: s.photo.isEmpty ? const CircleAvatar(child: Icon(Icons.person)) : CircleAvatar(backgroundImage: MemoryImage(base64Decode(s.photo))), title: Text(s.nama), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Switch(value: s.statusAktif == 'aktif', activeColor: const Color(0xFF1A237E), onChanged: (v) => FirebaseFirestore.instance.collection('users').doc(s.id).update({'status_aktif': v ? 'aktif' : 'terblokir'})), IconButton(icon: const Icon(Icons.edit_note_rounded), onPressed: () => _editRole(s))]))).toList())))),
    ]);
  }

  Widget _proStat(String t, String v, IconData i, Color c) => Container(width: 170, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i, color: c), const SizedBox(height: 10), Text(t, style: const TextStyle(color: Colors.grey, fontSize: 11)), Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]));
  Widget _proPie(int m, int l, int s, int b) => Container(width: 300, height: 300, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: PieChart(PieChartData(sections: [PieChartSectionData(color: Colors.indigo, value: m.toDouble(), title: "Ujian", radius: 45), PieChartSectionData(color: Colors.red, value: l.toDouble(), title: "Lapor", radius: 45), PieChartSectionData(color: Colors.green, value: s.toDouble(), title: "Beres", radius: 45), PieChartSectionData(color: Colors.grey, value: b.toDouble(), title: "Siap", radius: 45)])));
  Widget _proTokenPanel() => Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]), borderRadius: BorderRadius.circular(25)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("TOKEN SESI", style: TextStyle(color: Colors.white60, letterSpacing: 2)), StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('settings').doc('exam_token').snapshots(), builder: (c, snap) { String token = snap.hasData ? snap.data!['current_token'] : "---"; return Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(token, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 10)), IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent, size: 30), onPressed: () => FirebaseFirestore.instance.collection('settings').doc('exam_token').update({'current_token': (Random().nextInt(900000)+100000).toString()}))]); })]));

  Widget _buildLive(List<UserAccount> s) => GridView.builder(padding: const EdgeInsets.all(20), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: s.length, itemBuilder: (c, i) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Column(children: [Expanded(child: s[i].liveFrame.isEmpty ? const Icon(Icons.videocam_off) : Image.memory(base64Decode(s[i].liveFrame), fit: BoxFit.cover)), Text(s[i].nama, style: const TextStyle(fontSize: 8))])));
  Widget _buildBroadcastPanel() => Padding(padding: const EdgeInsets.all(40), child: Column(children: [TextField(controller: _msgCtrl, maxLines: 4, decoration: const InputDecoration(labelText: "Ketik Pesan Broadcast", border: OutlineInputBorder())), const SizedBox(height: 20), ElevatedButton(onPressed: () => FirebaseFirestore.instance.collection('settings').doc('broadcast').set({'message': _msgCtrl.text, 'timestamp': FieldValue.serverTimestamp()}), child: const Text("KIRIM PESAN"))]));
  Widget _buildSettingsView(List<UserAccount> u) { final p = TextEditingController(); return SingleChildScrollView(padding: const EdgeInsets.all(30), child: Column(children: [Card(child: ListTile(title: const Text("PIN Buka Kunci"), subtitle: TextField(controller: p), trailing: ElevatedButton(onPressed: () => FirebaseFirestore.instance.collection('settings').doc('app_config').update({'proctor_password': p.text}), child: const Text("Simpan")))), ...u.where((x) => x.role != 'siswa').map((x) => ListTile(title: Text(x.nama), subtitle: Text(x.role.toUpperCase()), trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _editRole(x))))])); }
  void _editRole(UserAccount u) { String r = u.role; showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(u.nama), content: DropdownButtonFormField<String>(value: r, items: const [DropdownMenuItem(value: "siswa", child: Text("SISWA")), DropdownMenuItem(value: "guru", child: Text("GURU")), DropdownMenuItem(value: "admin1", child: Text("ADMIN 1"))], onChanged: (v) => r = v!), actions: [ElevatedButton(onPressed: () { FirebaseFirestore.instance.collection('users').doc(u.id).update({'role': r}); Navigator.pop(ctx); }, child: const Text("SIMPAN"))])); }
}

// --- HOME SISWA ---
class HomeScreen extends StatefulWidget { final UserAccount user; const HomeScreen({super.key, required this.user}); @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> { final _t = TextEditingController(); ExamData? _ex; bool _l = true; CameraController? _c; @override void initState() { super.initState(); _f(); _i(); } void _f() async { final s = await FirebaseFirestore.instance.collection('exam').get(); final list = s.docs.map((d) => ExamData.fromFirestore(d)).toList(); if(mounted) setState(() { try { _ex = list.firstWhere((e) => e.isOngoing); } catch(_) { _ex = null; } _l = false; }); } void _i() async { if(kIsWeb) return; final cams = await availableCameras(); _c = CameraController(cams.firstWhere((x) => x.lensDirection == CameraLensDirection.front), ResolutionPreset.low); await _c!.initialize(); } @override Widget build(BuildContext context) => Scaffold(body: _l ? const Center(child: CircularProgressIndicator()) : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.school, size: 80, color: Color(0xFF0F172A)), Text("Halo, ${widget.user.nama}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), if(_ex != null) ...[const SizedBox(height: 30), Text(_ex!.namaMapel, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 20), SizedBox(width: 250, child: TextField(controller: _t, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Masukkan Token"))), const SizedBox(height: 30), ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(250, 60), backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white), onPressed: () async { final ts = await FirebaseFirestore.instance.collection('settings').doc('exam_token').get(); if(ts.exists && _t.text.trim() == ts['current_token']) { if(!kIsWeb) { final img = await _c!.takePicture(); await FirebaseFirestore.instance.collection('users').doc(widget.user.id).update({'photo': base64Encode(await img.readAsBytes())}); } if(mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ExamScreen(exam: _ex!, user: widget.user))); } }, child: const Text("MULAI UJIAN"))]]))); }

// --- EXAM SCREEN ---
class ExamScreen extends StatefulWidget { final ExamData exam; final UserAccount user; const ExamScreen({super.key, required this.exam, required this.user}); @override State<ExamScreen> createState() => _ExamScreenState(); }
class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver { late final WebViewController _c; int _b = 100; bool _f = false; int _cl = 0; @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _in(); if(!kIsWeb) { _c = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadRequest(Uri.parse(widget.exam.link))..setNavigationDelegate(NavigationDelegate(onPageFinished: (u) { if(u.contains("formResponse")) _auto(); })); } FirebaseFirestore.instance.collection('settings').doc('broadcast').snapshots().listen((s) { if(s.exists && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s['message']), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)); }); Timer.periodic(const Duration(seconds: 15), (t) async { if(_f) return; int lv = 100; if(!kIsWeb) lv = await Battery().batteryLevel; FirebaseFirestore.instance.collection('users').doc(widget.user.id).update({'battery': lv}); if(mounted) setState(() => _b = lv); }); } void _in() async { if(!kIsWeb) await startKioskMode(); FirebaseFirestore.instance.collection('users').doc(widget.user.id).update({'status_mengerjakan': 'mengerjakan'}); } void _auto() async { _f = true; if(!kIsWeb) await stopKioskMode(); FirebaseFirestore.instance.collection('users').doc(widget.user.id).update({'status_mengerjakan': 'selesai'}); if (mounted) Navigator.pop(context); } @override void didChangeAppLifecycleState(AppLifecycleState s) { if(!_f && s == AppLifecycleState.paused) Navigator.push(context, MaterialPageRoute(builder: (_) => LockScreen(user: widget.user))); } @override Widget build(BuildContext context) => PopScope(canPop: false, child: Scaffold(body: Stack(children: [ kIsWeb ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Ujian sedang berlangsung..."), const SizedBox(height: 20), ElevatedButton(onPressed: () => launchUrl(Uri.parse(widget.exam.link)), child: const Text("Klik untuk buka Soal (Baru)"))])) : WebViewWidget(controller: _c), Positioned(top: 40, right: 20, child: GestureDetector(onTap: () { _cl++; if(_cl >= 5) { _cl = 0; _show(); } }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)), child: Text("$_b%", style: const TextStyle(color: Colors.white, fontSize: 10)))))]))); void _show() { final ct = TextEditingController(); showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("PIN Proktor"), content: TextField(controller: ct, obscureText: true), actions: [ElevatedButton(onPressed: () async { final d = await FirebaseFirestore.instance.collection('settings').doc('app_config').get(); if(ct.text == d.data()?['proctor_password']) { _f = true; if(!kIsWeb) await stopKioskMode(); Navigator.pop(ctx); Navigator.pop(context); } }, child: const Text("KELUAR"))])); } }

class LockScreen extends StatefulWidget { final UserAccount user; const LockScreen({super.key, required this.user}); @override State<LockScreen> createState() => _LockScreenState(); }
class _LockScreenState extends State<LockScreen> { final _p = TextEditingController(); @override void initState() { super.initState(); FirebaseFirestore.instance.collection('users').doc(widget.user.id).update({'status_mengerjakan': 'melanggar'}); } @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.red.shade900, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.lock, size: 50, color: Colors.white), const Text("TERKUNCI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), SizedBox(width: 250, child: TextField(controller: _p, decoration: const InputDecoration(labelText: "Masukkan PIN", filled: true, fillColor: Colors.white))), ElevatedButton(onPressed: () async { final d = await FirebaseFirestore.instance.collection('settings').doc('app_config').get(); if(_p.text == d.data()?['proctor_password']) Navigator.pop(context); }, child: const Text("BUKA"))]))); }
class SplashScreen extends StatefulWidget { const SplashScreen({super.key}); @override State<SplashScreen> createState() => _SplashScreenState(); }
class _SplashScreenState extends State<SplashScreen> { @override void initState() { super.initState(); Future.delayed(const Duration(seconds: 2), () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))); } @override Widget build(BuildContext context) => const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator(color: Colors.white))); }
class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final _u = TextEditingController(); final _p = TextEditingController();
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.school, size: 80, color: Color(0xFF0F172A)), const SizedBox(height: 30), SizedBox(width: 300, child: TextField(controller: _u, decoration: const InputDecoration(labelText: "Nama Pengguna", border: OutlineInputBorder()))), const SizedBox(height: 15), SizedBox(width: 300, child: TextField(controller: _p, obscureText: true, decoration: const InputDecoration(labelText: "Kata Sandi", border: OutlineInputBorder()))), const SizedBox(height: 30), ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(300, 60), backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white), onPressed: () async {
    final snap = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: _u.text.trim()).where('password', isEqualTo: _p.text.trim()).get();
    if (snap.docs.isNotEmpty) {
      final u = UserAccount.fromFirestore(snap.docs.first);
      if (u.statusAktif == 'terblokir') { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Akun Terblokir!"))); }
      else { if (mounted) { if (u.role == 'admin1') Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Admin1Dashboard(admin: u))); else if (u.role == 'guru') Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GuruDashboard(guru: u))); else Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(user: u))); } }
    } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login Gagal!"))); }
  }, child: const Text("MASUK"))])));
}