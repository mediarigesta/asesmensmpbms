part of '../main.dart';

// ============================================================
// SESSION TIMEOUT MIXIN
// ============================================================
mixin IdleTimeoutMixin<T extends StatefulWidget> on State<T> {
  Timer? _idleTimer;
  DateTime _lastActivity = DateTime.now();
  static const _idleLimit = Duration(minutes: 15);

  void resetIdleTimer() => _lastActivity = DateTime.now();

  void startIdleWatcher() {
    _idleTimer?.cancel();
    _lastActivity = DateTime.now();
    _idleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (DateTime.now().difference(_lastActivity) >= _idleLimit) {
        _idleTimer?.cancel();
        _showIdleDialog();
      }
    });
  }

  void _showIdleDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.access_time, color: Colors.orange),
          SizedBox(width: 8),
          Text('Sesi Tidak Aktif'),
        ]),
        content: const Text('Sesi Anda tidak aktif selama 15 menit.\nApakah Anda ingin tetap masuk?'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              startIdleWatcher();
            },
            child: const Text('Tetap Masuk'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('saved_user_id');
              await prefs.remove('saved_username');
              await prefs.remove('saved_password');
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false,
              );
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void stopIdleWatcher() => _idleTimer?.cancel();
}
