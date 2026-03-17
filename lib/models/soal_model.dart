part of '../main.dart';

// ============================================================
// MODEL SOAL
// ============================================================
enum TipeSoal { pilihanGanda, benarSalah, uraian }

class SoalModel {
  final String id;
  final int nomor;
  final TipeSoal tipe;
  final String pertanyaan;
  final String gambar; // base64 gambar soal (kosong jika tidak ada)
  final List<String> pilihan; // ["A. ...", "B. ..."] untuk PG
  final String kunciJawaban;  // "A"/"B"/.. | "BENAR"/"SALAH" | kosong uraian
  final int skor;

  SoalModel({
    required this.id,
    required this.nomor,
    required this.tipe,
    required this.pertanyaan,
    this.gambar = '',
    required this.pilihan,
    required this.kunciJawaban,
    required this.skor,
  });

  Map<String, dynamic> toMap() => {
    'nomor': nomor,
    'tipe': tipe.name,
    'pertanyaan': pertanyaan,
    'gambar': gambar,
    'pilihan': pilihan,
    'kunciJawaban': kunciJawaban,
    'skor': skor,
  };

  factory SoalModel.fromMap(Map<String, dynamic> d, String id) {
    TipeSoal t;
    switch (d['tipe']) {
      case 'pilihanGanda': t = TipeSoal.pilihanGanda; break;
      case 'benarSalah': t = TipeSoal.benarSalah; break;
      default: t = TipeSoal.uraian;
    }
    return SoalModel(
      id: id,
      nomor: d['nomor'] ?? 0,
      tipe: t,
      pertanyaan: d['pertanyaan'] ?? '',
      gambar: d['gambar'] ?? '',
      pilihan: List<String>.from(d['pilihan'] ?? []),
      kunciJawaban: d['kunciJawaban'] ?? '',
      skor: d['skor'] ?? 1,
    );
  }
}

// ============================================================
// SOAL MANUAL EDITOR — Buat soal langsung di app
// ============================================================

// Model soal draft untuk editor
class SoalDraft {
  TipeSoal tipe;
  String pertanyaan;
  String? gambarBase64; // base64 gambar soal
  List<String> pilihan; // untuk PG: ["Teks A", "Teks B", ...]
  String kunciJawaban;
  int skor;

  SoalDraft({
    this.tipe = TipeSoal.pilihanGanda,
    this.pertanyaan = '',
    this.gambarBase64,
    List<String>? pilihan,
    this.kunciJawaban = '',
    this.skor = 1,
  }) : pilihan = pilihan ?? ['', '', '', ''];

  SoalDraft copy() => SoalDraft(
    tipe: tipe,
    pertanyaan: pertanyaan,
    gambarBase64: gambarBase64,
    pilihan: List.from(pilihan),
    kunciJawaban: kunciJawaban,
    skor: skor,
  );
}
