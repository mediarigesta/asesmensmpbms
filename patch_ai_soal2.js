const fs = require('fs');
const path = require('path');
const mainFile = path.join(__dirname, 'lib', 'main.dart');
let c = fs.readFileSync(mainFile, 'utf8');

// ─────────────────────────────────────────────────────────────────────────────
// 1. Tambah class GroqAiParser sebelum class SoalModel
// ─────────────────────────────────────────────────────────────────────────────
const BEFORE_SOAL_MODEL = `class SoalModel {`;

const GROQ_CLASS = `// ============================================================
// GROQ AI PARSER — Parse soal dari docx format bebas via Groq API
// API Key disimpan di Firestore: settings/app_config.groq_api_key
// ============================================================
class GroqAiParser {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model    = 'llama-3.3-70b-versatile';

  /// Ekstrak teks mentah dari .docx (satu baris per paragraf)
  static String extractText(Uint8List bytes) {
    try {
      final archive  = ZipDecoder().decodeBytes(bytes);
      final xmlFile  = archive.findFile('word/document.xml');
      if (xmlFile == null) return '';
      final xml      = utf8.decode(xmlFile.content as List<int>);
      final paraReg  = RegExp(r'<w:p[ >].*?</w:p>', dotAll: true);
      final tReg     = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
      final buf      = StringBuffer();
      for (final para in paraReg.allMatches(xml)) {
        final lineBuf = StringBuffer();
        for (final t in tReg.allMatches(para.group(0)!)) {
          lineBuf.write(t.group(1) ?? '');
        }
        final line = lineBuf.toString().trim();
        if (line.isNotEmpty) buf.writeln(line);
      }
      return buf.toString();
    } catch (_) { return ''; }
  }

  /// Kirim teks ke Groq, kembalikan List<SoalDraft>
  static Future<List<SoalDraft>> parse(String text, String apiKey) async {
    final prompt =
      'Kamu adalah asisten yang mengekstrak soal ujian dari dokumen sekolah. '
      'Ekstrak SEMUA soal dari teks berikut.\\n'
      'Kembalikan HANYA JSON valid, tanpa markdown code block, tanpa komentar apapun.\\n\\n'
      'Format JSON yang diinginkan:\\n'
      '{"soal":[{"nomor":1,"tipe":"PG","pertanyaan":"...","pilihan":["...","...","...","..."],"kunciJawaban":"A","skor":1}]}\\n\\n'
      'Aturan penting:\\n'
      '- tipe: "PG" untuk Pilihan Ganda, "BS" untuk Benar/Salah, "URAIAN" untuk Essay/Uraian\\n'
      '- pilihan: isi teks pilihan TANPA huruf A/B/C/D di depan, array kosong [] untuk BS dan URAIAN\\n'
      '- kunciJawaban: "A"/"B"/"C"/"D" untuk PG, "BENAR"/"SALAH" untuk BS, "" untuk URAIAN\\n'
      '- skor: angka (default 1, bisa lebih untuk uraian)\\n'
      '- Jika kunci jawaban tidak ditemukan, kosongkan saja\\n\\n'
      'Teks dokumen:\\n\$text';

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer \$apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.1,
        'max_tokens': 8000,
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error']?['message'] ?? response.body);
    }

    final data    = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices'][0]['message']['content'] as String;

    // Bersihkan response — ambil JSON saja jika ada markdown
    String jsonStr = content.trim();
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
    if (jsonMatch != null) jsonStr = jsonMatch.group(0)!;

    final parsed   = jsonDecode(jsonStr) as Map<String, dynamic>;
    final soalList = (parsed['soal'] as List<dynamic>);

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
      return SoalDraft(
        tipe        : tipe,
        pertanyaan  : m['pertanyaan']?.toString() ?? '',
        pilihan     : pilihanRaw,
        kunciJawaban: m['kunciJawaban']?.toString() ?? '',
        skor        : (m['skor'] as num?)?.toInt() ?? 1,
      );
    }).toList();
  }
}

class SoalModel {`;

if (!c.includes(BEFORE_SOAL_MODEL)) { console.error('ERROR: marker SoalModel tidak ditemukan'); process.exit(1); }
c = c.replace(BEFORE_SOAL_MODEL, GROQ_CLASS);
console.log('1. GroqAiParser class ✓');

// ─────────────────────────────────────────────────────────────────────────────
// 2. Tambah state _aiParsing di upload soal state class
// ─────────────────────────────────────────────────────────────────────────────
const OLD_STATE = `  // --- Docx import state ---\n  bool   _docxParsing  = false;\n  String? _docxFileName;`;
const NEW_STATE = `  // --- Docx import state ---\n  bool   _docxParsing  = false;\n  bool   _aiParsing    = false;\n  String? _docxFileName;`;

if (!c.includes(OLD_STATE)) { console.error('ERROR: marker state tidak ditemukan'); process.exit(1); }
c = c.replace(OLD_STATE, NEW_STATE);
console.log('2. State _aiParsing ✓');

// ─────────────────────────────────────────────────────────────────────────────
// 3. Tambah tombol "Upload & Parse dengan AI" di _stepDocxImport()
// ─────────────────────────────────────────────────────────────────────────────
const OLD_UPLOAD_END = `Format: .docx (Microsoft Word)",\n                  style: TextStyle(color: Colors.grey, fontSize: 11)),\n            ]),\n          ),\n        ),\n      ]),\n    );\n  }`;

const NEW_UPLOAD_END = `Format: .docx (Microsoft Word)",\n                  style: TextStyle(color: Colors.grey, fontSize: 11)),\n            ]),\n          ),\n        ),\n        const SizedBox(height: 20),\n\n        // ── Divider "Atau" ──\n        Row(children: [\n          const Expanded(child: Divider()),\n          Padding(\n            padding: const EdgeInsets.symmetric(horizontal: 12),\n            child: Text('Atau', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),\n          ),\n          const Expanded(child: Divider()),\n        ]),\n        const SizedBox(height: 16),\n\n        // ── Upload dengan AI ──\n        Container(\n          decoration: BoxDecoration(\n            gradient: LinearGradient(\n              colors: [Colors.purple.shade600, Colors.indigo.shade600],\n              begin: Alignment.topLeft, end: Alignment.bottomRight,\n            ),\n            borderRadius: BorderRadius.circular(16),\n            boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],\n          ),\n          padding: const EdgeInsets.all(16),\n          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n            Row(children: [\n              Container(\n                padding: const EdgeInsets.all(8),\n                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),\n                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),\n              ),\n              const SizedBox(width: 10),\n              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                Text('Upload dengan AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),\n                Text('Format bebas — AI akan memproses otomatis', style: TextStyle(color: Colors.white70, fontSize: 11)),\n              ]),\n            ]),\n            const SizedBox(height: 12),\n            const Text(\n              'Tidak perlu template khusus. Upload soal dalam format apapun — AI akan mengenali dan mengekstrak soal secara otomatis.',\n              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),\n            ),\n            const SizedBox(height: 14),\n            _aiParsing\n                ? const Center(child: Column(children: [\n                    CircularProgressIndicator(color: Colors.white),\n                    SizedBox(height: 8),\n                    Text('AI sedang membaca dokumen...', style: TextStyle(color: Colors.white70, fontSize: 12)),\n                  ]))\n                : SizedBox(\n                    width: double.infinity,\n                    child: ElevatedButton.icon(\n                      style: ElevatedButton.styleFrom(\n                        backgroundColor: Colors.white,\n                        foregroundColor: Colors.purple.shade700,\n                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),\n                        padding: const EdgeInsets.symmetric(vertical: 12),\n                      ),\n                      onPressed: _docxParsing ? null : _pickDocxWithAi,\n                      icon: const Icon(Icons.upload_file, size: 18),\n                      label: const Text('Pilih File .docx', style: TextStyle(fontWeight: FontWeight.bold)),\n                    ),\n                  ),\n          ]),\n        ),\n      ]),\n    );\n  }`;

if (!c.includes(OLD_UPLOAD_END)) { console.error('ERROR: marker akhir _stepDocxImport tidak ditemukan'); process.exit(1); }
c = c.replace(OLD_UPLOAD_END, NEW_UPLOAD_END);
console.log('3. Tombol AI di _stepDocxImport ✓');

// ─────────────────────────────────────────────────────────────────────────────
// 4. Tambah _pickDocxWithAi() setelah _parseDocxIsolate
// ─────────────────────────────────────────────────────────────────────────────
const AFTER_PARSE_ISOLATE = `  static List<SoalModel> _parseDocxIsolate(Uint8List bytes) => DocxParser.parse(bytes);`;

const AI_METHOD = `  static List<SoalModel> _parseDocxIsolate(Uint8List bytes) => DocxParser.parse(bytes);

  Future<void> _pickDocxWithAi() async {
    // 1. Ambil API key dari Firestore
    String groqApiKey = '';
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
      groqApiKey = doc.data()?['groq_api_key']?.toString() ?? '';
    } catch (_) {}

    if (groqApiKey.isEmpty) {
      _snack('API Key Groq belum diatur. Isi di Settings \u2192 Groq API Key.', Colors.orange);
      return;
    }

    setState(() => _aiParsing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['docx'], withData: true,
      );
      if (result == null || result.files.isEmpty) { setState(() => _aiParsing = false); return; }

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        _snack('Gagal membaca file', Colors.red);
        setState(() => _aiParsing = false); return;
      }

      // 2. Ekstrak teks dari docx
      final rawText = GroqAiParser.extractText(bytes);
      if (rawText.trim().isEmpty) {
        _snack('File tidak dapat dibaca atau kosong', Colors.red);
        setState(() => _aiParsing = false); return;
      }

      // 3. Kirim ke Groq AI
      final drafts = await GroqAiParser.parse(rawText, groqApiKey);
      _soals.clear();
      _soals.addAll(drafts);

      setState(() {
        _docxFileName = result.files.first.name;
        _aiParsing    = false;
        _docxParsed   = drafts.isNotEmpty;
        _editingIndex = -1;
      });

      if (drafts.isEmpty) {
        _snack('AI tidak menemukan soal dalam dokumen ini.', Colors.orange);
      } else {
        _snack('\${drafts.length} soal berhasil diparse oleh AI! Cek & edit sebelum upload.', Colors.green);
      }
    } catch (e) {
      setState(() => _aiParsing = false);
      _snack('Gagal: \$e', Colors.red);
    }
  }`;

if (!c.includes(AFTER_PARSE_ISOLATE)) { console.error('ERROR: marker _parseDocxIsolate tidak ditemukan'); process.exit(1); }
c = c.replace(AFTER_PARSE_ISOLATE, AI_METHOD);
console.log('4. _pickDocxWithAi() method ✓');

// ─────────────────────────────────────────────────────────────────────────────
// 5. Tambah field Groq API Key di Settings (sebelum "// Reset Status")
// ─────────────────────────────────────────────────────────────────────────────
const RESET_STATUS_MARKER = `      // Reset Status`;

const GROQ_KEY_CARD = `      // Groq AI API Key (untuk fitur parse soal dengan AI)
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.purple.shade600, Colors.indigo.shade600]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text("Groq AI API Key",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 6),
              const Text(
                  "API Key dari Groq (groq.com) untuk fitur upload soal otomatis dengan AI. Gratis.",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 20),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('settings')
                    .doc('app_config')
                    .snapshots(),
                builder: (c, snap) {
                  final data = snap.hasData && snap.data!.exists
                      ? snap.data!.data() as Map<String, dynamic>
                      : <String, dynamic>{};
                  final ctrl = TextEditingController(
                      text: data['groq_api_key']?.toString() ?? '');
                  return Row(children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          hintText: "gsk_xxxxxxxxxxxxxxxxxxxx",
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white),
                      onPressed: () => FirebaseFirestore.instance
                          .collection('settings')
                          .doc('app_config')
                          .set({'groq_api_key': ctrl.text.trim()},
                              SetOptions(merge: true)),
                      child: const Text("Simpan"),
                    ),
                  ]);
                },
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Reset Status`;

if (!c.includes(RESET_STATUS_MARKER)) { console.error('ERROR: marker Reset Status tidak ditemukan'); process.exit(1); }
c = c.replace(RESET_STATUS_MARKER, GROQ_KEY_CARD);
console.log('5. Groq API Key di Settings ✓');

fs.writeFileSync(mainFile, c, 'utf8');
console.log('\n✓ lib/main.dart selesai diperbarui!');
