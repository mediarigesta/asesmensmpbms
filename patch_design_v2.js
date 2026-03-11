const fs = require('fs');
const path = require('path');
const mainFile = path.join(__dirname, 'lib', 'main.dart');
let c = fs.readFileSync(mainFile, 'utf8');

// ─────────────────────────────────────────────────────────────────────────────
// 1. Add dart:ui import
// ─────────────────────────────────────────────────────────────────────────────
const OLD_IMPORT = "import 'dart:async';";
const NEW_IMPORT = "import 'dart:async';\nimport 'dart:ui' as ui;";
if (!c.includes("import 'dart:ui'")) {
  if (!c.includes(OLD_IMPORT)) { console.error('ERROR: dart:async import not found'); process.exit(1); }
  c = c.replace(OLD_IMPORT, NEW_IMPORT);
  console.log('1. dart:ui import added');
} else {
  console.log('1. dart:ui already imported, skip');
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Update theme color presets (deeper, more dramatic)
// ─────────────────────────────────────────────────────────────────────────────
const OLD_PRESETS =
  "    BMTheme.navy:   BMColors(primary: Color(0xFF0F172A), gradient2: Color(0xFF1E3A5F), surface: Color(0xFFF1F5F9), cardBg: Colors.white),\n" +
  "    BMTheme.dark:   BMColors(primary: Color(0xFF1E293B), gradient2: Color(0xFF0F172A), surface: Color(0xFF0F172A), cardBg: Color(0xFF1E293B)),\n" +
  "    BMTheme.ocean:  BMColors(primary: Color(0xFF0369A1), gradient2: Color(0xFF0284C7), surface: Color(0xFFF1F5F9), cardBg: Colors.white),\n" +
  "    BMTheme.forest: BMColors(primary: Color(0xFF166534), gradient2: Color(0xFF15803D), surface: Color(0xFFF1F5F9), cardBg: Colors.white),\n" +
  "    BMTheme.purple: BMColors(primary: Color(0xFF6B21A8), gradient2: Color(0xFF7E22CE), surface: Color(0xFFF1F5F9), cardBg: Colors.white),\n" +
  "    BMTheme.rose:   BMColors(primary: Color(0xFF9F1239), gradient2: Color(0xFFBE123C), surface: Color(0xFFF1F5F9), cardBg: Colors.white),";

const NEW_PRESETS =
  "    BMTheme.navy:   BMColors(primary: Color(0xFF0D1117), gradient2: Color(0xFF1C2A4A), surface: Color(0xFFF1F5F9), cardBg: Colors.white),\n" +
  "    BMTheme.dark:   BMColors(primary: Color(0xFF000000), gradient2: Color(0xFF0F0F1A), surface: Color(0xFF0F172A), cardBg: Color(0xFF1E293B)),\n" +
  "    BMTheme.ocean:  BMColors(primary: Color(0xFF0C1A3E), gradient2: Color(0xFF0E3460), surface: Color(0xFFF1F5F9), cardBg: Colors.white),\n" +
  "    BMTheme.forest: BMColors(primary: Color(0xFF0A1F12), gradient2: Color(0xFF0E3A1C), surface: Color(0xFFF1F5F9), cardBg: Colors.white),\n" +
  "    BMTheme.purple: BMColors(primary: Color(0xFF130A2A), gradient2: Color(0xFF2D1554), surface: Color(0xFFF1F5F9), cardBg: Colors.white),\n" +
  "    BMTheme.rose:   BMColors(primary: Color(0xFF1A0510), gradient2: Color(0xFF3D0A20), surface: Color(0xFFF1F5F9), cardBg: Colors.white),";

if (!c.includes(OLD_PRESETS)) { console.error('ERROR: theme presets not found'); process.exit(1); }
c = c.replace(OLD_PRESETS, NEW_PRESETS);
console.log('2. Theme color presets updated');

// ─────────────────────────────────────────────────────────────────────────────
// 3. Update theme names
// ─────────────────────────────────────────────────────────────────────────────
const OLD_NAMES =
  "    BMTheme.navy:   'Navy (Default)',\n" +
  "    BMTheme.dark:   'Dark Mode',\n" +
  "    BMTheme.ocean:  'Ocean Blue',\n" +
  "    BMTheme.forest: 'Forest Green',\n" +
  "    BMTheme.purple: 'Royal Purple',\n" +
  "    BMTheme.rose:   'Deep Rose',";

const NEW_NAMES =
  "    BMTheme.navy:   'Void Dark',\n" +
  "    BMTheme.dark:   'Pure Black',\n" +
  "    BMTheme.ocean:  'Deep Ocean',\n" +
  "    BMTheme.forest: 'Dark Forest',\n" +
  "    BMTheme.purple: 'Cosmic Purple',\n" +
  "    BMTheme.rose:   'Blood Rose',";

if (!c.includes(OLD_NAMES)) { console.error('ERROR: theme names not found'); process.exit(1); }
c = c.replace(OLD_NAMES, NEW_NAMES);
console.log('3. Theme names updated');

// ─────────────────────────────────────────────────────────────────────────────
// 4. Redesign SplashScreen build()
// ─────────────────────────────────────────────────────────────────────────────
const OLD_SPLASH =
  "  @override\n" +
  "  Widget build(BuildContext context) => Scaffold(\n" +
  "    backgroundColor: BMThemePresets.colors(_themeNotifier.value).primary,\n" +
  "    body: FadeTransition(\n" +
  "      opacity: _fade,\n" +
  "      child: Center(\n" +
  "        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [\n" +
  "          Container(\n" +
  "            width: 180,\n" +
  "            height: 180,\n" +
  "            decoration: BoxDecoration(\n" +
  "              shape: BoxShape.circle,\n" +
  "              border: Border.all(color: Colors.white24, width: 1.5),\n" +
  "            ),\n" +
  "            padding: const EdgeInsets.all(10),\n" +
  "            child: Image.asset('assets/logo.png', width: 160, height: 160),\n" +
  "          ),\n" +
  "          const SizedBox(height: 20),\n" +
  "          Text(\"Budi Mulia Exam\",\n" +
  "              style: TextStyle(\n" +
  "                  color: Colors.white,\n" +
  "                  fontSize: 28,\n" +
  "                  fontWeight: FontWeight.bold,\n" +
  "                  letterSpacing: 2)),\n" +
  "          const SizedBox(height: 6),\n" +
  "          Text(\"SMP Budi Mulia Jakarta\",\n" +
  "              style: TextStyle(color: Colors.white54, fontSize: 14)),\n" +
  "          const SizedBox(height: 44),\n" +
  "          const SizedBox(\n" +
  "            width: 24,\n" +
  "            height: 24,\n" +
  "            child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),\n" +
  "          ),\n" +
  "        ]),\n" +
  "      ),\n" +
  "    ),\n" +
  "  );";

const NEW_SPLASH =
  "  @override\n" +
  "  Widget build(BuildContext context) {\n" +
  "    final col = BMThemePresets.colors(_themeNotifier.value);\n" +
  "    return Scaffold(\n" +
  "      backgroundColor: col.primary,\n" +
  "      body: Stack(\n" +
  "        children: [\n" +
  "          // Radial gradient bg\n" +
  "          Positioned.fill(\n" +
  "            child: Container(\n" +
  "              decoration: BoxDecoration(\n" +
  "                gradient: RadialGradient(\n" +
  "                  center: Alignment.center,\n" +
  "                  radius: 1.4,\n" +
  "                  colors: [col.gradient2, col.primary, col.primary],\n" +
  "                  stops: const [0.0, 0.55, 1.0],\n" +
  "                ),\n" +
  "              ),\n" +
  "            ),\n" +
  "          ),\n" +
  "          // Orb glow top-right\n" +
  "          Positioned(\n" +
  "            top: -120, right: -100,\n" +
  "            child: Container(\n" +
  "              width: 420, height: 420,\n" +
  "              decoration: BoxDecoration(\n" +
  "                shape: BoxShape.circle,\n" +
  "                gradient: RadialGradient(\n" +
  "                  colors: [col.gradient2.withValues(alpha: 0.28), Colors.transparent],\n" +
  "                ),\n" +
  "              ),\n" +
  "            ),\n" +
  "          ),\n" +
  "          // Orb glow bottom-left\n" +
  "          Positioned(\n" +
  "            bottom: -100, left: -80,\n" +
  "            child: Container(\n" +
  "              width: 360, height: 360,\n" +
  "              decoration: BoxDecoration(\n" +
  "                shape: BoxShape.circle,\n" +
  "                gradient: RadialGradient(\n" +
  "                  colors: [col.gradient2.withValues(alpha: 0.18), Colors.transparent],\n" +
  "                ),\n" +
  "              ),\n" +
  "            ),\n" +
  "          ),\n" +
  "          // Main content\n" +
  "          FadeTransition(\n" +
  "            opacity: _fade,\n" +
  "            child: Center(\n" +
  "              child: Column(\n" +
  "                mainAxisAlignment: MainAxisAlignment.center,\n" +
  "                children: [\n" +
  "                  // Glowing logo\n" +
  "                  Container(\n" +
  "                    width: 130, height: 130,\n" +
  "                    decoration: BoxDecoration(\n" +
  "                      shape: BoxShape.circle,\n" +
  "                      gradient: RadialGradient(\n" +
  "                        colors: [\n" +
  "                          col.gradient2.withValues(alpha: 0.55),\n" +
  "                          col.primary.withValues(alpha: 0.1),\n" +
  "                        ],\n" +
  "                      ),\n" +
  "                      boxShadow: [\n" +
  "                        BoxShadow(\n" +
  "                          color: col.gradient2.withValues(alpha: 0.55),\n" +
  "                          blurRadius: 60, spreadRadius: 6,\n" +
  "                        ),\n" +
  "                      ],\n" +
  "                      border: Border.all(\n" +
  "                        color: Colors.white.withValues(alpha: 0.12), width: 1.5,\n" +
  "                      ),\n" +
  "                    ),\n" +
  "                    padding: const EdgeInsets.all(16),\n" +
  "                    child: Image.asset('assets/logo.png'),\n" +
  "                  ),\n" +
  "                  const SizedBox(height: 30),\n" +
  "                  // Gradient title\n" +
  "                  ShaderMask(\n" +
  "                    shaderCallback: (b) => const LinearGradient(\n" +
  "                      colors: [Colors.white, Color(0xFFB0C4DE)],\n" +
  "                      begin: Alignment.topCenter,\n" +
  "                      end: Alignment.bottomCenter,\n" +
  "                    ).createShader(b),\n" +
  "                    child: const Text(\n" +
  "                      'BUDI MULIA EXAM',\n" +
  "                      style: TextStyle(\n" +
  "                        color: Colors.white,\n" +
  "                        fontSize: 24,\n" +
  "                        fontWeight: FontWeight.w800,\n" +
  "                        letterSpacing: 4,\n" +
  "                      ),\n" +
  "                    ),\n" +
  "                  ),\n" +
  "                  const SizedBox(height: 8),\n" +
  "                  Text(\n" +
  "                    'SMP BUDI MULIA JAKARTA',\n" +
  "                    style: TextStyle(\n" +
  "                      color: Colors.white.withValues(alpha: 0.35),\n" +
  "                      fontSize: 11,\n" +
  "                      letterSpacing: 3,\n" +
  "                      fontWeight: FontWeight.w500,\n" +
  "                    ),\n" +
  "                  ),\n" +
  "                  const SizedBox(height: 64),\n" +
  "                  // Slim shimmer bar\n" +
  "                  Container(\n" +
  "                    width: 100, height: 2,\n" +
  "                    decoration: BoxDecoration(\n" +
  "                      color: Colors.white.withValues(alpha: 0.1),\n" +
  "                      borderRadius: BorderRadius.circular(2),\n" +
  "                    ),\n" +
  "                    child: LinearProgressIndicator(\n" +
  "                      backgroundColor: Colors.transparent,\n" +
  "                      color: Colors.white.withValues(alpha: 0.5),\n" +
  "                      minHeight: 2,\n" +
  "                    ),\n" +
  "                  ),\n" +
  "                ],\n" +
  "              ),\n" +
  "            ),\n" +
  "          ),\n" +
  "        ],\n" +
  "      ),\n" +
  "    );\n" +
  "  }";

if (!c.includes(OLD_SPLASH)) { console.error('ERROR: SplashScreen build not found'); process.exit(1); }
c = c.replace(OLD_SPLASH, NEW_SPLASH);
console.log('4. SplashScreen redesigned');

// ─────────────────────────────────────────────────────────────────────────────
// 5. Redesign LoginScreen build()
// ─────────────────────────────────────────────────────────────────────────────
const OLD_LOGIN_START =
  "  @override\n" +
  "  Widget build(BuildContext context) => Scaffold(\n" +
  "    backgroundColor: BMThemePresets.colors(_themeNotifier.value).primary,\n" +
  "    body: Center(\n" +
  "      child: SingleChildScrollView(\n" +
  "        child: Column(\n" +
  "          mainAxisAlignment: MainAxisAlignment.center,\n" +
  "          children: [\n" +
  "            Image.asset('assets/logo.png', width: 130, height: 130),\n" +
  "            const SizedBox(height: 10),\n" +
  "            const Text(\"Budi Mulia Exam\",\n" +
  "                style: TextStyle(\n" +
  "                    color: Colors.white,\n" +
  "                    fontSize: 26,\n" +
  "                    fontWeight: FontWeight.bold)),\n" +
  "            const Text(\"SMP Budi Mulia Jakarta\",\n" +
  "                style: TextStyle(color: Colors.white54, fontSize: 13)),\n" +
  "            const SizedBox(height: 40),\n" +
  "\n" +
  "            // Card Login\n" +
  "            Container(\n" +
  "              constraints: const BoxConstraints(maxWidth: 480),\n" +
  "              width: double.infinity,\n" +
  "              margin: const EdgeInsets.symmetric(horizontal: 24),\n" +
  "              padding: const EdgeInsets.all(28),\n" +
  "              decoration: BoxDecoration(\n" +
  "                color: Colors.white,\n" +
  "                borderRadius: BorderRadius.circular(24),\n" +
  "                boxShadow: [\n" +
  "                  BoxShadow(\n" +
  "                      color: Colors.black.withValues(alpha: 0.15),\n" +
  "                      blurRadius: 30,\n" +
  "                      spreadRadius: 0,\n" +
  "                      offset: const Offset(0, 8)),\n" +
  "                  BoxShadow(\n" +
  "                      color: Colors.black.withValues(alpha: 0.08),\n" +
  "                      blurRadius: 8,\n" +
  "                      spreadRadius: 0,\n" +
  "                      offset: const Offset(0, 2)),\n" +
  "                ],\n" +
  "              ),\n" +
  "              child: Column(children: [\n" +
  "                const Text(\"Masuk ke Akun\",\n" +
  "                    style: TextStyle(\n" +
  "                        fontSize: 18, fontWeight: FontWeight.bold)),\n" +
  "                const SizedBox(height: 6),\n" +
  "                const Text(\"Silakan masukkan kredensial Anda\",\n" +
  "                    style: TextStyle(color: Colors.grey, fontSize: 12)),\n" +
  "                const SizedBox(height: 24),\n" +
  "                TextField(\n" +
  "                  controller: _u,\n" +
  "                  decoration: InputDecoration(\n" +
  "                    labelText: \"Username\",\n" +
  "                    border: OutlineInputBorder(\n" +
  "                        borderRadius: BorderRadius.circular(10)),\n" +
  "                    prefixIcon: const Icon(Icons.person_outline),\n" +
  "                    filled: true,\n" +
  "                    fillColor: Colors.grey.shade50,\n" +
  "                  ),\n" +
  "                ),\n" +
  "                const SizedBox(height: 14),\n" +
  "                TextField(\n" +
  "                  controller: _p,\n" +
  "                  obscureText: _obscure,\n" +
  "                  decoration: InputDecoration(\n" +
  "                    labelText: \"Password\",\n" +
  "                    border: OutlineInputBorder(\n" +
  "                        borderRadius: BorderRadius.circular(10)),\n" +
  "                    prefixIcon: const Icon(Icons.lock_outline),\n" +
  "                    filled: true,\n" +
  "                    fillColor: Colors.grey.shade50,\n" +
  "                    suffixIcon: IconButton(\n" +
  "                      icon: Icon(_obscure\n" +
  "                          ? Icons.visibility_off\n" +
  "                          : Icons.visibility),\n" +
  "                      onPressed: () =>\n" +
  "                          setState(() => _obscure = !_obscure),\n" +
  "                    ),\n" +
  "                  ),\n" +
  "                ),\n" +
  "                const SizedBox(height: 12),\n" +
  "                // Remember Me row\n" +
  "                Row(\n" +
  "                  children: [\n" +
  "                    SizedBox(\n" +
  "                      width: 24,\n" +
  "                      height: 24,\n" +
  "                      child: Checkbox(\n" +
  "                        value: _rememberMe,\n" +
  "                        onChanged: (v) => setState(() => _rememberMe = v ?? false),\n" +
  "                        activeColor: const Color(0xFF0F172A),\n" +
  "                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),\n" +
  "                      ),\n" +
  "                    ),\n" +
  "                    const SizedBox(width: 8),\n" +
  "                    const Text(\"Ingat Saya\",\n" +
  "                        style: TextStyle(fontSize: 13, color: Colors.black87)),\n" +
  "                  ],\n" +
  "                ),\n" +
  "                const SizedBox(height: 20),\n" +
  "                SizedBox(\n" +
  "                  width: double.infinity,\n" +
  "                  height: 50,\n" +
  "                  child: ElevatedButton(\n" +
  "                    style: ElevatedButton.styleFrom(\n" +
  "                      backgroundColor: BMThemePresets.colors(_themeNotifier.value).primary,\n" +
  "                      foregroundColor: Colors.white,\n" +
  "                      shape: RoundedRectangleBorder(\n" +
  "                          borderRadius: BorderRadius.circular(10)),\n" +
  "                    ),\n" +
  "                    onPressed: _loading ? null : _login,\n" +
  "                    child: _loading\n" +
  "                        ? const SizedBox(\n" +
  "                        width: 22,\n" +
  "                        height: 22,\n" +
  "                        child: CircularProgressIndicator(\n" +
  "                            color: Colors.white, strokeWidth: 2))\n" +
  "                        : const Text(\"MASUK\",\n" +
  "                        style: TextStyle(\n" +
  "                            fontSize: 15,\n" +
  "                            fontWeight: FontWeight.bold,\n" +
  "                            letterSpacing: 1)),\n" +
  "                  ),\n" +
  "                ),\n" +
  "              ]),\n" +
  "            ),\n" +
  "          ],\n" +
  "        ),\n" +
  "      ),\n" +
  "    ),\n" +
  "  );";

const NEW_LOGIN =
  "  @override\n" +
  "  Widget build(BuildContext context) {\n" +
  "    final col = BMThemePresets.colors(_themeNotifier.value);\n" +
  "    return Scaffold(\n" +
  "      backgroundColor: col.primary,\n" +
  "      body: Stack(\n" +
  "        children: [\n" +
  "          // ── Gradient background ──────────────────────────────────\n" +
  "          Positioned.fill(\n" +
  "            child: Container(\n" +
  "              decoration: BoxDecoration(\n" +
  "                gradient: LinearGradient(\n" +
  "                  begin: Alignment.topLeft,\n" +
  "                  end: Alignment.bottomRight,\n" +
  "                  colors: [col.primary, col.gradient2, col.primary],\n" +
  "                  stops: const [0.0, 0.5, 1.0],\n" +
  "                ),\n" +
  "              ),\n" +
  "            ),\n" +
  "          ),\n" +
  "          // ── Orb top-right ────────────────────────────────────────\n" +
  "          Positioned(\n" +
  "            top: -100, right: -80,\n" +
  "            child: Container(\n" +
  "              width: 360, height: 360,\n" +
  "              decoration: BoxDecoration(\n" +
  "                shape: BoxShape.circle,\n" +
  "                gradient: RadialGradient(\n" +
  "                  colors: [col.gradient2.withValues(alpha: 0.45), Colors.transparent],\n" +
  "                ),\n" +
  "              ),\n" +
  "            ),\n" +
  "          ),\n" +
  "          // ── Orb bottom-left ──────────────────────────────────────\n" +
  "          Positioned(\n" +
  "            bottom: -110, left: -90,\n" +
  "            child: Container(\n" +
  "              width: 400, height: 400,\n" +
  "              decoration: BoxDecoration(\n" +
  "                shape: BoxShape.circle,\n" +
  "                gradient: RadialGradient(\n" +
  "                  colors: [col.gradient2.withValues(alpha: 0.25), Colors.transparent],\n" +
  "                ),\n" +
  "              ),\n" +
  "            ),\n" +
  "          ),\n" +
  "          // ── Content ──────────────────────────────────────────────\n" +
  "          Center(\n" +
  "            child: SingleChildScrollView(\n" +
  "              padding: const EdgeInsets.symmetric(vertical: 48),\n" +
  "              child: Column(\n" +
  "                mainAxisAlignment: MainAxisAlignment.center,\n" +
  "                children: [\n" +
  "                  // Logo with glow\n" +
  "                  Container(\n" +
  "                    width: 88, height: 88,\n" +
  "                    decoration: BoxDecoration(\n" +
  "                      shape: BoxShape.circle,\n" +
  "                      gradient: RadialGradient(\n" +
  "                        colors: [\n" +
  "                          col.gradient2.withValues(alpha: 0.6),\n" +
  "                          col.primary.withValues(alpha: 0.2),\n" +
  "                        ],\n" +
  "                      ),\n" +
  "                      boxShadow: [\n" +
  "                        BoxShadow(\n" +
  "                          color: col.gradient2.withValues(alpha: 0.6),\n" +
  "                          blurRadius: 40, spreadRadius: 4,\n" +
  "                        ),\n" +
  "                      ],\n" +
  "                      border: Border.all(\n" +
  "                        color: Colors.white.withValues(alpha: 0.15), width: 1,\n" +
  "                      ),\n" +
  "                    ),\n" +
  "                    padding: const EdgeInsets.all(12),\n" +
  "                    child: Image.asset('assets/logo.png'),\n" +
  "                  ),\n" +
  "                  const SizedBox(height: 18),\n" +
  "                  ShaderMask(\n" +
  "                    shaderCallback: (b) => const LinearGradient(\n" +
  "                      colors: [Colors.white, Color(0xFFCDD9F0)],\n" +
  "                      begin: Alignment.topCenter,\n" +
  "                      end: Alignment.bottomCenter,\n" +
  "                    ).createShader(b),\n" +
  "                    child: const Text(\n" +
  "                      'BUDI MULIA EXAM',\n" +
  "                      style: TextStyle(\n" +
  "                        color: Colors.white,\n" +
  "                        fontSize: 20,\n" +
  "                        fontWeight: FontWeight.w800,\n" +
  "                        letterSpacing: 3,\n" +
  "                      ),\n" +
  "                    ),\n" +
  "                  ),\n" +
  "                  const SizedBox(height: 4),\n" +
  "                  Text(\n" +
  "                    'SMP Budi Mulia Jakarta',\n" +
  "                    style: TextStyle(\n" +
  "                      color: Colors.white.withValues(alpha: 0.38),\n" +
  "                      fontSize: 12,\n" +
  "                      letterSpacing: 1.5,\n" +
  "                    ),\n" +
  "                  ),\n" +
  "                  const SizedBox(height: 36),\n" +
  "                  // ── Glass card ──────────────────────────────────\n" +
  "                  Container(\n" +
  "                    constraints: const BoxConstraints(maxWidth: 440),\n" +
  "                    margin: const EdgeInsets.symmetric(horizontal: 20),\n" +
  "                    child: ClipRRect(\n" +
  "                      borderRadius: BorderRadius.circular(28),\n" +
  "                      child: BackdropFilter(\n" +
  "                        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),\n" +
  "                        child: Container(\n" +
  "                          decoration: BoxDecoration(\n" +
  "                            color: Colors.white.withValues(alpha: 0.09),\n" +
  "                            borderRadius: BorderRadius.circular(28),\n" +
  "                            border: Border.all(\n" +
  "                              color: Colors.white.withValues(alpha: 0.15),\n" +
  "                              width: 1.5,\n" +
  "                            ),\n" +
  "                          ),\n" +
  "                          padding: const EdgeInsets.all(28),\n" +
  "                          child: Column(\n" +
  "                            crossAxisAlignment: CrossAxisAlignment.start,\n" +
  "                            children: [\n" +
  "                              const Text(\n" +
  "                                'Selamat Datang',\n" +
  "                                style: TextStyle(\n" +
  "                                  color: Colors.white,\n" +
  "                                  fontSize: 22,\n" +
  "                                  fontWeight: FontWeight.bold,\n" +
  "                                ),\n" +
  "                              ),\n" +
  "                              const SizedBox(height: 4),\n" +
  "                              Text(\n" +
  "                                'Masuk untuk melanjutkan',\n" +
  "                                style: TextStyle(\n" +
  "                                  color: Colors.white.withValues(alpha: 0.45),\n" +
  "                                  fontSize: 13,\n" +
  "                                ),\n" +
  "                              ),\n" +
  "                              const SizedBox(height: 28),\n" +
  "                              // Username\n" +
  "                              TextField(\n" +
  "                                controller: _u,\n" +
  "                                style: const TextStyle(color: Colors.white),\n" +
  "                                decoration: InputDecoration(\n" +
  "                                  labelText: 'Username',\n" +
  "                                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),\n" +
  "                                  prefixIcon: Icon(Icons.person_outline,\n" +
  "                                      color: Colors.white.withValues(alpha: 0.45)),\n" +
  "                                  filled: true,\n" +
  "                                  fillColor: Colors.white.withValues(alpha: 0.07),\n" +
  "                                  border: OutlineInputBorder(\n" +
  "                                    borderRadius: BorderRadius.circular(14),\n" +
  "                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),\n" +
  "                                  ),\n" +
  "                                  enabledBorder: OutlineInputBorder(\n" +
  "                                    borderRadius: BorderRadius.circular(14),\n" +
  "                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),\n" +
  "                                  ),\n" +
  "                                  focusedBorder: OutlineInputBorder(\n" +
  "                                    borderRadius: BorderRadius.circular(14),\n" +
  "                                    borderSide: const BorderSide(color: Colors.white54, width: 1.5),\n" +
  "                                  ),\n" +
  "                                ),\n" +
  "                              ),\n" +
  "                              const SizedBox(height: 14),\n" +
  "                              // Password\n" +
  "                              TextField(\n" +
  "                                controller: _p,\n" +
  "                                obscureText: _obscure,\n" +
  "                                style: const TextStyle(color: Colors.white),\n" +
  "                                decoration: InputDecoration(\n" +
  "                                  labelText: 'Password',\n" +
  "                                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),\n" +
  "                                  prefixIcon: Icon(Icons.lock_outline,\n" +
  "                                      color: Colors.white.withValues(alpha: 0.45)),\n" +
  "                                  suffixIcon: IconButton(\n" +
  "                                    icon: Icon(\n" +
  "                                      _obscure ? Icons.visibility_off : Icons.visibility,\n" +
  "                                      color: Colors.white38,\n" +
  "                                    ),\n" +
  "                                    onPressed: () => setState(() => _obscure = !_obscure),\n" +
  "                                  ),\n" +
  "                                  filled: true,\n" +
  "                                  fillColor: Colors.white.withValues(alpha: 0.07),\n" +
  "                                  border: OutlineInputBorder(\n" +
  "                                    borderRadius: BorderRadius.circular(14),\n" +
  "                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),\n" +
  "                                  ),\n" +
  "                                  enabledBorder: OutlineInputBorder(\n" +
  "                                    borderRadius: BorderRadius.circular(14),\n" +
  "                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),\n" +
  "                                  ),\n" +
  "                                  focusedBorder: OutlineInputBorder(\n" +
  "                                    borderRadius: BorderRadius.circular(14),\n" +
  "                                    borderSide: const BorderSide(color: Colors.white54, width: 1.5),\n" +
  "                                  ),\n" +
  "                                ),\n" +
  "                              ),\n" +
  "                              const SizedBox(height: 16),\n" +
  "                              // Remember Me\n" +
  "                              Row(\n" +
  "                                children: [\n" +
  "                                  SizedBox(\n" +
  "                                    width: 22, height: 22,\n" +
  "                                    child: Checkbox(\n" +
  "                                      value: _rememberMe,\n" +
  "                                      onChanged: (v) => setState(() => _rememberMe = v ?? false),\n" +
  "                                      activeColor: Colors.white,\n" +
  "                                      checkColor: col.primary,\n" +
  "                                      side: const BorderSide(color: Colors.white38),\n" +
  "                                      shape: RoundedRectangleBorder(\n" +
  "                                          borderRadius: BorderRadius.circular(4)),\n" +
  "                                    ),\n" +
  "                                  ),\n" +
  "                                  const SizedBox(width: 8),\n" +
  "                                  Text(\n" +
  "                                    'Ingat Saya',\n" +
  "                                    style: TextStyle(\n" +
  "                                      color: Colors.white.withValues(alpha: 0.65),\n" +
  "                                      fontSize: 13,\n" +
  "                                    ),\n" +
  "                                  ),\n" +
  "                                ],\n" +
  "                              ),\n" +
  "                              const SizedBox(height: 24),\n" +
  "                              // Gradient login button\n" +
  "                              SizedBox(\n" +
  "                                width: double.infinity,\n" +
  "                                height: 52,\n" +
  "                                child: DecoratedBox(\n" +
  "                                  decoration: BoxDecoration(\n" +
  "                                    borderRadius: BorderRadius.circular(14),\n" +
  "                                    gradient: LinearGradient(\n" +
  "                                      colors: [\n" +
  "                                        col.gradient2.withValues(alpha: 0.9),\n" +
  "                                        col.gradient2,\n" +
  "                                      ],\n" +
  "                                      begin: Alignment.topLeft,\n" +
  "                                      end: Alignment.bottomRight,\n" +
  "                                    ),\n" +
  "                                    boxShadow: [\n" +
  "                                      BoxShadow(\n" +
  "                                        color: col.gradient2.withValues(alpha: 0.5),\n" +
  "                                        blurRadius: 20, offset: const Offset(0, 6),\n" +
  "                                      ),\n" +
  "                                    ],\n" +
  "                                  ),\n" +
  "                                  child: ElevatedButton(\n" +
  "                                    style: ElevatedButton.styleFrom(\n" +
  "                                      backgroundColor: Colors.transparent,\n" +
  "                                      shadowColor: Colors.transparent,\n" +
  "                                      foregroundColor: Colors.white,\n" +
  "                                      shape: RoundedRectangleBorder(\n" +
  "                                        borderRadius: BorderRadius.circular(14),\n" +
  "                                      ),\n" +
  "                                    ),\n" +
  "                                    onPressed: _loading ? null : _login,\n" +
  "                                    child: _loading\n" +
  "                                        ? const SizedBox(\n" +
  "                                            width: 22, height: 22,\n" +
  "                                            child: CircularProgressIndicator(\n" +
  "                                                color: Colors.white, strokeWidth: 2),\n" +
  "                                          )\n" +
  "                                        : const Text(\n" +
  "                                            'MASUK',\n" +
  "                                            style: TextStyle(\n" +
  "                                              fontSize: 15,\n" +
  "                                              fontWeight: FontWeight.bold,\n" +
  "                                              letterSpacing: 2,\n" +
  "                                            ),\n" +
  "                                          ),\n" +
  "                                  ),\n" +
  "                                ),\n" +
  "                              ),\n" +
  "                            ],\n" +
  "                          ),\n" +
  "                        ),\n" +
  "                      ),\n" +
  "                    ),\n" +
  "                  ),\n" +
  "                ],\n" +
  "              ),\n" +
  "            ),\n" +
  "          ),\n" +
  "        ],\n" +
  "      ),\n" +
  "    );\n" +
  "  }";

if (!c.includes(OLD_LOGIN_START)) { console.error('ERROR: LoginScreen build not found'); process.exit(1); }
c = c.replace(OLD_LOGIN_START, NEW_LOGIN);
console.log('5. LoginScreen redesigned with glassmorphism');

// ─────────────────────────────────────────────────────────────────────────────
fs.writeFileSync(mainFile, c, 'utf8');
console.log('\n✓ Design v2 applied to lib/main.dart!');
