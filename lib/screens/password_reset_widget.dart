part of '../main.dart';

// ============================================================
// PASSWORD RESET WIDGET
// ============================================================
class PasswordResetWidget extends StatefulWidget {
  const PasswordResetWidget({super.key});
  @override
  State<PasswordResetWidget> createState() => _PasswordResetWidgetState();
}

class _PasswordResetWidgetState extends State<PasswordResetWidget> {
  final _searchCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _searching = false;
  bool _saving = false;
  bool _obscure = true;
  UserAccount? _found;
  String? _notFound;

  void _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _found = null;
      _notFound = null;
    });
    try {
      // Cari by username
      var snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: q)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        setState(() {
          _found = UserAccount.fromFirestore(snap.docs.first);
          _searching = false;
        });
        return;
      }
      // Cari by nama
      snap = await FirebaseFirestore.instance
          .collection('users')
          .where('nama', isEqualTo: q)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        setState(() {
          _found = UserAccount.fromFirestore(snap.docs.first);
          _searching = false;
        });
      } else {
        setState(() {
          _notFound = "Akun \"$q\" tidak ditemukan.";
          _searching = false;
        });
      }
    } catch (e) {
      setState(() {
        _notFound = "Terjadi kesalahan pencarian.";
        _searching = false;
      });
    }
  }

  void _save() async {
    if (_found == null || _newPassCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_found!.id)
        .update({'password': _newPassCtrl.text.trim()});
    setState(() {
      _saving = false;
      _found = null;
      _newPassCtrl.clear();
      _searchCtrl.clear();
      _notFound = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Password berhasil diubah!"),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: "Username atau Nama",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white),
            onPressed: _searching ? null : _search,
            child: _searching
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text("CARI"),
          ),
        ]),
        if (_notFound != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 16),
            const SizedBox(width: 6),
            Text(_notFound!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ]),
        ],
        if (_found != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(_found!.nama,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                const SizedBox(height: 2),
                Text(
                    "Username: ${_found!.username}  •  Role: ${_found!.role}  •  Kelas: ${_found!.kode}",
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _newPassCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: "Password Baru",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
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
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: const Text("SIMPAN"),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ]);
}

