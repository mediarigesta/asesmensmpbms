part of '../main.dart';

// ============================================================
// DATA MODELS
// ============================================================
class UserAccount {
  final String id, kode, nama, username, password, role, ruang,
      statusMengerjakan, statusAktif, photo, liveFrame;
  final int battery;
  // Status per-ujian, disimpan sebagai map: { examId: { status, violationCount, ... } }
  final Map<String, dynamic> examStatus;

  UserAccount({
    required this.id,
    required this.kode,
    required this.nama,
    required this.username,
    required this.password,
    required this.role,
    required this.ruang,
    required this.statusMengerjakan,
    required this.statusAktif,
    required this.battery,
    required this.photo,
    required this.liveFrame,
    required this.examStatus,
  });

  factory UserAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAccount(
      id: doc.id,
      kode: data['kode']?.toString() ?? "",
      nama: data['nama'] ?? "",
      username: data['username'] ?? "",
      password: data['password']?.toString() ?? "",
      role: (data['role'] ?? "siswa").toString().toLowerCase(),
      ruang: data['ruang']?.toString() ?? "",
      statusMengerjakan: data['status_mengerjakan'] ?? "belum mulai",
      statusAktif: data['status_aktif'] ?? "aktif",
      battery: data['battery'] ?? 100,
      photo: data['photo'] ?? "",
      liveFrame: data['liveFrame'] ?? "",
      examStatus: Map<String, dynamic>.from(data['exam_status'] ?? const {}),
    );
  }

  /// Status khusus untuk 1 ujian. Jika belum ada, fallback ke status global.
  String statusForExam(String examId) {
    final raw = examStatus[examId];
    if (raw is Map && raw['status'] is String && (raw['status'] as String).isNotEmpty) {
      return raw['status'] as String;
    }
    return statusMengerjakan;
  }

  int violationForExam(String examId) {
    final raw = examStatus[examId];
    if (raw is Map && raw['violationCount'] is int) {
      return raw['violationCount'] as int;
    }
    return 0;
  }

  String get classFolder {
    final match = RegExp(r'^\d+[A-Za-z]+').stringMatch(kode);
    if (match != null) return match;
    final angka = RegExp(r'^\d+').stringMatch(kode);
    return angka ?? kode;
  }

  // Angka kelas saja: "7A01" -> "7"
  String get gradeNumber {
    final angka = RegExp(r'^\d+').stringMatch(kode);
    return angka ?? "";
  }

  // Cek apakah jenjang ujian cocok: "Kelas 7" cocok dengan kode "7A01", "07A", dll
  bool matchJenjang(String jenjang) {
    if (jenjang.isEmpty || kode.isEmpty) return false;
    // Ambil semua angka di depan kode siswa
    final g = gradeNumber;
    if (g.isEmpty) return false;
    // Normalisasi: hapus leading zero "07" -> "7"
    final gNorm = int.tryParse(g)?.toString() ?? g;
    // Cek apakah jenjang mengandung angka kelas siswa
    // "Kelas 7".contains("7") = true, tapi harus word-boundary
    // Gunakan regex agar "Kelas 7" tidak cocok dengan "Kelas 17"
    final pattern = RegExp(r'\b' + gNorm + r'\b');
    return pattern.hasMatch(jenjang) || jenjang.contains(gNorm);
  }

  String get initials {
    final parts = nama.trim().split(' ');
    if (parts.length >= 2) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : "?";
  }
}

class ExamData {
  final String id, judul, mapel, jenjang, link, instruksi;
  final DateTime waktuMulai, waktuSelesai;
  final bool antiCurang, kameraAktif, autoSubmit;
  final int maxCurang;
  final String status;
  final String mode;
  final DateTime? createdAt;
  final String kategori;
  final String creatorName;
  final List<String> targetKelas;
  final int kkm; // Kriteria Ketuntasan Minimal (0 = tidak aktif)
  final String spiType; // reguler, susulan, remedial
  final String? parentExamId; // ID ujian induk untuk susulan/remedial
  final bool isPaused; // Fitur Darurat: ujian dijeda

  ExamData({
    required this.id,
    required this.judul,
    required this.mapel,
    required this.jenjang,
    required this.link,
    required this.instruksi,
    required this.waktuMulai,
    required this.waktuSelesai,
    required this.antiCurang,
    required this.kameraAktif,
    required this.autoSubmit,
    required this.maxCurang,
    this.status = 'published',
    this.mode = 'form',
    this.createdAt,
    this.kategori = '',
    this.creatorName = '',
    this.targetKelas = const [],
    this.kkm = 0,
    this.spiType = 'reguler',
    this.parentExamId,
    this.isPaused = false,
  });

  factory ExamData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamData(
      id: doc.id,
      judul: data['judul'] ?? "",
      mapel: data['mapel'] ?? "",
      jenjang: data['jenjang'] ?? "",
      link: data['link'] ?? "",
      instruksi: data['instruksi'] ?? "",
      waktuMulai: (data['waktuMulai'] as Timestamp?)?.toDate() ?? DateTime.now(),
      waktuSelesai: (data['waktuSelesai'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 2)),
      antiCurang: data['antiCurang'] ?? true,
      kameraAktif: data['kameraAktif'] ?? true,
      autoSubmit: data['autoSubmit'] ?? true,
      maxCurang: data['maxCurang'] ?? 3,
      status: data['status'] ?? 'published',
      mode: data['mode'] ?? 'form',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      kategori: data['kategori'] ?? '',
      creatorName: data['creatorName'] ?? '',
      targetKelas: List<String>.from(data['targetKelas'] ?? []),
      kkm: data['kkm'] ?? 0,
      spiType: data['spiType'] ?? 'reguler',
      parentExamId: data['parentExamId'],
      isPaused: data['isPaused'] ?? false,
    );
  }

  bool get isDraft => status == 'draft';
  bool get isOngoing =>
      DateTime.now().isAfter(waktuMulai) && DateTime.now().isBefore(waktuSelesai);
  bool get sudahSelesai => DateTime.now().isAfter(waktuSelesai);
  bool get belumMulai => DateTime.now().isBefore(waktuMulai);

  Duration get sisaWaktu => waktuSelesai.difference(DateTime.now());
}

/// Helper: update status ujian per-siswa, per-ujian.
/// - Menyimpan status global `status_mengerjakan` (terakhir dikerjakan)
/// - Menyimpan juga di nested map `exam_status.<examId>.status` agar riwayat per-ujian tidak hilang.
Future<void> updateExamStatusForUser({
  required ExamData exam,
  required UserAccount user,
  required String status,
  int? violationCount,
  Map<String, dynamic>? extraFields,
}) async {
  final docRef = FirebaseFirestore.instance.collection('users').doc(user.id);
  final data = <String, dynamic>{
    'status_mengerjakan': status,
    'exam_status.${exam.id}.status': status,
    'exam_status.${exam.id}.updatedAt': FieldValue.serverTimestamp(),
  };
  if (violationCount != null) {
    data['exam_status.${exam.id}.violationCount'] = violationCount;
  }
  if (extraFields != null) {
    data.addAll(extraFields);
  }
  await docRef.update(data);
}
