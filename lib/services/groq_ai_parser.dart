part of '../main.dart';

// ============================================================
// DOCX LOCAL PARSER — Parse soal dari docx secara lokal tanpa AI
// Mendukung: nomor soal, pilihan A-D, gambar, equation, kunci jawaban
// ============================================================
class DocxLocalParser {
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
        // Parse setiap <Relationship> terpisah untuk menangani urutan atribut apapun
        final relTagReg = RegExp(r'<Relationship[^>]+/?>', dotAll: true);
        for (final tag in relTagReg.allMatches(relsXml)) {
          final t = tag.group(0)!;
          // Cek apakah ini relasi gambar
          if (!RegExp(r'Type="[^"]*image', caseSensitive: false).hasMatch(t)) continue;
          final idMatch     = RegExp(r'Id="([^"]+)"').firstMatch(t);
          final targetMatch = RegExp(r'Target="([^"]+)"').firstMatch(t);
          if (idMatch == null || targetMatch == null) continue;
          final rId    = idMatch.group(1)!;
          final target = targetMatch.group(1)!;
          // Coba beberapa path: word/media/image1.png, media/image1.png
          final imgFile = archive.findFile('word/$target')
              ?? archive.findFile(target);
          if (imgFile != null) {
            rIdToBase64[rId] = base64Encode(imgFile.content as List<int>);
          }
        }
      }
      debugPrint('[Docx Parser] Ditemukan ${rIdToBase64.length} gambar dari relasi');

      // ── Parse word/numbering.xml ──────────────────────────────────
      // numId → ilvl → (format, lvlText)
      final numDefs = <String, Map<int, (String, String)>>{};
      final numXmlFile = archive.findFile('word/numbering.xml');
      if (numXmlFile != null) {
        final numXml = utf8.decode(numXmlFile.content as List<int>);
        // abstractNum definitions
        final abNumMap = <String, Map<int, (String, String)>>{};
        final abNumReg = RegExp(
            r'<w:abstractNum w:abstractNumId="(\d+)"[^>]*>(.*?)</w:abstractNum>',
            dotAll: true);
        for (final ab in abNumReg.allMatches(numXml)) {
          final abId   = ab.group(1)!;
          final abBody = ab.group(2)!;
          final levels = <int, (String, String)>{};
          final lvlReg = RegExp(
              r'<w:lvl w:ilvl="(\d+)"[^>]*>(.*?)</w:lvl>', dotAll: true);
          for (final lvl in lvlReg.allMatches(abBody)) {
            final ilvl    = int.parse(lvl.group(1)!);
            final lvlBody = lvl.group(2)!;
            final fmt  = RegExp(r'<w:numFmt w:val="([^"]+)"')
                             .firstMatch(lvlBody)?.group(1) ?? 'decimal';
            final txt  = RegExp(r'<w:lvlText w:val="([^"]*)"')
                             .firstMatch(lvlBody)?.group(1) ?? '%1.';
            levels[ilvl] = (fmt, txt);
          }
          abNumMap[abId] = levels;
        }
        // numId → abstractNumId
        final numReg = RegExp(
            r'<w:num w:numId="(\d+)"[^>]*>.*?<w:abstractNumId w:val="(\d+)"',
            dotAll: true);
        for (final num in numReg.allMatches(numXml)) {
          final nid = num.group(1)!;
          final abId = num.group(2)!;
          if (abNumMap.containsKey(abId)) numDefs[nid] = abNumMap[abId]!;
        }
      }
      debugPrint('[Docx Parser] numDefs: ${numDefs.keys.toList()} (${numDefs.length} entries)');

      // Counter per numId → ilvl
      final numCounters = <String, Map<int, int>>{};

      // ── Parse word/styles.xml untuk style-based numbering ──────────
      // Banyak Word doc menyimpan numPr di style, bukan di paragraf
      // styleId → (numId, ilvl)
      final styleNumMap = <String, (String numId, int ilvl)>{};
      final stylesFile = archive.findFile('word/styles.xml');
      if (stylesFile != null) {
        final stylesXml = utf8.decode(stylesFile.content as List<int>);
        final styleReg = RegExp(
            r'<w:style[^>]+w:styleId="([^"]+)"[^>]*>(.*?)</w:style>',
            dotAll: true);
        for (final sm in styleReg.allMatches(stylesXml)) {
          final styleId = sm.group(1)!;
          final styleBody = sm.group(2)!;
          // Cek apakah style ini punya numPr
          final snpMatch = RegExp(r'<w:numPr>(.*?)</w:numPr>', dotAll: true)
              .firstMatch(styleBody);
          if (snpMatch != null) {
            final snpBlock = snpMatch.group(1)!;
            final sIlvl = RegExp(r'<w:ilvl w:val="(\d+)"')
                .firstMatch(snpBlock)?.group(1) ?? '0';
            final sNumId = RegExp(r'<w:numId w:val="(\d+)"')
                .firstMatch(snpBlock)?.group(1) ?? '0';
            if (sNumId != '0') {
              styleNumMap[styleId] = (sNumId, int.parse(sIlvl));
            }
          }
        }
      }
      debugPrint('[Docx Parser] styleNumMap: ${styleNumMap.keys.toList()} (${styleNumMap.length} styles with numbering)');

      // ── Parse paragraf dokumen ─────────────────────────────────────
      final xmlFile = archive.findFile('word/document.xml');
      if (xmlFile == null) return (text: '', images: {});
      final xml = utf8.decode(xmlFile.content as List<int>);

      final paraReg  = RegExp(r'<w:p[ >].*?</w:p>', dotAll: true);
      final runReg   = RegExp(r'<w:r[ >].*?</w:r>', dotAll: true);
      final tReg     = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
      // numPr: parse ilvl dan numId secara terpisah (urutan bisa bervariasi)
      final numPrBlockReg = RegExp(r'<w:numPr>(.*?)</w:numPr>', dotAll: true);
      final ilvlReg = RegExp(r'<w:ilvl w:val="(\d+)"');
      final numIdReg = RegExp(r'<w:numId w:val="(\d+)"');
      final pStyleReg = RegExp(r'<w:pStyle w:val="([^"]+)"');

      final buf       = StringBuffer();
      final namedImgs = <String, String>{}; // 'GAMBAR_1' → base64
      int   imgCount  = 0;

      // ── Helper: extract text from a single paragraph XML ──────
      String parseParagraph(String pXml) {
        final lineBuf = StringBuffer();
        bool  hasRed  = false;
        bool  hasBold = false;
        bool  hasColor = false;

        // ── Numbering (Word list format) ──────────────────────────
        // Cek numPr langsung di paragraf, ATAU inherit dari pStyle
        String numPrefix = '';
        String? numId;
        int ilvl = 0;

        final numPrMatch = numPrBlockReg.firstMatch(pXml);
        if (numPrMatch != null) {
          final block = numPrMatch.group(1)!;
          numId = numIdReg.firstMatch(block)?.group(1);
          ilvl = int.parse(ilvlReg.firstMatch(block)?.group(1) ?? '0');
        }

        // Fallback: cek pStyle → style numbering
        if ((numId == null || numId == '0') && pXml.contains('<w:pStyle')) {
          final psMatch = pStyleReg.firstMatch(pXml);
          if (psMatch != null) {
            final styleId = psMatch.group(1)!;
            if (styleNumMap.containsKey(styleId)) {
              final (sNumId, sIlvl) = styleNumMap[styleId]!;
              numId = sNumId;
              // ilvl dari paragraf override style, tapi jika tidak ada, gunakan style
              if (numPrMatch == null) {
                ilvl = sIlvl;
              }
            }
          }
        }

        if (numId != null && numId != '0') {
          numCounters.putIfAbsent(numId, () => {});
          final ctrs = numCounters[numId]!;
          ctrs.keys.where((k) => k > ilvl).toList().forEach(ctrs.remove);
          ctrs[ilvl] = (ctrs[ilvl] ?? 0) + 1;
          final count = ctrs[ilvl]!;
          if (numDefs.containsKey(numId) &&
              numDefs[numId]!.containsKey(ilvl)) {
            final (fmt, lvlTxt) = numDefs[numId]![ilvl]!;
            final numStr = _formatListNum(count, fmt);
            numPrefix = lvlTxt.replaceAll('%${ilvl + 1}', numStr);
            numPrefix = '  ' * ilvl + numPrefix + ' ';
          } else {
            numPrefix = '  ' * ilvl + '$count. ';
          }
        }

        // ── Gambar (r:embed, r:link, r:id — semua pola Word) ───
        final imgRefReg = RegExp(r'r:(?:embed|link|id)="([^"]+)"');
        final foundRIds = <String>{};
        for (final em in imgRefReg.allMatches(pXml)) {
          final rId = em.group(1)!;
          if (rIdToBase64.containsKey(rId) && !foundRIds.contains(rId)) {
            foundRIds.add(rId);
            imgCount++;
            final key = 'GAMBAR_$imgCount';
            namedImgs[key] = rIdToBase64[rId]!;
            lineBuf.write('[$key] ');
          }
        }

        // ── Ganti OMML inline agar urutan terjaga ─────────────────
        String pXmlInline = pXml;
        if (pXml.contains('<m:oMath')) {
          final oMathReg =
              RegExp(r'<m:oMath[ >].*?</m:oMath>', dotAll: true);
          pXmlInline = pXmlInline.replaceAllMapped(oMathReg, (m) {
            final eqText = _ommlToText(m.group(0)!);
            if (eqText.isEmpty) return '';
            // Jika teks sederhana (hanya angka/huruf/titik/koma/spasi/titik-dua),
            // jangan bungkus sebagai equation — langsung sisipkan sebagai teks biasa
            if (RegExp(r'^[\w\s.,;:+\-=()/%]+$').hasMatch(eqText)) {
              return '<w:r><w:t>$eqText</w:t></w:r>';
            }
            return '<w:r><w:t>[EQ: $eqText]</w:t></w:r>';
          });
        }

        // ── Teks per run (deteksi bold, warna, super/subscript) ──
        for (final run in runReg.allMatches(pXmlInline)) {
          final rXml = run.group(0)!;

          // Warna merah/biru/hijau dll (pilihan yang merupakan jawaban)
          if (!hasRed &&
              RegExp(r'<w:color w:val="(?:FF|ff|C0|c0)[0-9A-Fa-f]{4}"')
                  .hasMatch(rXml)) {
            hasRed = true;
          }
          // Warna apapun selain hitam/auto
          if (!hasColor &&
              RegExp(r'<w:color w:val="(?!000000|auto)[0-9A-Fa-f]{6}"')
                  .hasMatch(rXml)) {
            hasColor = true;
          }
          // Bold
          if (!hasBold &&
              (rXml.contains('<w:b/>') || rXml.contains('<w:b w:val="true"') ||
               rXml.contains('<w:b w:val="1"'))) {
            hasBold = true;
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
        if (line.isEmpty) return '';
        line = numPrefix + line;
        if (hasRed) line = '[JAWABAN] $line';
        else if (hasBold) line = '[BOLD] $line';
        else if (hasColor) line = '[BERWARNA] $line';
        return line;
      }

      // ── Parse tabel (w:tbl) terlebih dahulu ─────────────────────
      // Ganti <w:tbl>...</w:tbl> dengan representasi teks tabel
      String xmlProcessed = xml;
      final tblReg = RegExp(r'<w:tbl[ >].*?</w:tbl>', dotAll: true);
      xmlProcessed = xmlProcessed.replaceAllMapped(tblReg, (tblMatch) {
        final tblXml = tblMatch.group(0)!;
        final rowReg = RegExp(r'<w:tr[ >].*?</w:tr>', dotAll: true);
        final cellReg = RegExp(r'<w:tc[ >].*?</w:tc>', dotAll: true);
        final rows = <List<String>>[];
        for (final row in rowReg.allMatches(tblXml)) {
          final cells = <String>[];
          for (final cell in cellReg.allMatches(row.group(0)!)) {
            // Tiap cell bisa punya beberapa paragraf
            final cellParts = <String>[];
            for (final p in paraReg.allMatches(cell.group(0)!)) {
              final ct = _mText(p.group(0)!);
              if (ct.isNotEmpty) cellParts.add(ct);
            }
            cells.add(cellParts.join(' '));
          }
          rows.add(cells);
        }
        if (rows.isEmpty) return '';
        // Render sebagai tabel teks
        final sb = StringBuffer();
        sb.writeln('[TABEL]');
        for (final row in rows) {
          sb.writeln('| ${row.join(' | ')} |');
        }
        sb.writeln('[/TABEL]');
        // Ganti XML tabel dengan paragraf palsu agar tidak diproses ulang
        return '<w:p><w:r><w:t>${sb.toString()}</w:t></w:r></w:p>';
      });

      for (final para in paraReg.allMatches(xmlProcessed)) {
        final line = parseParagraph(para.group(0)!);
        if (line.isNotEmpty) buf.writeln(line);
      }

      final result = buf.toString();
      debugPrint('[Docx Parser] Extracted ${result.split('\n').length} lines, ${namedImgs.length} images');
      // Show first 300 chars for debugging
      debugPrint('[Docx Parser] Preview: ${result.substring(0, result.length.clamp(0, 300))}');
      return (text: result, images: namedImgs);
    } catch (e, st) {
      debugPrint('[Docx Parser] extractStructured error: $e\n$st');
      return (text: '', images: {});
    }
  }

  // ============================================================
  // LOCAL PARSER — Parse soal dari docx secara lokal
  // Menggunakan output extractStructured + heuristic pattern matching
  // ============================================================

  /// Parse .docx bytes langsung ke List<SoalDraft>.
  /// Mendukung format Word apapun: nomor otomatis/manual, pilihan A-D,
  /// kunci jawaban dari warna/bold/section, gambar, equation.
  static List<SoalDraft> parseLocal(Uint8List bytes) {
    final extracted = extractStructured(bytes);
    if (extracted.text.trim().isEmpty) return [];
    return _parseStructuredText(extracted.text, extracted.images);
  }

  /// Parse teks terstruktur (output extractStructured) ke List<SoalDraft>
  static List<SoalDraft> _parseStructuredText(
      String text, Map<String, String> images) {
    final rawLines = text.split('\n').map((l) => l.trimRight()).toList();

    debugPrint('[Local Parser] Input: ${rawLines.length} lines');
    for (int i = 0; i < rawLines.length && i < 15; i++) {
      debugPrint('[Local Parser] L$i: ${rawLines[i]}');
    }

    // ── 0. Pisahkan konten tabel ──
    final lines = <String>[];
    bool inTable = false;
    final tableBuf = StringBuffer();
    for (final l in rawLines) {
      if (l.trim().startsWith('[TABEL]')) {
        inTable = true; tableBuf.clear(); tableBuf.write(l); continue;
      }
      if (l.trim().startsWith('[/TABEL]')) {
        inTable = false; tableBuf.write(' $l');
        lines.add(tableBuf.toString()); continue;
      }
      if (inTable) { tableBuf.write(' | ${l.trim()}'); continue; }
      lines.add(l);
    }
    if (inTable && tableBuf.isNotEmpty) lines.add(tableBuf.toString());

    // ── 1. Deteksi section template: [PILIHAN GANDA], [BENAR SALAH], [URAIAN] ──
    TipeSoal? forcedTipe;

    // ── 2. Cari bagian "Kunci Jawaban" di akhir dokumen ──────────
    final kunciMap = <int, String>{};
    int kunciSectionStart = -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = _stripMarkers(lines[i]);
      if (RegExp(r'(?:KUNCI|Kunci)\s*(?:JAWABAN|Jawaban)', caseSensitive: false)
          .hasMatch(line)) {
        kunciSectionStart = i;
        break;
      }
    }
    if (kunciSectionStart >= 0) {
      final kunciReg = RegExp(r'(\d+)\s*[.)]\s*([A-Ea-e])');
      for (int i = kunciSectionStart; i < lines.length; i++) {
        final stripped = _stripMarkers(lines[i]);
        for (final m in kunciReg.allMatches(stripped)) {
          final num = int.tryParse(m.group(1)!);
          if (num != null) kunciMap[num] = m.group(2)!.toUpperCase();
        }
      }
      lines.removeRange(kunciSectionStart, lines.length);
      debugPrint('[Local Parser] Kunci jawaban section: ${kunciMap.length} kunci ditemukan');
    }

    // ── 3. Parse soal ───────────────────────────────────────────
    final questionReg = RegExp(r'^(\d{1,3})\s*[.)]\s+(.+)');
    final optionReg = RegExp(r'^([A-Ea-e])\s*[.)]\s+(.+)');

    final soals = <SoalDraft>[];
    int currentNomor = 0;
    String currentQuestion = '';
    List<String> currentOptions = [];
    String? currentGambar;
    int currentSkor = 1;
    String templateKunci = ''; // dari "JAWABAN: B"
    // Per-opsi: track [JAWABAN] (red) terpisah dari [BOLD]/[BERWARNA]
    List<bool> optionIsRed = [];
    List<bool> optionIsBold = [];
    List<bool> optionIsColored = [];

    void flush() {
      if (currentQuestion.isEmpty) return;
      currentNomor++;

      TipeSoal tipe = forcedTipe ?? TipeSoal.pilihanGanda;
      if (currentOptions.isEmpty) {
        tipe = TipeSoal.uraian;
      } else if (currentOptions.length == 2) {
        final lower = currentOptions.map((o) => o.toLowerCase().trim()).toList();
        if ((lower.contains('benar') && lower.contains('salah')) ||
            (lower.contains('true') && lower.contains('false'))) {
          tipe = TipeSoal.benarSalah;
        }
      }

      // ── Kunci jawaban — prioritas: kunciMap > template JAWABAN: > [JAWABAN] (red) > smart bold/color > kosong ──
      String kunci = '';

      // P1: Kunci dari section "Kunci Jawaban" di akhir dokumen
      if (kunciMap.containsKey(currentNomor)) {
        kunci = kunciMap[currentNomor]!;
      }

      // P2: Kunci dari template marker "JAWABAN: B"
      if (kunci.isEmpty && templateKunci.isNotEmpty) {
        kunci = templateKunci.toUpperCase();
      }

      // P3: [JAWABAN] = warna merah → paling reliable
      if (kunci.isEmpty) {
        final redCount = optionIsRed.where((x) => x).length;
        if (redCount == 1) {
          kunci = String.fromCharCode(65 + optionIsRed.indexOf(true));
        }
      }

      // P4: [BERWARNA] = warna non-hitam → reliable jika hanya 1 opsi berwarna
      if (kunci.isEmpty) {
        final colorCount = optionIsColored.where((x) => x).length;
        if (colorCount >= 1 && colorCount < currentOptions.length) {
          // Ambil opsi pertama yang berwarna
          kunci = String.fromCharCode(65 + optionIsColored.indexOf(true));
        }
      }

      // P5: [BOLD] → hanya jika TIDAK semua opsi bold (smart detection)
      if (kunci.isEmpty) {
        final boldCount = optionIsBold.where((x) => x).length;
        if (boldCount >= 1 && boldCount < currentOptions.length) {
          // Hanya 1 atau beberapa opsi bold, bukan semua → kemungkinan jawaban
          kunci = String.fromCharCode(65 + optionIsBold.indexOf(true));
        }
        // Jika SEMUA opsi bold → abaikan, tidak informatif
      }

      final pertanyaan = _processEq(currentQuestion.trim());

      String? gambar = currentGambar;
      if (gambar == null) {
        final gMatch = RegExp(r'\[GAMBAR_(\d+)\]').firstMatch(pertanyaan);
        if (gMatch != null) {
          gambar = images['GAMBAR_${gMatch.group(1)}'];
        }
      }

      final pilihan = currentOptions.map(_processEq).toList();
      if (tipe == TipeSoal.pilihanGanda) {
        while (pilihan.length < 4) pilihan.add('');
      }

      soals.add(SoalDraft(
        tipe: tipe,
        pertanyaan: pertanyaan,
        gambarBase64: gambar,
        pilihan: pilihan,
        kunciJawaban: kunci,
        skor: currentSkor,
      ));

      currentQuestion = '';
      currentOptions = [];
      currentGambar = null;
      currentSkor = 1;
      templateKunci = '';
      optionIsRed = [];
      optionIsBold = [];
      optionIsColored = [];
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;

      final stripped = _stripMarkers(line);
      if (stripped.isEmpty) continue;

      // ── Template section markers ──
      if (stripped.contains('[PILIHAN GANDA]')) { flush(); forcedTipe = TipeSoal.pilihanGanda; continue; }
      if (stripped.contains('[BENAR SALAH]'))   { flush(); forcedTipe = TipeSoal.benarSalah;   continue; }
      if (stripped.contains('[URAIAN]'))         { flush(); forcedTipe = TipeSoal.uraian;       continue; }

      // ── Template kunci/skor markers ──
      if (RegExp(r'^JAWABAN\s*:\s*(.+)', caseSensitive: false).firstMatch(stripped) case final jm?) {
        templateKunci = jm.group(1)!.trim();
        continue;
      }
      if (RegExp(r'^SKOR\s*:\s*(\d+)', caseSensitive: false).firstMatch(stripped) case final sm?) {
        currentSkor = int.tryParse(sm.group(1)!) ?? 1;
        continue;
      }

      // ── Marker detection per baris ──
      final hasRed = line.contains('[JAWABAN]');
      final hasBold = line.contains('[BOLD]');
      final hasColor = line.contains('[BERWARNA]');

      // ── Cek pilihan jawaban (cek SEBELUM soal) ──
      final oMatch = optionReg.firstMatch(stripped);
      if (oMatch != null && currentQuestion.isNotEmpty) {
        final letter = oMatch.group(1)!.toUpperCase();
        final optText = oMatch.group(2)!;
        final expectedIdx = currentOptions.length;
        final expectedLetter = String.fromCharCode(65 + expectedIdx);

        if (letter == expectedLetter || currentOptions.isEmpty) {
          currentOptions.add(optText);
          optionIsRed.add(hasRed);
          optionIsBold.add(hasBold || hasRed);
          optionIsColored.add(hasColor || hasRed);
          _checkImageInLine(line, images, (g) { currentGambar ??= g; });
          continue;
        }
      }

      // ── Cek nomor soal baru ──
      final qMatch = questionReg.firstMatch(stripped);
      if (qMatch != null) {
        flush();
        currentQuestion = qMatch.group(2)!;
        _checkImageInLine(line, images, (g) { currentGambar ??= g; });
        continue;
      }

      // ── Baris [GAMBAR_N] standalone ──
      final imgOnly = RegExp(r'^\[GAMBAR_(\d+)\]$').firstMatch(stripped);
      if (imgOnly != null) {
        final key = 'GAMBAR_${imgOnly.group(1)}';
        if (currentGambar == null && images.containsKey(key)) {
          currentGambar = images[key];
        }
        if (currentQuestion.isNotEmpty) currentQuestion += ' [$key]';
        continue;
      }

      // ── Lanjutan teks pertanyaan (multi-line) ──
      if (currentQuestion.isNotEmpty && currentOptions.isEmpty) {
        currentQuestion += '\n$stripped';
        _checkImageInLine(line, images, (g) { currentGambar ??= g; });
        continue;
      }

      // ── Kelanjutan opsi terakhir ──
      if (currentOptions.isNotEmpty && stripped.isNotEmpty) {
        if (!questionReg.hasMatch(stripped) && !optionReg.hasMatch(stripped)) {
          currentOptions[currentOptions.length - 1] += ' $stripped';
          continue;
        }
      }
    }
    flush();

    debugPrint('[Local Parser] Hasil: ${soals.length} soal, '
        '${soals.where((s) => s.kunciJawaban.isNotEmpty).length} kunci, '
        '${soals.where((s) => s.gambarBase64 != null).length} gambar');

    // ── FALLBACK: jika tidak ada soal ditemukan, coba deteksi dari cluster opsi ──
    if (soals.isEmpty) {
      debugPrint('[Local Parser] Fallback: mencoba deteksi dari cluster opsi...');
      return _parseByOptionClusters(lines, images, kunciMap);
    }

    return soals;
  }

  /// Strip marker tags dari baris teks
  static String _stripMarkers(String line) {
    return line
        .replaceFirst(RegExp(r'^\s*\[JAWABAN\]\s*'), '')
        .replaceFirst(RegExp(r'^\s*\[BOLD\]\s*'), '')
        .replaceFirst(RegExp(r'^\s*\[BERWARNA\]\s*'), '')
        .trim();
  }

  /// Fallback parser: cari soal dari cluster opsi (a/b/c/d)
  static List<SoalDraft> _parseByOptionClusters(
      List<String> lines, Map<String, String> images,
      Map<int, String> kunciMap) {
    final optionLineReg = RegExp(r'^([A-Ea-e])\s*[.)]\s+(.+)');
    final soals = <SoalDraft>[];
    int nomor = 0;

    // Cari indeks baris opsi 'A' (awal cluster opsi)
    final optionAIndices = <int>[];
    for (int i = 0; i < lines.length; i++) {
      final stripped = _stripMarkers(lines[i]);
      final m = optionLineReg.firstMatch(stripped);
      if (m != null && m.group(1)!.toUpperCase() == 'A') {
        optionAIndices.add(i);
      }
    }

    debugPrint('[Local Parser] Fallback: ${optionAIndices.length} cluster opsi');
    if (optionAIndices.isEmpty) return [];

    int prevEnd = 0;
    for (int ci = 0; ci < optionAIndices.length; ci++) {
      final aIdx = optionAIndices[ci];
      final nextBound = ci + 1 < optionAIndices.length
          ? optionAIndices[ci + 1]
          : lines.length;

      // Kumpulkan pertanyaan (baris sebelum opsi A)
      final questionBuf = StringBuffer();
      String? gambar;
      for (int qi = prevEnd; qi < aIdx; qi++) {
        final ql = _stripMarkers(lines[qi]);
        if (ql.isEmpty) continue;
        final numStrip = RegExp(r'^\d{1,3}\s*[.)]\s+(.+)').firstMatch(ql);
        final qText = numStrip != null ? numStrip.group(1)! : ql;
        if (questionBuf.isNotEmpty) questionBuf.write('\n');
        questionBuf.write(qText);
        final gMatch = RegExp(r'\[GAMBAR_(\d+)\]').firstMatch(ql);
        if (gMatch != null && gambar == null) {
          final key = 'GAMBAR_${gMatch.group(1)}';
          if (images.containsKey(key)) gambar = images[key];
        }
      }

      if (questionBuf.isEmpty) { prevEnd = nextBound; continue; }

      // Kumpulkan opsi
      final options = <String>[];
      final optRedMarkers = <bool>[];
      final optBoldMarkers = <bool>[];
      final optColorMarkers = <bool>[];
      for (int oi = aIdx; oi < nextBound; oi++) {
        final ol = lines[oi];
        final stripped = _stripMarkers(ol);
        final om = optionLineReg.firstMatch(stripped);
        if (om != null) {
          options.add(om.group(2)!);
          optRedMarkers.add(ol.contains('[JAWABAN]'));
          optBoldMarkers.add(ol.contains('[BOLD]') || ol.contains('[JAWABAN]'));
          optColorMarkers.add(ol.contains('[BERWARNA]') || ol.contains('[JAWABAN]'));
          final gm = RegExp(r'\[GAMBAR_(\d+)\]').firstMatch(ol);
          if (gm != null && gambar == null) {
            final key = 'GAMBAR_${gm.group(1)}';
            if (images.containsKey(key)) gambar = images[key];
          }
        }
      }

      nomor++;
      // Smart kunci detection (same priority as main parser)
      String kunci = '';
      if (kunciMap.containsKey(nomor)) {
        kunci = kunciMap[nomor]!;
      }
      if (kunci.isEmpty) {
        final redCount = optRedMarkers.where((x) => x).length;
        if (redCount == 1) {
          kunci = String.fromCharCode(65 + optRedMarkers.indexOf(true));
        }
      }
      if (kunci.isEmpty) {
        final colorCount = optColorMarkers.where((x) => x).length;
        if (colorCount >= 1 && colorCount < options.length) {
          kunci = String.fromCharCode(65 + optColorMarkers.indexOf(true));
        }
      }
      if (kunci.isEmpty) {
        final boldCount = optBoldMarkers.where((x) => x).length;
        if (boldCount >= 1 && boldCount < options.length) {
          kunci = String.fromCharCode(65 + optBoldMarkers.indexOf(true));
        }
      }

      final pertanyaan = _processEq(questionBuf.toString().trim());
      if (gambar == null) {
        final gMatch = RegExp(r'\[GAMBAR_(\d+)\]').firstMatch(pertanyaan);
        if (gMatch != null) gambar = images['GAMBAR_${gMatch.group(1)}'];
      }

      final pilihan = options.map(_processEq).toList();
      while (pilihan.length < 4) pilihan.add('');

      soals.add(SoalDraft(
        tipe: TipeSoal.pilihanGanda,
        pertanyaan: pertanyaan,
        gambarBase64: gambar,
        pilihan: pilihan,
        kunciJawaban: kunci,
        skor: 1,
      ));

      prevEnd = nextBound;
    }

    debugPrint('[Local Parser] Fallback: ${soals.length} soal, '
        '${soals.where((s) => s.kunciJawaban.isNotEmpty).length} kunci');
    return soals;
  }

  /// Helper: cek apakah baris mengandung [GAMBAR_N] dan panggil callback
  static void _checkImageInLine(String line, Map<String, String> images,
      void Function(String base64) onFound) {
    final gMatch = RegExp(r'\[GAMBAR_(\d+)\]').firstMatch(line);
    if (gMatch != null) {
      final key = 'GAMBAR_${gMatch.group(1)}';
      if (images.containsKey(key)) onFound(images[key]!);
    }
  }

  /// Format angka list sesuai numFmt Word
  static String _formatListNum(int n, String fmt) {
    switch (fmt) {
      case 'lowerLetter': return String.fromCharCode(96 + ((n - 1) % 26) + 1);
      case 'upperLetter': return String.fromCharCode(64 + ((n - 1) % 26) + 1);
      case 'lowerRoman':  return _toRoman(n).toLowerCase();
      case 'upperRoman':  return _toRoman(n).toUpperCase();
      case 'bullet':      return '•';
      case 'none':        return '';
      default:            return '$n';
    }
  }

  static String _toRoman(int n) {
    const vals = [1000,900,500,400,100,90,50,40,10,9,5,4,1];
    const syms = ['M','CM','D','CD','C','XC','L','XL','X','IX','V','IV','I'];
    final buf = StringBuffer();
    var x = n;
    for (var i = 0; i < vals.length; i++) {
      while (x >= vals[i]) { buf.write(syms[i]); x -= vals[i]; }
    }
    return buf.toString();
  }

  /// Konversi OMML XML ke teks LaTeX
  static String _ommlToText(String xml) {
    // Fraction: \frac{num}{den}
    final fracReg = RegExp(
        r'<m:f>.*?<m:num>(.*?)</m:num>.*?<m:den>(.*?)</m:den>.*?</m:f>',
        dotAll: true);
    // Radical: \sqrt{...}
    final radReg = RegExp(r'<m:rad>.*?<m:e>(.*?)</m:e>.*?</m:rad>',
        dotAll: true);
    // Superscript: base^{sup}
    final sSupReg = RegExp(
        r'<m:sSup>.*?<m:e>(.*?)</m:e>.*?<m:sup>(.*?)</m:sup>.*?</m:sSup>',
        dotAll: true);
    // Subscript: base_{sub}
    final sSubReg = RegExp(
        r'<m:sSub>.*?<m:e>(.*?)</m:e>.*?<m:sub>(.*?)</m:sub>.*?</m:sSub>',
        dotAll: true);
    // SubSup: base_{sub}^{sup}
    final sSubSupReg = RegExp(
        r'<m:sSubSup>.*?<m:e>(.*?)</m:e>.*?<m:sub>(.*?)</m:sub>.*?<m:sup>(.*?)</m:sup>.*?</m:sSubSup>',
        dotAll: true);
    // Delimiter (parentheses/brackets): \left( ... \right)
    final delimReg = RegExp(
        r'<m:d>.*?<m:e>(.*?)</m:e>.*?</m:d>',
        dotAll: true);

    String s = xml;
    bool hadStructure = false;

    // Process nested structures from most complex to simplest
    if (fracReg.hasMatch(s)) { hadStructure = true; }
    s = s.replaceAllMapped(fracReg, (m) =>
        '\\frac{${_mText(m.group(1)!)}}{${_mText(m.group(2)!)}}');

    if (radReg.hasMatch(s)) { hadStructure = true; }
    s = s.replaceAllMapped(radReg,  (m) =>
        '\\sqrt{${_mText(m.group(1)!)}}');

    if (sSubSupReg.hasMatch(s)) { hadStructure = true; }
    s = s.replaceAllMapped(sSubSupReg, (m) =>
        '${_mText(m.group(1)!)}_{${_mText(m.group(2)!)}}^{${_mText(m.group(3)!)}}');

    if (sSupReg.hasMatch(s)) { hadStructure = true; }
    s = s.replaceAllMapped(sSupReg, (m) =>
        '${_mText(m.group(1)!)}^{${_mText(m.group(2)!)}}');

    if (sSubReg.hasMatch(s)) { hadStructure = true; }
    s = s.replaceAllMapped(sSubReg, (m) =>
        '${_mText(m.group(1)!)}_{${_mText(m.group(2)!)}}');

    if (delimReg.hasMatch(s)) { hadStructure = true; }
    s = s.replaceAllMapped(delimReg, (m) =>
        '(${_mText(m.group(1)!)})');

    // Jika ada struktur OMML yang sudah dikonversi ke plain text,
    // ambil sisa <m:t> DAN plain text hasil konversi
    if (hadStructure) {
      // Strip sisa XML tags, pertahankan plain text hasil konversi
      // 1. Ambil <m:t> yang tersisa
      final mTReg = RegExp(r'<m:t[^>]*>(.*?)</m:t>', dotAll: true);
      final remaining = mTReg.allMatches(s).map((m) => m.group(1) ?? '').join();
      // 2. Strip semua XML tags dari hasil
      final stripped = s.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      // Gabungkan: jika stripped sudah mengandung konversi, gunakan itu
      return stripped.isNotEmpty ? stripped : remaining;
    }

    // Tidak ada struktur khusus: ambil semua <m:t>
    final mTReg = RegExp(r'<m:t[^>]*>(.*?)</m:t>', dotAll: true);
    return mTReg.allMatches(s).map((m) => m.group(1) ?? '').join().trim();
  }

  /// Extract text from OMML or w:t elements
  static String _mText(String xml) {
    // Try OMML text first
    final mR = RegExp(r'<m:t[^>]*>(.*?)</m:t>', dotAll: true);
    final mMatches = mR.allMatches(xml).map((m) => m.group(1) ?? '').join();
    if (mMatches.isNotEmpty) return mMatches.trim();
    // Fallback to w:t
    final wR = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
    return wR.allMatches(xml).map((m) => m.group(1) ?? '').join().trim();
  }

  // (Semua metode AI telah dihapus — parsing 100% lokal)

  /// Konversi [EQ: ...] dan Unicode superscript/subscript ke LaTeX inline
  static String _processEq(String text) {
    // Tabel Unicode superscript → digit
    const supMap = {
      '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
      '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9',
      'ⁿ': 'n', 'ⁱ': 'i',
    };
    // Tabel Unicode subscript → digit
    const subMap = {
      '₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4',
      '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9',
    };

    // Proteksi [GAMBAR_N] tags agar tidak diproses sebagai subscript
    final gambarTags = <String, String>{};
    int gIdx = 0;
    String s = text.replaceAllMapped(RegExp(r'\[GAMBAR_\d+\]'), (m) {
      final key = '\x00GTAG${gIdx++}\x00';
      gambarTags[key] = m.group(0)!;
      return key;
    });

    // 0. Normalisasi $$...$$ (block LaTeX dari AI) → $...$ (inline)
    s = s.replaceAllMapped(RegExp(r'\$\$([^$]+)\$\$'), (m) {
      return ' \$${m.group(1)!.trim()}\$ ';
    });

    // 1. [EQ: ...] → $LaTeX$
    s = s.replaceAllMapped(RegExp(r'\[EQ: ([^\]]+)\]'), (m) {
      String eq = m.group(1)!.trim();
      for (final e in supMap.entries) eq = eq.replaceAll(e.key, '^{${e.value}}');
      for (final e in subMap.entries) eq = eq.replaceAll(e.key, '_{${e.value}}');
      return ' \$$eq\$ ';
    });

    // 2a. Unicode superscript/subscript langsung setelah $...$ → masukkan ke dalam LaTeX
    //     Contoh: $\angle CB$² → $\angle CB^{2}$
    for (final e in supMap.entries) {
      s = s.replaceAllMapped(RegExp(r'\$([^$]+)\$' + e.key), (m) {
        return ' \$${m.group(1)!}^{${e.value}}\$ ';
      });
    }
    for (final e in subMap.entries) {
      s = s.replaceAllMapped(RegExp(r'\$([^$]+)\$' + e.key), (m) {
        return ' \$${m.group(1)!}_{${e.value}}\$ ';
      });
    }

    // ── Proteksi: sembunyikan semua $...$ yang sudah ada agar step 2b-2d
    //    tidak mencocokkan ^{} atau _{} yang sudah di DALAM blok LaTeX ──
    final latexBlocks = <String, String>{};
    int lIdx = 0;
    s = s.replaceAllMapped(RegExp(r'\$([^$]+)\$'), (m) {
      final key = '\x01LTX${lIdx++}\x01';
      latexBlocks[key] = m.group(0)!;
      return key;
    });

    // 2b. Unicode superscript di teks biasa
    for (final e in supMap.entries) {
      s = s.replaceAllMapped(RegExp(r'([^\s\x01]+)' + e.key), (m) {
        return ' \$${m.group(1)!}^{${e.value}}\$ ';
      });
    }
    for (final e in subMap.entries) {
      s = s.replaceAllMapped(RegExp(r'([^\s\x01]+)' + e.key), (m) {
        return ' \$${m.group(1)!}_{${e.value}}\$ ';
      });
    }

    // 2c-i. (...)^{...} atau (...)_{...} → bungkus parenthesized expr + superscript
    //     Contoh: "(x + 3)^{2}" → "$(x + 3)^{2}$"
    s = s.replaceAllMapped(
      RegExp(r'(\([^)]*\))(\^{[^}]+})'),
      (m) => ' \$${m.group(1)!}${m.group(2)!}\$ ',
    );
    s = s.replaceAllMapped(
      RegExp(r'(\([^)]*\))(_{[^}]+})'),
      (m) => ' \$${m.group(1)!}${m.group(2)!}\$ ',
    );

    // 2c-ii. Bare ^{...} atau _{...} di teks biasa → bungkus dgn LaTeX
    //     Contoh: "x^{2} + y" → "$x^{2}$ + y"
    s = s.replaceAllMapped(
      RegExp(r'([a-zA-Z0-9]+)(\^{[^}]+})'),
      (m) => ' \$${m.group(1)!}${m.group(2)!}\$ ',
    );
    s = s.replaceAllMapped(
      RegExp(r'([a-zA-Z0-9]+)(_{[^}]+})'),
      (m) => ' \$${m.group(1)!}${m.group(2)!}\$ ',
    );

    // 2c-iii. Bare {N} tanpa ^ (artefak OMML accent, mis. P{'} → P')
    s = s.replaceAllMapped(
      RegExp(r"([a-zA-Z0-9]+)\{'\}"),
      (m) => ' \$${m.group(1)!}\'\$ ',
    );

    // 2d. Bare ^N (tanpa kurung kurawal) → bungkus dgn LaTeX
    //     Contoh: "cm^2" → "$cm^{2}$", "x^2" → "$x^{2}$"
    s = s.replaceAllMapped(
      RegExp(r'([a-zA-Z]+)\^([0-9a-zA-Z])(?![{])'),
      (m) => ' \$${m.group(1)!}^{${m.group(2)!}}\$ ',
    );
    s = s.replaceAllMapped(
      RegExp(r'([a-zA-Z]+)_([0-9a-zA-Z])(?![{])'),
      (m) => ' \$${m.group(1)!}_{${m.group(2)!}}\$ ',
    );

    // 2d-ii. (...)^N → bungkus parenthesized expr + bare superscript
    s = s.replaceAllMapped(
      RegExp(r'(\([^)]*\))\^([0-9a-zA-Z])(?![{])'),
      (m) => ' \$${m.group(1)!}^{${m.group(2)!}}\$ ',
    );
    s = s.replaceAllMapped(
      RegExp(r'(\([^)]*\))_([0-9a-zA-Z])(?![{])'),
      (m) => ' \$${m.group(1)!}_{${m.group(2)!}}\$ ',
    );

    // ── Restore blok $...$ yang diproteksi ──
    for (final e in latexBlocks.entries) {
      s = s.replaceAll(e.key, e.value);
    }

    // 3. Pastikan ada spasi di antara teks dan $...$ (fix "250dan$\frac...")
    s = s.replaceAllMapped(RegExp(r'([a-zA-Z0-9])\s*(\$[^$])'), (m) {
      return '${m.group(1)!} ${m.group(2)!}';
    });
    s = s.replaceAllMapped(RegExp(r'(\$[^$]+\$)([a-zA-Z0-9])'), (m) {
      return '${m.group(1)!} ${m.group(2)!}';
    });

    // 4. Hapus spasi berlebih
    s = s.replaceAll(RegExp(r'  +'), ' ').trim();

    // 5. Consolidate: jika teks punya $...$ fragmented dan sisa teks
    //    hanya berisi simbol matematika (tanpa kata ≥3 huruf), gabungkan
    //    semua jadi satu blok $...$
    //    Contoh: "$K^{'}$ (-2, 0), $L^{'}$ (2, -5)" → "$K^{'}(-2, 0), L^{'}(2, -5)$"
    const _mathFuncs = {'sin','cos','tan','sec','csc','cot','log','det','lim','max','min'};
    if (RegExp(r'\$[^$]+\$').hasMatch(s)) {
      final nonLatex = s.replaceAll(RegExp(r'\$[^$]+\$'), '').trim();
      if (nonLatex.isNotEmpty) {
        final words = RegExp(r'[a-zA-Z]{3,}').allMatches(nonLatex);
        final hasNonMath = words.any((m) => !_mathFuncs.contains(m.group(0)!.toLowerCase()));
        if (!hasNonMath) {
          s = '\$${s.replaceAll(RegExp(r'\s*\$\s*'), ' ').trim()}\$';
        }
      }
    }

    // 5b. Jika teks TANPA $...$ tapi sepenuhnya matematika → bungkus seluruhnya
    //     Heuristik: tidak ada kata ≥3 huruf, dan ada simbol math (+,-,=,^,_,(,))
    if (!s.contains('\$') && s.isNotEmpty) {
      final words = RegExp(r'[a-zA-Z]{3,}').allMatches(s);
      final hasNonMath = words.any((m) => !_mathFuncs.contains(m.group(0)!.toLowerCase()));
      final hasMathOp = RegExp(r'[+\-=^_×÷]').hasMatch(s) ||
          RegExp(r'[A-Z]\(').hasMatch(s) || // P(-2,3) coordinate notation
          RegExp(r"[A-Z]'").hasMatch(s);     // P' prime notation
      if (!hasNonMath && hasMathOp) {
        s = '\$$s\$';
      }
    }

    // 6. Restore [GAMBAR_N] tags
    for (final e in gambarTags.entries) {
      s = s.replaceAll(e.key, e.value);
    }

    return s;
  }
}
