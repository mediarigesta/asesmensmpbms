part of '../main.dart';

// ============================================================
// ADMIN MATA PELAJARAN
// ============================================================
class AdminSubjectManager extends StatefulWidget {
  const AdminSubjectManager({super.key});
  @override
  State<AdminSubjectManager> createState() => _AdminSubjectManagerState();
}

class _AdminSubjectManagerState extends State<AdminSubjectManager> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                labelText: "Nama Mata Pelajaran",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.book),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white),
            onPressed: () {
              if (_ctrl.text.trim().isNotEmpty) {
                FirebaseFirestore.instance
                    .collection('subjects')
                    .add({'name': _ctrl.text.trim()});
                _ctrl.clear();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text("Tambah"),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('subjects')
              .orderBy('name')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_outlined,
                          size: 50, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("Belum ada mata pelajaran.",
                          style: TextStyle(color: Colors.grey)),
                    ]),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: snap.data!.docs.length,
              itemBuilder: (c, i) {
                final doc = snap.data!.docs[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF0F172A),
                      child: Icon(Icons.book, color: Colors.white, size: 18),
                    ),
                    title: Text((doc.data() as Map)['name'],
                        style:
                        const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Hapus Mapel?"),
                            content: Text(
                                "Hapus \"${(doc.data() as Map)['name']}\"?"),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Batal")),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white),
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text("Hapus"),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          FirebaseFirestore.instance
                              .collection('subjects')
                              .doc(doc.id)
                              .delete();
                        }
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}


