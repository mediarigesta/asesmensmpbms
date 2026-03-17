part of '../main.dart';

// WINDOWS KEYBOARD BLOCKER
// Mencegat shortcut berbahaya di level Flutter saat ujian Windows
// ============================================================
class _WindowsKeyboardBlocker extends StatelessWidget {
  final Widget child;
  const _WindowsKeyboardBlocker({required this.child});

  static bool _shouldBlock(KeyEvent event) {
    if (HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.tab) return true;
    if (HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.f4) return true;
    if (event.logicalKey == LogicalKeyboardKey.metaLeft ||
        event.logicalKey == LogicalKeyboardKey.metaRight) return true;
    if (HardwareKeyboard.instance.isControlPressed &&
        HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.delete) return true;
    if (event.logicalKey == LogicalKeyboardKey.printScreen) return true;
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.escape) return true;
    if (HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.escape) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) { if (_shouldBlock(event)) {} },
      child: child,
    );
  }
}
