const fs   = require('fs');
const path = require('path');

const mainFile      = path.join(__dirname, 'lib', 'main.dart');
const snippetFile   = path.join(__dirname, 'groq_class_v2.dart');

let c          = fs.readFileSync(mainFile,    'utf8');
const newClass = fs.readFileSync(snippetFile, 'utf8').trim();

// ─────────────────────────────────────────────────────────────────────────────
// 1. Ganti seluruh class GroqAiParser dengan versi baru
// ─────────────────────────────────────────────────────────────────────────────
const OLD_CLASS_START = 'class GroqAiParser {';
const OLD_CLASS_STOP  = '\nclass SoalModel {';

const startIdx = c.indexOf(OLD_CLASS_START);
if (startIdx === -1) { console.error('ERROR: class GroqAiParser tidak ditemukan'); process.exit(1); }

const endIdx = c.indexOf(OLD_CLASS_STOP, startIdx);
if (endIdx === -1) { console.error('ERROR: class SoalModel tidak ditemukan setelah GroqAiParser'); process.exit(1); }

c = c.substring(0, startIdx) + newClass + '\n' + c.substring(endIdx + 1);
console.log('1. GroqAiParser class v2 ✓');

// ─────────────────────────────────────────────────────────────────────────────
// 2. Update _pickDocxWithAi() — ganti extractText → extractStructured
// ─────────────────────────────────────────────────────────────────────────────
const OLD_EXTRACT = `      // 2. Ekstrak teks dari docx
      final rawText = GroqAiParser.extractText(bytes);
      if (rawText.trim().isEmpty) {
        _snack('File tidak dapat dibaca atau kosong', Colors.red);
        setState(() => _aiParsing = false); return;
      }

      // 3. Kirim ke Groq AI
      final drafts = await GroqAiParser.parse(rawText, groqApiKey);`;

const NEW_EXTRACT = `      // 2. Ekstrak teks + gambar dari docx
      final extracted = GroqAiParser.extractStructured(bytes);
      if (extracted.text.trim().isEmpty) {
        _snack('File tidak dapat dibaca atau kosong', Colors.red);
        setState(() => _aiParsing = false); return;
      }

      // 3. Kirim ke Groq AI
      final drafts = await GroqAiParser.parse(extracted.text, extracted.images, groqApiKey);`;

if (!c.includes(OLD_EXTRACT)) { console.error('ERROR: marker _pickDocxWithAi body tidak ditemukan'); process.exit(1); }
c = c.replace(OLD_EXTRACT, NEW_EXTRACT);
console.log('2. _pickDocxWithAi() updated ✓');

// ─────────────────────────────────────────────────────────────────────────────
fs.writeFileSync(mainFile, c, 'utf8');
console.log('\n✓ lib/main.dart selesai diperbarui!');
