Widget _buildBroadcast() =>
    StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('settings').doc(
            'broadcast').snapshots(),
        builder: (c, snap) {
          return Center(
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.campaign, size: 50, color: Colors.red),
                            const SizedBox(height: 20),
                            Text(
                                snap.hasData ? (snap.data!
                                    .data() as Map?)?['message'] ??
                                    "Tidak ada pesan" : "Memuat...",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)
                            )
                          ]
                      )
                  )
              )
          );
        }
    );