part of '../main.dart';

// ============================================================
// HELPER: Strip [GAMBAR_N] tag dari teks untuk display
// ============================================================
String _stripGambarTag(String text) {
  return text.replaceAll(RegExp(r'\[GAMBAR_\d+\]\s*'), '').trim();
}

// ============================================================
// HELPER: Render text with inline LaTeX
// ============================================================
Widget _buildTextWithLatex(String text, double fontSize) {
  // Hapus tag [GAMBAR_N] dari teks yang ditampilkan
  text = _stripGambarTag(text);
  // Pastikan semua equation (^{...}, _{...}, [EQ:...], Unicode superscript) ter-wrap $...$
  text = DocxLocalParser._processEq(text);
  // Detect LaTeX: $...$
  final parts = <InlineSpan>[];
  final latexReg = RegExp(r'\$([^$]+)\$');
  int lastEnd = 0;
  for (final m in latexReg.allMatches(text)) {
    if (m.start > lastEnd) {
      parts.add(TextSpan(text: text.substring(lastEnd, m.start),
          style: TextStyle(fontSize: fontSize, color: const Color(0xFF1E293B))));
    }
    parts.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Math.tex(
        m.group(1)!,
        textStyle: TextStyle(fontSize: fontSize),
        onErrorFallback: (e) => Text(m.group(0)!, style: TextStyle(fontSize: fontSize, color: Colors.red)),
      ),
    ));
    lastEnd = m.end;
  }
  if (lastEnd < text.length) {
    parts.add(TextSpan(text: text.substring(lastEnd),
        style: TextStyle(fontSize: fontSize, color: const Color(0xFF1E293B))));
  }
  if (parts.isEmpty) {
    return Text(text, style: TextStyle(fontSize: fontSize, color: const Color(0xFF1E293B)));
  }
  return Text.rich(TextSpan(children: parts));
}

// ============================================================
// HELPER: Gambar soal responsif + long-press zoom overlay
// ============================================================
Widget _buildZoomableImage(Uint8List imageBytes, BuildContext context) {
  final screenH = MediaQuery.of(context).size.height;
  final screenW = MediaQuery.of(context).size.width;
  // Batasi tinggi gambar: 30% layar di mobile, 40% di web/desktop
  final maxImgH = kIsWeb || isWindows ? screenH * 0.40 : screenH * 0.30;
  // Lebar maksimal: 90% lebar parent atau 500px (mana yang lebih kecil)
  final maxImgW = screenW > 600 ? 500.0 : screenW * 0.90;
  return LayoutBuilder(
    builder: (ctx, constraints) {
      final effectiveW = constraints.maxWidth < maxImgW ? constraints.maxWidth : maxImgW;
      return GestureDetector(
        onLongPress: () {
          _showImageZoomOverlay(context, imageBytes);
        },
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: effectiveW, maxHeight: maxImgH),
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showImageZoomOverlay(BuildContext context, Uint8List imageBytes) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      pageBuilder: (_, __, ___) => _ImageZoomOverlay(imageBytes: imageBytes),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 200),
    ),
  );
}

class _ImageZoomOverlay extends StatelessWidget {
  final Uint8List imageBytes;
  const _ImageZoomOverlay({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // Tap area untuk menutup
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(color: Colors.transparent),
        ),
        // Gambar yang bisa di-zoom
        Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        // Tombol tutup
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 16,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
        // Hint text
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          left: 0, right: 0,
          child: const Center(
            child: Text("Pinch untuk zoom • Ketuk untuk menutup",
              style: TextStyle(color: Colors.white60, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// GLOBAL THEME SWITCHER WIDGET
// ============================================================
/// Chip pemilih AI provider di Settings
Widget _aiProviderChip(String value, String label, String current, IconData icon) {
  final selected = value == current;
  return GestureDetector(
    onTap: () => FirebaseFirestore.instance
        .collection('settings')
        .doc('app_config')
        .set({'ai_provider': value}, SetOptions(merge: true)),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.purple.shade700 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? Colors.purple.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14,
            color: selected ? Colors.white : Colors.grey.shade600),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey.shade700,
            )),
      ]),
    ),
  );
}

Widget _buildThemeSwitcher() {
  return StatefulBuilder(
    builder: (ctx, setSt) {
      final themes = BMTheme.values;
      final themeColors = {
        BMTheme.navy:   const Color(0xFF0D1117),
        BMTheme.dark:   const Color(0xFF000000),
        BMTheme.ocean:  const Color(0xFF0C1A3E),
        BMTheme.forest: const Color(0xFF0A1F12),
        BMTheme.purple: const Color(0xFF130A2A),
        BMTheme.rose:   const Color(0xFF1A0510),
      };
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.palette_outlined, size: 16, color: Colors.grey),
              SizedBox(width: 6),
              Text('Tema Aplikasi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            ]),
            const SizedBox(height: 8),
            ValueListenableBuilder<BMTheme>(
              valueListenable: _themeNotifier,
              builder: (_, current, __) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: themes.map((t) {
                  final isSelected = current == t;
                  return GestureDetector(
                    onTap: () async {
                      _themeNotifier.value = t;
                      setSt(() {});
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('app_theme', t.name);
                    },
                    child: Tooltip(
                      message: BMThemePresets.name(t),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: themeColors[t],
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : Border.all(color: Colors.transparent, width: 2),
                          boxShadow: isSelected
                              ? [BoxShadow(color: themeColors[t]!.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
