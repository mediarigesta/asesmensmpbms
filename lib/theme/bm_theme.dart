part of '../main.dart';

// ============================================================
// THEME SYSTEM
// ============================================================
enum BMTheme { navy, dark, ocean, forest, purple, rose }

class BMColors extends ThemeExtension<BMColors> {
  final Color primary;
  final Color gradient2;
  final Color surface;
  final Color cardBg;

  const BMColors({
    required this.primary,
    required this.gradient2,
    required this.surface,
    required this.cardBg,
  });

  @override
  BMColors copyWith({Color? primary, Color? gradient2, Color? surface, Color? cardBg}) =>
      BMColors(
        primary: primary ?? this.primary,
        gradient2: gradient2 ?? this.gradient2,
        surface: surface ?? this.surface,
        cardBg: cardBg ?? this.cardBg,
      );

  @override
  BMColors lerp(BMColors? other, double t) {
    if (other is! BMColors) return this;
    return BMColors(
      primary: Color.lerp(primary, other.primary, t)!,
      gradient2: Color.lerp(gradient2, other.gradient2, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
    );
  }
}

extension BMColorsX on BuildContext {
  BMColors get bm => Theme.of(this).extension<BMColors>()!;
}

class BMThemePresets {
  static const _presets = {
    BMTheme.navy:   BMColors(primary: Color(0xFF0D1117), gradient2: Color(0xFF1C2A4A), surface: Color(0xFFF1F5F9), cardBg: Colors.white),
    BMTheme.dark:   BMColors(primary: Color(0xFF000000), gradient2: Color(0xFF0F0F1A), surface: Color(0xFF0F172A), cardBg: Color(0xFF1E293B)),
    BMTheme.ocean:  BMColors(primary: Color(0xFF0C1A3E), gradient2: Color(0xFF0E3460), surface: Color(0xFFF1F5F9), cardBg: Colors.white),
    BMTheme.forest: BMColors(primary: Color(0xFF0A1F12), gradient2: Color(0xFF0E3A1C), surface: Color(0xFFF1F5F9), cardBg: Colors.white),
    BMTheme.purple: BMColors(primary: Color(0xFF130A2A), gradient2: Color(0xFF2D1554), surface: Color(0xFFF1F5F9), cardBg: Colors.white),
    BMTheme.rose:   BMColors(primary: Color(0xFF1A0510), gradient2: Color(0xFF3D0A20), surface: Color(0xFFF1F5F9), cardBg: Colors.white),
  };

  static const _names = {
    BMTheme.navy:   'Void Dark',
    BMTheme.dark:   'Pure Black',
    BMTheme.ocean:  'Deep Ocean',
    BMTheme.forest: 'Dark Forest',
    BMTheme.purple: 'Cosmic Purple',
    BMTheme.rose:   'Blood Rose',
  };

  static String name(BMTheme t) => _names[t]!;
  static BMColors colors(BMTheme t) => _presets[t]!;

  static ThemeData of(BMTheme t) {
    final c = _presets[t]!;
    final isDark = t == BMTheme.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ),
      extensions: [c],
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.black.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedColor: c.primary,
        selectedTileColor: c.primary.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? const Color(0xFF111122) : Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }
}

// ============================================================
// THEME NOTIFIER (global)
// ============================================================
final _themeNotifier = ValueNotifier<BMTheme>(BMTheme.navy);
