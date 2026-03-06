class GroqAiParser {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model    = 'llama-3.3-70b-versatile';

  /// Ekstrak teks terstruktur dari .docx dengan penanda khusus:
  /// - [JAWABAN] di awal baris = teks berwarna merah (kunci jawaban)
  /// - [GAMBAR_N] = posisi gambar ke-N
  /// - [EQ: ...] = persamaan matematika (OMML)
  /// - ^{...} / _{...} = superscript / subscript inline
  static ({String text, Map<String, String> images})
      extractStructured(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // ── Baca relasi gambar dari word/_rels/document.xml.rels ──────
      final rIdToBase64 = <String, String>{};
      final relsFile = archive.findFile('word/_rels/document.xml.rels');
      if (relsFile != null) {
        final relsXml = utf8.decode(relsFile.content as List<int>);
        final relReg  = RegExp(
          r'<Relationship[^>]+Id="([^"]+)"[^>]+Type="[^"]*image[^"]*"[^>]+Target="([^"]+)"',
        );
        for (final m in relReg.allMatches(relsXml)) {
          final rId    = m.group(1)!;
          final target = m.group(2)!;
          final imgFile = archive.findFile('word/$target');
          if (imgFile != null) {
            rIdToBase64[rId] = base64Encode(imgFile.content as List<int>);
          }
        }
      }

      // ── Parse paragraf dokumen ─────────────────────────────────────
      final xmlFile = archive.findFile('word/document.xml');
      if (xmlFile == null) return (text: '', images: {});
      final xml = utf8.decode(xmlFile.content as List<int>);

      final paraReg  = RegExp(r'<w:p[ >].*?</w:p>', dotAll: true);
      final runReg   = RegExp(r'<w:r[ >].*?</w:r>', dotAll: true);
      final tReg     = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
      final embedReg = RegExp(r'r:embed="([^"]+)"');

      final buf       = StringBuffer();
      final namedImgs = <String, String>{}; // 'GAMBAR_1' → base64
      int   imgCount  = 0;

      for (final para in paraReg.allMatches(xml)) {
        final pXml    = para.group(0)!;
        final lineBuf = StringBuffer();
        bool  hasRed  = false;

        // ── Gambar ────────────────────────────────────────────────
        if (pXml.contains('r:embed=')) {
          for (final em in embedReg.allMatches(pXml)) {
            final rId = em.group(1)!;
            if (rIdToBase64.containsKey(rId)) {
              imgCount++;
              final key = 'GAMBAR_$imgCount';
              namedImgs[key] = rIdToBase64[rId]!;
              lineBuf.write('[$key] ');
              break; // satu gambar per paragraf
            }
          }
        }

        // ── Persamaan OMML ────────────────────────────────────────
        if (pXml.contains('<m:oMath')) {
          final oMathReg =
              RegExp(r'<m:oMath[ >].*?</m:oMath>', dotAll: true);
          for (final eq in oMathReg.allMatches(pXml)) {
            final eqText = _ommlToText(eq.group(0)!);
            if (eqText.isNotEmpty) lineBuf.write('[EQ: $eqText] ');
          }
        }

        // ── Teks per run (deteksi warna merah + super/subscript) ──
        for (final run in runReg.allMatches(pXml)) {
          final rXml = run.group(0)!;

          // Warna merah: FF0000, C00000, dll (pilihan yang merupakan jawaban)
          if (!hasRed &&
              RegExp(r'<w:color w:val="(?:FF|ff|C0|c0)[0-9A-Fa-f]{4}"')
                  .hasMatch(rXml)) {
            hasRed = true;
          }

          final isSup = rXml.contains('w:val="superscript"');
          final isSub = rXml.contains('w:val="subscript"');

          for (final t in tReg.allMatches(rXml)) {
            final txt = t.group(1) ?? '';
            if (txt.isEmpty) continue;
            if (isSup)      lineBuf.write('^{$txt}');
            else if (isSub) lineBuf.write('_{$txt}');
            else            lineBuf.write(txt);
          }
        }

        String line = lineBuf.toString().trim();
        if (line.isEmpty) continue;
        if (hasRed) line = '[JAWABAN] $line';
        buf.writeln(line);
      }

      return (text: buf.toString(), images: namedImgs);
    } catch (_) {
      return (text: '', images: {});
    }
  }

  /// Konversi OMML XML ke teks yang readable oleh LLM
  static String _ommlToText(String xml) {
    // Superscript: base^{sup}
    final sSupReg = RegExp(
        r'<m:sSup>.*?<m:e>(.*?)</m:e>.*?<m:sup>(.*?)</m:sup>.*?</m:sSup>',
        dotAll: true);
    // Subscript: base_{sub}
    final sSubReg = RegExp(
        r'<m:sSub>.*?<m:e>(.*?)</m:e>.*?<m:sub>(.*?)</m:sub>.*?</m:sSub>',
        dotAll: true);
    // Fraction: (num)/(den)
    final fracReg = RegExp(
        r'<m:f>.*?<m:num>(.*?)</m:num>.*?<m:den>(.*?)</m:den>.*?</m:f>',
        dotAll: true);
    // Radical: sqrt(...)
    final radReg = RegExp(r'<m:rad>.*?<m:e>(.*?)</m:e>.*?</m:rad>',
        dotAll: true);

    String s = xml;
    s = s.replaceAllMapped(fracReg, (m) =>
        '(${_mText(m.group(1)!)})/(${_mText(m.group(2)!)})');
    s = s.replaceAllMapped(radReg,  (m) =>
        'sqrt(${_mText(m.group(1)!)})');
    s = s.replaceAllMapped(sSupReg, (m) =>
        '${_mText(m.group(1)!)}^{${_mText(m.group(2)!)}}');
    s = s.replaceAllMapped(sSubReg, (m) =>
        '${_mText(m.group(1)!)}_{${_mText(m.group(2)!)}}');

    // Sisa: ambil semua <m:t>
    final mTReg = RegExp(r'<m:t[^>]*>(.*?)</m:t>', dotAll: true);
    return mTReg.allMatches(s).map((m) => m.group(1) ?? '').join().trim();
  }

  static String _mText(String xml) {
    final r = RegExp(r'<m:t[^>]*>(.*?)</m:t>', dotAll: true);
    return r.allMatches(xml).map((m) => m.group(1) ?? '').join().trim();
  }

  /// Kirim teks ke Groq AI, kembalikan List<SoalDraft>
  static Future<List<SoalDraft>> parse(
    String text, Map<String, String> images, String apiKey) async {
    final prompt =
      'Kamu adalah asisten yang mengekstrak soal ujian dari dokumen sekolah Indonesia. '
      'Ekstrak SEMUA soal dari teks berikut.\n'
      'Kembalikan HANYA JSON valid, tanpa markdown, tanpa komentar.\n\n'
      'PENANDA KHUSUS dalam teks:\n'
      '- [JAWABAN] di awal baris = pilihan itu adalah KUNCI JAWABAN yang benar\n'
      '- [GAMBAR_N] = ada gambar di posisi tersebut, pertahankan teks [GAMBAR_N] di field pertanyaan\n'
      '- [EQ: ...] = persamaan matematika → konversi ke LaTeX inline (contoh: \$4^{2}=16\$)\n'
      '- ^{...} = superscript, _{...} = subscript → konversi ke LaTeX\n\n'
      'Format JSON:\n'
      '{"soal":[{"nomor":1,"tipe":"PG","pertanyaan":"...","pilihan":["...","...","...","..."],"kunciJawaban":"A","skor":1}]}\n\n'
      'Aturan WAJIB:\n'
      '1. "pertanyaan" HARUS mencakup SEMUA konteks: lead-in/instruksi, sub-poin/pernyataan bernomor, DAN kalimat pertanyaan utama — pisahkan dengan \\n\n'
      '2. JANGAN potong bagian apapun dari soal; jika ada "Perhatikan ... berikut:" diikuti daftar bernomor, semua itu masuk ke "pertanyaan"\n'
      '3. tipe: "PG" untuk Pilihan Ganda, "BS" untuk Benar/Salah, "URAIAN" untuk Essay\n'
      '4. pilihan: teks TANPA huruf A/B/C/D di depan, array [] untuk BS dan URAIAN\n'
      '5. kunciJawaban: ambil dari baris [JAWABAN] → "A"/"B"/"C"/"D" untuk PG; "" jika tidak ada petunjuk\n'
      '6. Semua persamaan matematika → notasi LaTeX\n\n'
      'Teks dokumen:\n$text';

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.1,
        'max_tokens': 8000,
      }),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error']?['message'] ?? response.body);
    }

    final data    = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices'][0]['message']['content'] as String;

    String jsonStr      = content.trim();
    final jsonMatch     = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
    if (jsonMatch != null) jsonStr = jsonMatch.group(0)!;

    final parsed   = jsonDecode(jsonStr) as Map<String, dynamic>;
    final soalList = parsed['soal'] as List<dynamic>;

    return soalList.map((item) {
      final m       = item as Map<String, dynamic>;
      final tipeStr = m['tipe']?.toString().toUpperCase() ?? 'PG';
      final tipe    = tipeStr == 'BS'     ? TipeSoal.benarSalah
                    : tipeStr == 'URAIAN' ? TipeSoal.uraian
                    : TipeSoal.pilihanGanda;
      final pilihanRaw = (m['pilihan'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? <String>[];
      if (tipe == TipeSoal.pilihanGanda) {
        while (pilihanRaw.length < 4) pilihanRaw.add('');
      }
      final pertanyaan = m['pertanyaan']?.toString() ?? '';

      // Pasangkan gambar yang direferensikan dalam pertanyaan
      String? gambarB64;
      final gMatch = RegExp(r'\[GAMBAR_(\d+)\]').firstMatch(pertanyaan);
      if (gMatch != null) {
        gambarB64 = images['GAMBAR_${gMatch.group(1)}'];
      }

      return SoalDraft(
        tipe        : tipe,
        pertanyaan  : pertanyaan,
        gambarBase64: gambarB64,
        pilihan     : pilihanRaw,
        kunciJawaban: m['kunciJawaban']?.toString() ?? '',
        skor        : (m['skor'] as num?)?.toInt() ?? 1,
      );
    }).toList();
  }
}
