const fs = require('fs');
const path = require('path');
const mainFile = path.join(__dirname, 'lib', 'main.dart');
let c = fs.readFileSync(mainFile, 'utf8');

// ─────────────────────────────────────────────────────────────────────────────
// 1. Upgrade ThemeData — cardTheme + listTileTheme + drawerTheme
// ─────────────────────────────────────────────────────────────────────────────
const OLD_CARD_THEME =
  "      cardTheme: CardThemeData(\n" +
  "        elevation: 2,\n" +
  "        shadowColor: Colors.black26,\n" +
  "        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),\n" +
  "        surfaceTintColor: Colors.transparent,\n" +
  "      ),\n" +
  "      dialogTheme: DialogThemeData(\n" +
  "        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),\n" +
  "        elevation: 8,\n" +
  "      ),\n" +
  "      snackBarTheme: const SnackBarThemeData(\n" +
  "        behavior: SnackBarBehavior.floating,\n" +
  "        shape: RoundedRectangleBorder(\n" +
  "          borderRadius: BorderRadius.all(Radius.circular(12)),\n" +
  "        ),\n" +
  "      ),";

const NEW_CARD_THEME =
  "      cardTheme: CardThemeData(\n" +
  "        elevation: 0,\n" +
  "        shadowColor: Colors.transparent,\n" +
  "        shape: RoundedRectangleBorder(\n" +
  "          borderRadius: BorderRadius.circular(20),\n" +
  "          side: BorderSide(\n" +
  "            color: isDark\n" +
  "                ? Colors.white.withValues(alpha: 0.09)\n" +
  "                : Colors.black.withValues(alpha: 0.07),\n" +
  "            width: 1,\n" +
  "          ),\n" +
  "        ),\n" +
  "        surfaceTintColor: Colors.transparent,\n" +
  "        margin: EdgeInsets.zero,\n" +
  "      ),\n" +
  "      listTileTheme: ListTileThemeData(\n" +
  "        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),\n" +
  "        selectedColor: c.primary,\n" +
  "        selectedTileColor: c.primary.withValues(alpha: 0.08),\n" +
  "        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),\n" +
  "      ),\n" +
  "      drawerTheme: DrawerThemeData(\n" +
  "        backgroundColor: isDark ? const Color(0xFF111122) : Colors.white,\n" +
  "        elevation: 0,\n" +
  "        shape: const RoundedRectangleBorder(\n" +
  "          borderRadius: BorderRadius.only(\n" +
  "            topRight: Radius.circular(28),\n" +
  "            bottomRight: Radius.circular(28),\n" +
  "          ),\n" +
  "        ),\n" +
  "      ),\n" +
  "      dialogTheme: DialogThemeData(\n" +
  "        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),\n" +
  "        elevation: 8,\n" +
  "      ),\n" +
  "      snackBarTheme: const SnackBarThemeData(\n" +
  "        behavior: SnackBarBehavior.floating,\n" +
  "        shape: RoundedRectangleBorder(\n" +
  "          borderRadius: BorderRadius.all(Radius.circular(14)),\n" +
  "        ),\n" +
  "      ),";

if (!c.includes(OLD_CARD_THEME)) { console.error('ERROR: cardTheme block not found'); process.exit(1); }
c = c.replace(OLD_CARD_THEME, NEW_CARD_THEME);
console.log('1. ThemeData upgraded (card + listTile + drawer)');

// ─────────────────────────────────────────────────────────────────────────────
// 2. Admin1Dashboard header: white → gradient + white text
// ─────────────────────────────────────────────────────────────────────────────
const OLD_ADMIN_HDR =
  "          // Header\n" +
  "          Container(\n" +
  "            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),\n" +
  "            color: Colors.white,\n" +
  "            child: Row(children: [\n" +
  "              IconButton(\n" +
  "                icon: const Icon(Icons.menu, color: Color(0xFF60A5FA)),\n" +
  "                tooltip: \"Menu\",\n" +
  "                onPressed: () => _scaffoldKey.currentState!.openDrawer(),\n" +
  "              ),\n" +
  "              Icon(Icons.admin_panel_settings, color: context.bm.primary),\n" +
  "              const SizedBox(width: 8),\n" +
  "              Expanded(\n" +
  "                child: Text(\"Admin: ${widget.admin.nama}\",\n" +
  "                    style: const TextStyle(fontWeight: FontWeight.bold)),\n" +
  "              ),\n";

const NEW_ADMIN_HDR =
  "          // Header (gradient)\n" +
  "          Container(\n" +
  "            padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),\n" +
  "            decoration: BoxDecoration(\n" +
  "              gradient: LinearGradient(\n" +
  "                colors: [context.bm.primary, context.bm.gradient2],\n" +
  "                begin: Alignment.topLeft, end: Alignment.bottomRight,\n" +
  "              ),\n" +
  "            ),\n" +
  "            child: Row(children: [\n" +
  "              IconButton(\n" +
  "                icon: const Icon(Icons.menu, color: Color(0xFF60A5FA)),\n" +
  "                tooltip: \"Menu\",\n" +
  "                onPressed: () => _scaffoldKey.currentState!.openDrawer(),\n" +
  "              ),\n" +
  "              const Icon(Icons.admin_panel_settings, color: Colors.white70),\n" +
  "              const SizedBox(width: 8),\n" +
  "              Expanded(\n" +
  "                child: Column(\n" +
  "                  crossAxisAlignment: CrossAxisAlignment.start,\n" +
  "                  mainAxisSize: MainAxisSize.min,\n" +
  "                  children: [\n" +
  "                    const Text('Administrator',\n" +
  "                        style: TextStyle(color: Colors.white54, fontSize: 11)),\n" +
  "                    Text(widget.admin.nama,\n" +
  "                        style: const TextStyle(\n" +
  "                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),\n" +
  "                  ],\n" +
  "                ),\n" +
  "              ),\n";

if (!c.includes(OLD_ADMIN_HDR)) { console.error('ERROR: Admin header not found'); process.exit(1); }
c = c.replace(OLD_ADMIN_HDR, NEW_ADMIN_HDR);
console.log('2. Admin header: white → gradient');

// ─────────────────────────────────────────────────────────────────────────────
// 3. Admin header logout icon → white
// ─────────────────────────────────────────────────────────────────────────────
const OLD_LOGOUT =
  "              IconButton(\n" +
  "                icon: const Icon(Icons.logout),\n" +
  "                tooltip: \"Keluar\",\n" +
  "                onPressed: () => showDialog(\n" +
  "                  context: context,\n" +
  "                  builder: (_) => AlertDialog(\n" +
  "                    title: const Text(\"Keluar?\"),\n" +
  "                    content: const Text(\"Yakin ingin keluar dari sesi ini?\"),";

const NEW_LOGOUT =
  "              IconButton(\n" +
  "                icon: const Icon(Icons.logout, color: Colors.white70),\n" +
  "                tooltip: \"Keluar\",\n" +
  "                onPressed: () => showDialog(\n" +
  "                  context: context,\n" +
  "                  builder: (_) => AlertDialog(\n" +
  "                    title: const Text(\"Keluar?\"),\n" +
  "                    content: const Text(\"Yakin ingin keluar dari sesi ini?\"),";

if (!c.includes(OLD_LOGOUT)) { console.error('ERROR: Admin logout icon not found'); process.exit(1); }
c = c.replace(OLD_LOGOUT, NEW_LOGOUT);
console.log('3. Admin logout icon → white');

// ─────────────────────────────────────────────────────────────────────────────
// 4. Admin drawer _item: hardcoded 0xFF0F172A → context.bm.primary
// ─────────────────────────────────────────────────────────────────────────────
const OLD_ITEM =
  "    Widget _item(int tab, IconData icon, String label) => ListTile(\n" +
  "      leading: Icon(icon, size: 20),\n" +
  "      title: Text(label, style: const TextStyle(fontSize: 14)),\n" +
  "      selected: _tab == tab,\n" +
  "      selectedColor: const Color(0xFF0F172A),\n" +
  "      selectedTileColor: const Color(0xFF0F172A08),\n" +
  "      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),\n" +
  "      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),\n" +
  "      onTap: () { Navigator.pop(context); setState(() => _tab = tab); },\n" +
  "    );";

const NEW_ITEM =
  "    Widget _item(int tab, IconData icon, String label) => ListTile(\n" +
  "      leading: Icon(icon, size: 20),\n" +
  "      title: Text(label, style: const TextStyle(fontSize: 14)),\n" +
  "      selected: _tab == tab,\n" +
  "      selectedColor: context.bm.primary,\n" +
  "      selectedTileColor: context.bm.primary.withValues(alpha: 0.08),\n" +
  "      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),\n" +
  "      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),\n" +
  "      onTap: () { Navigator.pop(context); setState(() => _tab = tab); },\n" +
  "    );";

if (!c.includes(OLD_ITEM)) { console.error('ERROR: Admin drawer _item not found'); process.exit(1); }
c = c.replace(OLD_ITEM, NEW_ITEM);
console.log('4. Admin drawer _item → context.bm.primary');

// ─────────────────────────────────────────────────────────────────────────────
// 5. Admin drawer Dashboard tile: hardcoded → context.bm
// ─────────────────────────────────────────────────────────────────────────────
const OLD_DASH_TILE =
  "            ListTile(\n" +
  "              leading: Image.asset('assets/logo.png', width: 22, height: 22),\n" +
  "              title: const Text('Dashboard', style: TextStyle(fontSize: 14)),\n" +
  "              selected: _tab == 0,\n" +
  "              selectedColor: const Color(0xFF0F172A),\n" +
  "              selectedTileColor: const Color(0x080F172A),\n" +
  "              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),\n" +
  "              onTap: () { Navigator.pop(context); setState(() => _tab = 0); },\n" +
  "            ),";

const NEW_DASH_TILE =
  "            ListTile(\n" +
  "              leading: Image.asset('assets/logo.png', width: 22, height: 22),\n" +
  "              title: const Text('Dashboard', style: TextStyle(fontSize: 14)),\n" +
  "              selected: _tab == 0,\n" +
  "              selectedColor: context.bm.primary,\n" +
  "              selectedTileColor: context.bm.primary.withValues(alpha: 0.08),\n" +
  "              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),\n" +
  "              onTap: () { Navigator.pop(context); setState(() => _tab = 0); },\n" +
  "            ),";

if (!c.includes(OLD_DASH_TILE)) { console.error('ERROR: Admin drawer Dashboard tile not found'); process.exit(1); }
c = c.replace(OLD_DASH_TILE, NEW_DASH_TILE);
console.log('5. Admin drawer Dashboard tile → context.bm.primary');

// ─────────────────────────────────────────────────────────────────────────────
// 6. Theme switcher color map: update to new palette
// ─────────────────────────────────────────────────────────────────────────────
const OLD_SWATCH =
  "      final themeColors = {\n" +
  "        BMTheme.navy:   const Color(0xFF0F172A),\n" +
  "        BMTheme.dark:   const Color(0xFF1E293B),\n" +
  "        BMTheme.ocean:  const Color(0xFF0369A1),\n" +
  "        BMTheme.forest: const Color(0xFF166534),\n" +
  "        BMTheme.purple: const Color(0xFF6B21A8),\n" +
  "        BMTheme.rose:   const Color(0xFF9F1239),\n" +
  "      };";

const NEW_SWATCH =
  "      final themeColors = {\n" +
  "        BMTheme.navy:   const Color(0xFF0D1117),\n" +
  "        BMTheme.dark:   const Color(0xFF000000),\n" +
  "        BMTheme.ocean:  const Color(0xFF0C1A3E),\n" +
  "        BMTheme.forest: const Color(0xFF0A1F12),\n" +
  "        BMTheme.purple: const Color(0xFF130A2A),\n" +
  "        BMTheme.rose:   const Color(0xFF1A0510),\n" +
  "      };";

if (!c.includes(OLD_SWATCH)) { console.error('ERROR: theme switcher color map not found'); process.exit(1); }
c = c.replace(OLD_SWATCH, NEW_SWATCH);
console.log('6. Theme switcher colors updated');

// ─────────────────────────────────────────────────────────────────────────────
// 7. Guru header badge — make _headerBadge text more visible
// ─────────────────────────────────────────────────────────────────────────────
const OLD_BADGE_FN =
  "  Widget _headerBadge(String label, Color color, IconData icon) => Container(\n" +
  "    margin: const EdgeInsets.only(top: 2),\n" +
  "    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),\n" +
  "    decoration: BoxDecoration(\n" +
  "        color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),\n" +
  "    child: Row(mainAxisSize: MainAxisSize.min, children: [\n" +
  "      Icon(icon, color: color, size: 12),\n" +
  "      const SizedBox(width: 4),\n" +
  "      Text(label,\n" +
  "          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),\n" +
  "    ]),\n" +
  "  );";

// Check if it exists
if (c.includes(OLD_BADGE_FN)) {
  const NEW_BADGE_FN =
    "  Widget _headerBadge(String label, Color color, IconData icon) => Container(\n" +
    "    margin: const EdgeInsets.only(top: 2),\n" +
    "    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),\n" +
    "    decoration: BoxDecoration(\n" +
    "        color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20),\n" +
    "        border: Border.all(color: Colors.white24, width: 0.5)),\n" +
    "    child: Row(mainAxisSize: MainAxisSize.min, children: [\n" +
    "      Icon(icon, color: Colors.white, size: 12),\n" +
    "      const SizedBox(width: 4),\n" +
    "      Text(label,\n" +
    "          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),\n" +
    "    ]),\n" +
    "  );";
  c = c.replace(OLD_BADGE_FN, NEW_BADGE_FN);
  console.log('7. _headerBadge → always white (contrast on gradient header)');
} else {
  console.log('7. _headerBadge not found, skip');
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. HomeScreen _chip → always white (contrast on gradient header)
// ─────────────────────────────────────────────────────────────────────────────
const OLD_CHIP =
  "  Widget _chip(IconData icon, String label) => Container(\n" +
  "    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),\n" +
  "    decoration: BoxDecoration(\n" +
  "        color: Colors.white.withValues(alpha: 0.15),\n" +
  "        borderRadius: BorderRadius.circular(20)),\n" +
  "    child: Row(mainAxisSize: MainAxisSize.min, children: [\n" +
  "      Icon(icon, color: Colors.white, size: 13),\n" +
  "      const SizedBox(width: 4),\n" +
  "      Text(label,\n" +
  "          style: const TextStyle(color: Colors.white70, fontSize: 12)),\n" +
  "    ]),\n" +
  "  );";

if (c.includes(OLD_CHIP)) {
  const NEW_CHIP =
    "  Widget _chip(IconData icon, String label) => Container(\n" +
    "    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),\n" +
    "    decoration: BoxDecoration(\n" +
    "        color: Colors.white.withValues(alpha: 0.18),\n" +
    "        borderRadius: BorderRadius.circular(20),\n" +
    "        border: Border.all(color: Colors.white24, width: 0.5)),\n" +
    "    child: Row(mainAxisSize: MainAxisSize.min, children: [\n" +
    "      Icon(icon, color: Colors.white, size: 13),\n" +
    "      const SizedBox(width: 4),\n" +
    "      Text(label,\n" +
    "          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),\n" +
    "    ]),\n" +
    "  );";
  c = c.replace(OLD_CHIP, NEW_CHIP);
  console.log('8. HomeScreen _chip → white text + border');
} else {
  console.log('8. _chip not found, skip');
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. IdleTimeout dialog: upgrade to glass style
// ─────────────────────────────────────────────────────────────────────────────
const OLD_IDLE =
  "      content: const Text('Sesi Anda tidak aktif selama 15 menit.\\nApakah Anda ingin tetap masuk?'),\n" +
  "        actions: [\n" +
  "          TextButton(\n" +
  "            onPressed: () {\n" +
  "              Navigator.pop(context);\n" +
  "              startIdleWatcher();\n" +
  "            },\n" +
  "            child: const Text('Tetap Masuk'),\n" +
  "          ),\n" +
  "          ElevatedButton(\n" +
  "            style: ElevatedButton.styleFrom(\n" +
  "                backgroundColor: Colors.red, foregroundColor: Colors.white),\n" +
  "            onPressed: () {\n" +
  "              Navigator.pop(context);\n" +
  "              Navigator.pushAndRemoveUntil(\n" +
  "                context,\n" +
  "                MaterialPageRoute(builder: (_) => const LoginScreen()),\n" +
  "                (r) => false,\n" +
  "              );\n" +
  "            },\n" +
  "            child: const Text('Keluar'),\n" +
  "          ),\n" +
  "        ],";

if (c.includes(OLD_IDLE)) {
  const NEW_IDLE =
    "      content: const Text('Sesi Anda tidak aktif selama 15 menit.\\nApakah Anda ingin tetap masuk?'),\n" +
    "        actionsAlignment: MainAxisAlignment.center,\n" +
    "        actions: [\n" +
    "          OutlinedButton(\n" +
    "            onPressed: () {\n" +
    "              Navigator.pop(context);\n" +
    "              startIdleWatcher();\n" +
    "            },\n" +
    "            child: const Text('Tetap Masuk'),\n" +
    "          ),\n" +
    "          const SizedBox(width: 8),\n" +
    "          ElevatedButton(\n" +
    "            style: ElevatedButton.styleFrom(\n" +
    "                backgroundColor: Colors.red, foregroundColor: Colors.white),\n" +
    "            onPressed: () {\n" +
    "              Navigator.pop(context);\n" +
    "              Navigator.pushAndRemoveUntil(\n" +
    "                context,\n" +
    "                MaterialPageRoute(builder: (_) => const LoginScreen()),\n" +
    "                (r) => false,\n" +
    "              );\n" +
    "            },\n" +
    "            child: const Text('Keluar'),\n" +
    "          ),\n" +
    "        ],";
  c = c.replace(OLD_IDLE, NEW_IDLE);
  console.log('9. IdleTimeout dialog actions centered');
} else {
  console.log('9. IdleTimeout dialog not found, skip');
}

// ─────────────────────────────────────────────────────────────────────────────
fs.writeFileSync(mainFile, c, 'utf8');
console.log('\n✓ Design v3 applied to lib/main.dart!');
