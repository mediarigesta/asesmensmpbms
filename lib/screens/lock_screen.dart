part of '../main.dart';

// ============================================================
// LOCK SCREEN
// ============================================================
class LockScreen extends StatefulWidget {
  final UserAccount user;
  final ExamData? exam; // opsional: untuk catat statistik per ujian
  const LockScreen({super.key, required this.user, this.exam});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _p = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, size: 55, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text("AKSES TERKUNCI",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    letterSpacing: 2)),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Kamu telah melampaui batas pelanggaran.\nHubungi proktor untuk membuka kunci perangkat ini.",
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _p,
                obscureText: _obscure,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, letterSpacing: 4),
                decoration: InputDecoration(
                  labelText: "PIN Proktor",
                  labelStyle:
                  const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 280,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade900,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _unlock,
                icon: _loading
                    ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.red.shade900,
                        strokeWidth: 2))
                    : const Icon(Icons.lock_open),
                label: Text(_loading ? "Memeriksa..." : "BUKA KUNCI"),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _unlock() async {
    if (_p.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final d = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_config')
          .get();
      if (d.exists &&
          _p.text.trim() ==
              (d.data() as Map)['proctor_password']?.toString()) {
        // Jika konteks ujian diketahui, catat juga ke exam_status (naikkan counter proktor unlock)
        if (widget.exam != null) {
          await updateExamStatusForUser(
            exam: widget.exam!,
            user: widget.user,
            status: 'mengerjakan',
            extraFields: {
              'exam_status.${widget.exam!.id}.proktorUnlockCount': FieldValue.increment(1),
            },
          );
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.user.id)
              .update({'status_mengerjakan': 'mengerjakan'});
        }
        if (isAndroid) {
          try { SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); } catch (_) {}
        }
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("PIN salah! Coba lagi."),
            backgroundColor: Colors.orange,
          ));
        }
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }
}

