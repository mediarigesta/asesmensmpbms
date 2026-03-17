part of '../main.dart';

// ============================================================
// SPLASH SCREEN
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();
    _loadThemeAndSession();
  }

  void _loadThemeAndSession() async {
    final prefs = await SharedPreferences.getInstance();
    // Load saved theme
    final savedTheme = prefs.getString('app_theme');
    if (savedTheme != null) {
      try {
        _themeNotifier.value = BMTheme.values.firstWhere((t) => t.name == savedTheme);
      } catch (_) {}
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Check auto-login
    final savedId = prefs.getString('saved_user_id');
    if (savedId != null && savedId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(savedId).get();
        if (doc.exists && mounted) {
          final u = UserAccount.fromFirestore(doc);
          if (u.statusAktif != 'terblokir') {
            if (u.role == 'admin1') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Admin1Dashboard(admin: u)));
            } else if (u.role == 'guru') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GuruDashboard(guru: u)));
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(user: u)));
            }
            return;
          }
        }
      } catch (_) {}
      // If failed, clear saved id and go to login
      await prefs.remove('saved_user_id');
    }
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = BMThemePresets.colors(_themeNotifier.value);
    return Scaffold(
      backgroundColor: col.primary,
      body: Stack(
        children: [
          // Radial gradient bg
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.4,
                  colors: [col.gradient2, col.primary, col.primary],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // Orb glow top-right
          Positioned(
            top: -120, right: -100,
            child: Container(
              width: 420, height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [col.gradient2.withValues(alpha: 0.28), Colors.transparent],
                ),
              ),
            ),
          ),
          // Orb glow bottom-left
          Positioned(
            bottom: -100, left: -80,
            child: Container(
              width: 360, height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [col.gradient2.withValues(alpha: 0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          // Main content
          FadeTransition(
            opacity: _fade,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glowing logo
                  Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          col.gradient2.withValues(alpha: 0.55),
                          col.primary.withValues(alpha: 0.1),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: col.gradient2.withValues(alpha: 0.55),
                          blurRadius: 60, spreadRadius: 6,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12), width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Image.asset('assets/logo.png'),
                  ),
                  const SizedBox(height: 30),
                  // Gradient title
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFB0C4DE)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(b),
                    child: const Text(
                      'BUDI MULIA EXAM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SMP BUDI MULIA JAKARTA',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 64),
                  // Slim shimmer bar
                  Container(
                    width: 100, height: 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: Colors.white.withValues(alpha: 0.5),
                      minHeight: 2,
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
}
