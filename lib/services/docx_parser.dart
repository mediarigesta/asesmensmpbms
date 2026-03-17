part of '../main.dart';

// ============================================================
// DOCX PARSER UTILITY
// ============================================================
class DocxParser {
  /// Parse file .docx bytes → list SoalModel
  /// Mendukung automatic numbering Word (decimal=nomor soal, upperLetter=pilihan A/B/C/D)
  static List<SoalModel> parse(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final xmlFile = archive.findFile('word/document.xml');
      if (xmlFile == null) return [];
      final xml = utf8.decode(xmlFile.content as List<int>);

      // Baca numbering.xml untuk deteksi format list otomatis Word
      final numMap = <String, String>{}; // numId -> format
      final numFile = archive.findFile('word/numbering.xml');
      if (numFile != null) {
        final numXml = utf8.decode(numFile.content as List<int>);
        numMap.addAll(_parseNumberingMap(numXml));
      }

      final paragraphs = _extractParagraphs(xml, numMap);
      return _parseParagraphs(paragraphs);
    } catch (e) {
      debugPrint('DocxParser error: $e');
      return [];
    }
  }

  // Bangun map: numId -> format ('decimal', 'upperLetter', dll)
  static Map<String, String> _parseNumberingMap(String numXml) {
    final result = <String, String>{};
    final abstractFmt = <String, String>{};
    final absReg = RegExp(r'<w:abstractNum w:abstractNumId="(\d+)".*?</w:abstractNum>', dotAll: true);
    for (final m in absReg.allMatches(numXml)) {
      final absId = m.group(1)!;
      final fmtMatch = RegExp(r'<w:numFmt w:val="([^"]+)"').firstMatch(m.group(0)!);
      if (fmtMatch != null) abstractFmt[absId] = fmtMatch.group(1)!;
    }
    final numReg = RegExp(r'<w:num w:numId="(\d+)"[^>]*>.*?<w:abstractNumId w:val="(\d+)"', dotAll: true);
    for (final m in numReg.allMatches(numXml)) {
      result[m.group(1)!] = abstractFmt[m.group(2)!] ?? 'none';
    }
    return result;
  }

  // Extract paragraf dengan info: teks, numId, format list
  static List<Map<String, String>> _extractParagraphs(String xml, Map<String, String> numMap) {
    final result = <Map<String, String>>[];
    final paraReg = RegExp(r'<w:p[ >].*?</w:p>', dotAll: true);
    for (final m in paraReg.allMatches(xml)) {
      final p = m.group(0)!;
      final tReg = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
      final textBuf = StringBuffer();
      for (final t in tReg.allMatches(p)) textBuf.write(t.group(1) ?? '');
      final text = textBuf.toString().trim();
      if (text.isEmpty) continue;
      final numIdMatch = RegExp(r'<w:numId w:val="(\d+)"').firstMatch(p);
      final numId = numIdMatch?.group(1);
      final fmt = numId != null ? (numMap[numId] ?? 'none') : 'none';
      result.add({'text': text, 'numId': numId ?? '', 'fmt': fmt});
    }
    return result;
  }

  static List<SoalModel> _parseParagraphs(List<Map<String, String>> paragraphs) {
    final soals = <SoalModel>[];
    TipeSoal? currentTipe;
    int? nomor;
    String? pertanyaan;
    List<String> pilihan = [];
    String kunci = '';
    int skor = 1;
    int counter = 0;
    int pilihanCounter = 0;

    void flush() {
      if (currentTipe != null && pertanyaan != null && pertanyaan!.isNotEmpty) {
        counter++;
        soals.add(SoalModel(
          id: 'draft_$counter',
          nomor: nomor ?? counter,
          tipe: currentTipe!,
          pertanyaan: pertanyaan!,
          pilihan: List.from(pilihan),
          kunciJawaban: kunci.toUpperCase(),
          skor: skor,
        ));
      }
      nomor = null; pertanyaan = null; pilihan = []; kunci = ''; skor = 1; pilihanCounter = 0;
    }

    for (final para in paragraphs) {
      final text = para['text']!;
      final fmt = para['fmt']!;

      // Section header
      if (text.contains('[PILIHAN GANDA]')) { flush(); currentTipe = TipeSoal.pilihanGanda; continue; }
      if (text.contains('[BENAR SALAH]')) { flush(); currentTipe = TipeSoal.benarSalah; continue; }
      if (text.contains('[URAIAN]')) { flush(); currentTipe = TipeSoal.uraian; continue; }
      if (currentTipe == null) continue;

      if (text.startsWith('JAWABAN:')) { kunci = text.replaceFirst('JAWABAN:', '').trim(); continue; }
      if (text.startsWith('SKOR:')) { skor = int.tryParse(text.replaceFirst('SKOR:', '').trim()) ?? 1; continue; }

      // Nomor soal: automatic decimal list
      if (fmt == 'decimal') {
        flush();
        nomor = (soals.length) + 1;
        pertanyaan = text;
        continue;
      }
      // Nomor soal: manual "1. teks"
      final nomorManualMatch = RegExp(r'^(\d+)\.\s+(.+)').firstMatch(text);
      if (nomorManualMatch != null) {
        flush();
        nomor = int.tryParse(nomorManualMatch.group(1)!);
        pertanyaan = nomorManualMatch.group(2)!;
        continue;
      }

      // Pilihan jawaban: automatic upperLetter/lowerLetter list
      if ((fmt == 'upperLetter' || fmt == 'lowerLetter') &&
          currentTipe == TipeSoal.pilihanGanda && pertanyaan != null) {
        final letter = String.fromCharCode(65 + pilihanCounter);
        pilihan.add('$letter. $text');
        pilihanCounter++;
        continue;
      }
      // Pilihan jawaban: manual "A. teks"
      final pilihanManualMatch = RegExp(r'^([A-Da-d])\.\s+(.+)').firstMatch(text);
      if (pilihanManualMatch != null && currentTipe == TipeSoal.pilihanGanda) {
        pilihan.add('${pilihanManualMatch.group(1)!.toUpperCase()}. ${pilihanManualMatch.group(2)!}');
        continue;
      }

      // Lanjutan pertanyaan multi-line
      if (pertanyaan != null) pertanyaan = '$pertanyaan $text';
    }
    flush();
    return soals;
  }
}


