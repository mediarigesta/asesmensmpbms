const fs   = require('fs');
const path = require('path');
const mainFile = path.join(__dirname, 'lib', 'main.dart');
let c = fs.readFileSync(mainFile, 'utf8');

// ─────────────────────────────────────────────────────────────────────────────
// 1. Ganti method parse() – tambah support multi-provider
// ─────────────────────────────────────────────────────────────────────────────
const OLD_PARSE = `  static Future<List<SoalDraft>> parse(
    String text, Map<String, String> images, String apiKey) async {
    final prompt =
      'Kamu adalah asisten yang mengekstrak soal ujian dari dokumen sekolah Indonesia. '
      'Ekstrak SEMUA soal dari teks berikut.\\n'
      'Kembalikan HANYA JSON valid, tanpa markdown, tanpa komentar.\\n\\n'
      'PENANDA KHUSUS dalam teks:\\n'
      '- [JAWABAN] di awal baris = pilihan itu adalah KUNCI JAWABAN yang benar\\n'
      '- [GAMBAR_N] = ada gambar di posisi tersebut, pertahankan teks [GAMBAR_N] di field pertanyaan\\n'
      '- [EQ: ...] = persamaan matematika → konversi ke LaTeX inline (contoh: \\\$4^{2}=16\\\$)\\n'
      '- ^{...} = superscript, _{...} = subscript → konversi ke LaTeX\\n\\n'
      'Format JSON:\\n'
      '{"soal":[{"nomor":1,"tipe":"PG","pertanyaan":"...","pilihan":["...","...","...","..."],"kunciJawaban":"A","skor":1}]}\\n\\n'
      'Aturan WAJIB:\\n'
      '1. "pertanyaan" HARUS mencakup SEMUA konteks: lead-in/instruksi, sub-poin/pernyataan bernomor, DAN kalimat pertanyaan utama — pisahkan dengan \\\\n\\n'
      '2. JANGAN potong bagian apapun dari soal; jika ada "Perhatikan ... berikut:" diikuti daftar bernomor, semua itu masuk ke "pertanyaan"\\n'
      '3. tipe: "PG" untuk Pilihan Ganda, "BS" untuk Benar/Salah, "URAIAN" untuk Essay\\n'
      '4. pilihan: teks TANPA huruf A/B/C/D di depan, array [] untuk BS dan URAIAN\\n'
      '5. kunciJawaban: ambil dari baris [JAWABAN] → "A"/"B"/"C"/"D" untuk PG; "" jika tidak ada petunjuk\\n'
      '6. Semua persamaan matematika → notasi LaTeX\\n\\n'
      'Teks dokumen:\\n$text';

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
    final jsonMatch     = RegExp(r'\\{[\\s\\S]*\\}').firstMatch(jsonStr);
    if (jsonMatch != null) jsonStr = jsonMatch.group(0)!;

    final parsed   = jsonDecode(jsonStr) as Map<String, dynamic>;
    final soalList = parsed['soal'] as List<dynamic>;`;

if (!c.includes(OLD_PARSE)) { console.error('ERROR: marker parse() tidak ditemukan'); process.exit(1); }

const NEW_PARSE = `  /// Provider yang didukung: 'groq', 'gemini', 'openrouter'
  static Future<List<SoalDraft>> parse(
    String text, Map<String, String> images, String apiKey,
    {String provider = 'groq', String model = ''}) async {
    final prompt =
      'Kamu adalah asisten yang mengekstrak soal ujian dari dokumen sekolah Indonesia. '
      'Ekstrak SEMUA soal dari teks berikut.\\n'
      'Kembalikan HANYA JSON valid, tanpa markdown, tanpa komentar.\\n\\n'
      'PENANDA KHUSUS dalam teks:\\n'
      '- [JAWABAN] di awal baris = pilihan itu adalah KUNCI JAWABAN yang benar\\n'
      '- [GAMBAR_N] = ada gambar di posisi tersebut, pertahankan teks [GAMBAR_N] di field pertanyaan\\n'
      '- [EQ: ...] = persamaan matematika \\u2192 konversi ke LaTeX inline (contoh: \\\$4^{2}=16\\\$)\\n'
      '- ^{...} = superscript, _{...} = subscript \\u2192 konversi ke LaTeX\\n\\n'
      'Format JSON:\\n'
      '{"soal":[{"nomor":1,"tipe":"PG","pertanyaan":"...","pilihan":["...","...","...","..."],"kunciJawaban":"A","skor":1}]}\\n\\n'
      'Aturan WAJIB:\\n'
      '1. "pertanyaan" HARUS mencakup SEMUA konteks: lead-in/instruksi, sub-poin/pernyataan bernomor, DAN kalimat pertanyaan utama\\n'
      '2. JANGAN potong bagian apapun dari soal\\n'
      '3. tipe: "PG" untuk Pilihan Ganda, "BS" untuk Benar/Salah, "URAIAN" untuk Essay\\n'
      '4. pilihan: teks TANPA huruf A/B/C/D di depan, array [] untuk BS dan URAIAN\\n'
      '5. kunciJawaban: ambil dari baris [JAWABAN] \\u2192 "A"/"B"/"C"/"D" untuk PG; "" jika tidak ada petunjuk\\n'
      '6. Semua persamaan matematika \\u2192 notasi LaTeX, selalu dibungkus \\\$...\\\$\\n\\n'
      'Teks dokumen:\\n$text';

    final String content;
    if (provider == 'gemini') {
      content = await _callGemini(prompt, apiKey, model);
    } else {
      content = await _callOpenAiCompat(prompt, apiKey, provider, model);
    }

    String jsonStr      = content.trim();
    final jsonMatch     = RegExp(r'\\{[\\s\\S]*\\}').firstMatch(jsonStr);
    if (jsonMatch != null) jsonStr = jsonMatch.group(0)!;

    final parsed   = jsonDecode(jsonStr) as Map<String, dynamic>;
    final soalList = parsed['soal'] as List<dynamic>;`;

c = c.replace(OLD_PARSE, NEW_PARSE);
console.log('1. parse() multi-provider ✓');

// ─────────────────────────────────────────────────────────────────────────────
// 2. Tambah helper _callOpenAiCompat & _callGemini sebelum _processEq
// ─────────────────────────────────────────────────────────────────────────────
const BEFORE_PROCESS_EQ = `  /// Konversi [EQ: ...] dan Unicode superscript/subscript ke LaTeX inline
  static String _processEq(String text) {`;

const HELPERS = `  // ── OpenAI-compatible (Groq & OpenRouter) ────────────────────────────
  static Future<String> _callOpenAiCompat(
      String prompt, String apiKey, String provider, String model) async {
    final endpoint = provider == 'openrouter'
        ? 'https://openrouter.ai/api/v1/chat/completions'
        : 'https://api.groq.com/openai/v1/chat/completions';
    final mdl = model.isNotEmpty ? model
        : provider == 'openrouter'
            ? 'google/gemini-2.0-flash-exp:free'
            : 'llama-3.3-70b-versatile';
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      if (provider == 'openrouter') 'HTTP-Referer': 'https://bm-exam.web.app',
    };
    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: jsonEncode({
        'model': mdl,
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.1,
        'max_tokens': 8000,
      }),
    ).timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error']?['message'] ?? response.body);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['choices'][0]['message']['content'] as String;
  }

  // ── Google Gemini ─────────────────────────────────────────────────────
  static Future<String> _callGemini(
      String prompt, String apiKey, String model) async {
    final mdl = model.isNotEmpty ? model : 'gemini-2.0-flash';
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/'
        '$mdl:generateContent?key=$apiKey';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{'role': 'user', 'parts': [{'text': prompt}]}],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 8000},
      }),
    ).timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(
          err['error']?['message'] ?? 'Gemini error: \${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  /// Konversi [EQ: ...] dan Unicode superscript/subscript ke LaTeX inline
  static String _processEq(String text) {`;

if (!c.includes(BEFORE_PROCESS_EQ)) { console.error('ERROR: marker _processEq tidak ditemukan'); process.exit(1); }
c = c.replace(BEFORE_PROCESS_EQ, HELPERS);
console.log('2. _callOpenAiCompat & _callGemini ✓');

// ─────────────────────────────────────────────────────────────────────────────
// 3. Update _pickDocxWithAi() — baca provider + key yang sesuai
// ─────────────────────────────────────────────────────────────────────────────
const OLD_PICK = `  Future<void> _pickDocxWithAi() async {
    // 1. Ambil API key dari Firestore
    String groqApiKey = '';
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
      groqApiKey = doc.data()?['groq_api_key']?.toString() ?? '';
    } catch (_) {}

    if (groqApiKey.isEmpty) {
      _snack('API Key Groq belum diatur. Isi di Settings → Groq API Key.', Colors.orange);
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

      // 2. Ekstrak teks + gambar dari docx
      final extracted = GroqAiParser.extractStructured(bytes);
      if (extracted.text.trim().isEmpty) {
        _snack('File tidak dapat dibaca atau kosong', Colors.red);
        setState(() => _aiParsing = false); return;
      }

      // 3. Kirim ke Groq AI
      final drafts = await GroqAiParser.parse(extracted.text, extracted.images, groqApiKey);`;

const NEW_PICK = `  Future<void> _pickDocxWithAi() async {
    // 1. Ambil provider + API key dari Firestore
    String provider = 'groq';
    String apiKey   = '';
    String aiModel  = '';
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
      final data = doc.data() ?? {};
      provider = data['ai_provider']?.toString() ?? 'groq';
      aiModel  = data['ai_model']?.toString() ?? '';
      final keyField = provider == 'gemini'      ? 'gemini_api_key'
                     : provider == 'openrouter'  ? 'openrouter_api_key'
                     : 'groq_api_key';
      apiKey = data[keyField]?.toString() ?? '';
    } catch (_) {}

    if (apiKey.isEmpty) {
      final provName = provider == 'gemini' ? 'Gemini'
                     : provider == 'openrouter' ? 'OpenRouter' : 'Groq';
      _snack('API Key $provName belum diatur. Isi di Settings → AI Provider.', Colors.orange);
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

      // 2. Ekstrak teks + gambar dari docx
      final extracted = GroqAiParser.extractStructured(bytes);
      if (extracted.text.trim().isEmpty) {
        _snack('File tidak dapat dibaca atau kosong', Colors.red);
        setState(() => _aiParsing = false); return;
      }

      // 3. Kirim ke AI
      final drafts = await GroqAiParser.parse(
          extracted.text, extracted.images, apiKey,
          provider: provider, model: aiModel);`;

if (!c.includes(OLD_PICK)) { console.error('ERROR: marker _pickDocxWithAi tidak ditemukan'); process.exit(1); }
c = c.replace(OLD_PICK, NEW_PICK);
console.log('3. _pickDocxWithAi() ✓');

// ─────────────────────────────────────────────────────────────────────────────
// 4. Ganti Settings card Groq menjadi multi-provider card
// ─────────────────────────────────────────────────────────────────────────────
const OLD_CARD_START = `      // Groq AI API Key (untuk fitur parse soal dengan AI)
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

const NEW_CARD = `      // AI Provider untuk parse soal otomatis
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              const Text("AI untuk Upload Soal",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 6),
            const Text("Pilih provider AI dan masukkan API Key untuk fitur upload soal otomatis.",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(height: 20),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('settings').doc('app_config').snapshots(),
              builder: (ctx, snap) {
                final data = snap.hasData && snap.data!.exists
                    ? snap.data!.data() as Map<String, dynamic> : <String, dynamic>{};
                final provider = data['ai_provider']?.toString() ?? 'groq';
                final keyField = provider == 'gemini'     ? 'gemini_api_key'
                               : provider == 'openrouter' ? 'openrouter_api_key'
                               : 'groq_api_key';
                final hintMap = {
                  'groq':        'gsk_xxxxxxxxxxxxxxxxxxxx',
                  'gemini':      'AIzaSyXXXXXXXXXXXXXXXXXX',
                  'openrouter':  'sk-or-v1-xxxxxxxxxxxxxxxxxxxx',
                };
                final infoMap = {
                  'groq':       '🔗 console.groq.com — Gratis, cepat (Llama 3.3 70B)',
                  'gemini':     '🔗 aistudio.google.com — Gratis, pintar (Gemini 2.0 Flash)',
                  'openrouter': '🔗 openrouter.ai — Gratis, pilihan model banyak',
                };
                final ctrl = TextEditingController(text: data[keyField]?.toString() ?? '');
                final modelCtrl = TextEditingController(text: data['ai_model']?.toString() ?? '');
                void save() {
                  FirebaseFirestore.instance.collection('settings').doc('app_config').set({
                    'ai_provider': provider,
                    keyField: ctrl.text.trim(),
                    'ai_model': modelCtrl.text.trim(),
                  }, SetOptions(merge: true));
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Provider selector
                  const Text("Provider", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _aiProviderChip('groq',       'Groq',       provider, Icons.bolt),
                    const SizedBox(width: 8),
                    _aiProviderChip('gemini',     'Gemini',     provider, Icons.stars),
                    const SizedBox(width: 8),
                    _aiProviderChip('openrouter', 'OpenRouter', provider, Icons.hub),
                  ]),
                  const SizedBox(height: 10),
                  Text(infoMap[provider] ?? '', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                  const SizedBox(height: 12),
                  // API Key
                  const Text("API Key", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          hintText: hintMap[provider] ?? '',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
                      onPressed: save,
                      child: const Text("Simpan"),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // Model override (opsional)
                  const Text("Model (opsional, kosongkan = default)",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: modelCtrl,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      hintText: provider == 'gemini' ? 'gemini-2.0-flash'
                               : provider == 'openrouter' ? 'google/gemini-2.0-flash-exp:free'
                               : 'llama-3.3-70b-versatile',
                      prefixIcon: const Icon(Icons.memory_outlined),
                    ),
                    onSubmitted: (_) => save(),
                  ),
                ]);
              },
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),

      // Reset Status`;

if (!c.includes(OLD_CARD_START)) { console.error('ERROR: marker Settings card tidak ditemukan'); process.exit(1); }
c = c.replace(OLD_CARD_START, NEW_CARD);
console.log('4. Settings AI Provider card ✓');

fs.writeFileSync(mainFile, c, 'utf8');
console.log('\n✓ lib/main.dart selesai diperbarui!');
