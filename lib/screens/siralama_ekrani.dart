import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:odak_kapsulu/screens/diger_profil_ekrani.dart';

class SiralamaEkran extends StatefulWidget {
  final bool nested;
  const SiralamaEkran({super.key, this.nested = false});

  @override
  State<SiralamaEkran> createState() => _SiralamaEkranState();
}

class _SiralamaEkranState extends State<SiralamaEkran> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Color _getRankBorderColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700); // Gold
    if (rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    return const Color(0xFF2A2A35); // Default grey border
  }

  Widget _getRankWidget(int rank) {
    if (rank <= 3) {
      IconData icon = Icons.emoji_events;
      Color color;
      if (rank == 1) {
        color = const Color(0xFFFFD700);
      } else if (rank == 2) {
        color = const Color(0xFFC0C0C0);
      } else {
        color = const Color(0xFFCD7F32);
      }
      return Icon(icon, color: color, size: 22);
    }
    return Text(
      '#$rank',
      style: const TextStyle(
        color: Color(0xFF71717A),
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget bodyContent = StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('kullanicilar')
          .orderBy('xp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Sıralama verisi bulunamadı.',
              style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
            ),
          );
        }

        var userDocs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: userDocs.length,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          itemBuilder: (context, index) {
            var doc = userDocs[index];
            var data = doc.data() as Map<String, dynamic>;
            String userId = doc.id;
            String username = data['kullaniciAdi'] ?? 'Kapsülcü';
            String fotoUrl = data['profilFotoUrl'] ?? '';
            int xp = data['xp'] ?? 0;
            int rank = index + 1;

            Color borderColor = _getRankBorderColor(rank);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: rank <= 3 ? 1.2 : 0.8),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: SizedBox(
                  width: 75,
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        alignment: Alignment.centerLeft,
                        child: _getRankWidget(rank),
                      ),
                      const SizedBox(width: 4),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF0A0A0E),
                        backgroundImage: fotoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(fotoUrl)
                            : null,
                        child: fotoUrl.isEmpty
                            ? const Icon(Icons.person, color: Color(0xFFA1A1AA))
                            : null,
                      ),
                    ],
                  ),
                ),
                title: Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                trailing: Text(
                  '${xp.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} XP',
                  style: const TextStyle(
                    color: Color(0xFF4A90E2),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DigerProfilEkran(hedefUid: userId),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    if (widget.nested) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0E),
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: AppBar(
        title: const Text('GLOBAL SIRALAMA', style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0E),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF2A2A35),
            height: 0.5,
          ),
        ),
      ),
      body: bodyContent,
    );
  }
}
