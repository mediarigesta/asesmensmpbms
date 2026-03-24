part of '../main.dart';

// ============================================================
// LOGIN SCREEN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = BMThemePresets.colors(_themeNotifier.value);
    return Scaffold(
      backgroundColor: col.primary,
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [col.primary, col.gradient2, col.primary],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // ── Orb top-right ────────────────────────────────────────
          Positioned(
            top: -100, right: -80,
            child: Container(
              width: 360, height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [col.gradient2.withValues(alpha: 0.45), Colors.transparent],
                ),
              ),
            ),
          ),
          // ── Orb bottom-left ──────────────────────────────────────
          Positioned(
            bottom: -110, left: -90,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [col.gradient2.withValues(alpha: 0.25), Colors.transparent],
                ),
              ),
            ),
          ),
          // ── Content ──────────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with glow
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          col.gradient2.withValues(alpha: 0.6),
                          col.primary.withValues(alpha: 0.2),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: col.gradient2.withValues(alpha: 0.6),
                          blurRadius: 40, spreadRadius: 4,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15), width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset('assets/logo.png'),
                  ),
                  const SizedBox(height: 18),
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFCDD9F0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(b),
                    child: const Text(
                      'BUDI MULIA EXAM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SMP Budi Mulia Jakarta',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  // ── Glass card ──────────────────────────────────
                  Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selamat Datang',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Masuk untuk melanjutkan',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 28),
                              // Username
                              TextField(
                                controller: _u,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                                  prefixIcon: Icon(Icons.person_outline,
                                      color: Colors.white.withValues(alpha: 0.45)),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.07),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Colors.white54, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Password
                              TextField(
                                controller: _p,
                                obscureText: _obscure,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                                  prefixIcon: Icon(Icons.lock_outline,
                                      color: Colors.white.withValues(alpha: 0.45)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.white38,
                                    ),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.07),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Colors.white54, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Remember Me
                              Row(
                                children: [
                                  SizedBox(
                                    width: 22, height: 22,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                      activeColor: Colors.white,
                                      checkColor: col.primary,
                                      side: const BorderSide(color: Colors.white38),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ingat Saya',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Gradient login button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      colors: [
                                        col.gradient2.withValues(alpha: 0.9),
                                        col.gradient2,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: col.gradient2.withValues(alpha: 0.5),
                                        blurRadius: 20, offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: _loading ? null : _login,
                                    child: _loading
                                        ? const SizedBox(
                                            width: 22, height: 22,
                                            child: CircularProgressIndicator(
                                                color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text(
                                            'MASUK',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _login() async {
    if (_u.text.trim().isEmpty || _p.text.trim().isEmpty) {
      _snack("Username dan password tidak boleh kosong!", Colors.orange);
      return;
    }
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _u.text.trim())
          .where('password', isEqualTo: _p.text.trim())
          .get();
      if (!mounted) return;
      setState(() => _loading = false);

      if (snap.docs.isEmpty) {
        _snack("Username atau password salah!", Colors.red);
        return;
      }

      final u = UserAccount.fromFirestore(snap.docs.first);
      if (u.statusAktif == 'terblokir') {
        _snack("Akun Anda terblokir. Hubungi administrator.", Colors.red);
        return;
      }

      // Save or clear user session based on Remember Me
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_user_id', u.id);
      } else {
        await prefs.remove('saved_user_id');
      }

      // Auto-reset status siswa jika "mengerjakan" tapi tidak ada ujian aktif
      if (u.role == 'siswa' && u.statusMengerjakan == 'mengerjakan') {
        final examSnap = await FirebaseFirestore.instance.collection('exam').get();
        final adaUjianAktif = examSnap.docs
            .map((d) => ExamData.fromFirestore(d))
            .any((e) => e.isOngoing && u.matchJenjang(e.jenjang));
        if (!adaUjianAktif) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(u.id)
              .update({'status_mengerjakan': 'belum mulai'});
        }
      }

      if (!mounted) return;
      if (u.role == 'admin1') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => Admin1Dashboard(admin: u)));
      } else if (u.role == 'guru') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => GuruDashboard(guru: u)));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(user: u)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack("Gagal login: ${e.toString()}", Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
