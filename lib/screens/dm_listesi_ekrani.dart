import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:odak_kapsulu/screens/dm_sohbet_ekrani.dart';
import 'package:odak_kapsulu/screens/arama_ekrani.dart';

class DmListesiEkran extends StatefulWidget {
  final bool nested;
  const DmListesiEkran({super.key, this.nested = false});

  @override
  State<DmListesiEkran> createState() => _DmListesiEkranState();
}

class _DmListesiEkranState extends State<DmListesiEkran> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final Widget bodyContent = _mevcutUid.isEmpty
        ? const Center(child: Text('Giriş yapmalısınız.', style: TextStyle(color: Colors.white60)))
        : StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('dmler')
                .where('katilimcilar', arrayContains: _mevcutUid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Henüz mesajlaşmanız bulunmuyor.',
                    style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                  ),
                );
              }

              var dmDocs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
              // Sort in memory by sonGuncelleme desc
              dmDocs.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;
                Timestamp t1 = dataA['sonGuncelleme'] as Timestamp? ?? Timestamp.now();
                Timestamp t2 = dataB['sonGuncelleme'] as Timestamp? ?? Timestamp.now();
                return t2.compareTo(t1);
              });

              return ListView.builder(
                itemCount: dmDocs.length,
                itemBuilder: (context, index) {
                  var doc = dmDocs[index];
                  var docData = doc.data() as Map<String, dynamic>;
                  List<dynamic> katilimcilar = docData['katilimcilar'] ?? [];
                  String targetUid = katilimcilar.firstWhere((uid) => uid != _mevcutUid, orElse: () => '');

                  if (targetUid.isEmpty) return const SizedBox.shrink();

                  String sonMesaj = docData['sonMesaj'] ?? 'Sohbeti başlatın...';

                  return StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('kullanicilar').doc(targetUid).snapshots(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData || !userSnap.data!.exists) {
                        return const SizedBox.shrink();
                      }

                      var userData = userSnap.data!.data() as Map<String, dynamic>;
                      String kullaniciAdi = userData['kullaniciAdi'] ?? 'Kapsülcü';
                      String profilFotoUrl = userData['profilFotoUrl'] ?? '';

                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF141419),
                              backgroundImage: profilFotoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(profilFotoUrl)
                                  : null,
                              child: profilFotoUrl.isEmpty
                                  ? const Icon(Icons.person, color: Color(0xFFA1A1AA))
                                  : null,
                            ),
                            title: Text(
                              kullaniciAdi,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                sonMesaj,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DmSohbetEkran(
                                    dmId: doc.id,
                                    hedefUid: targetUid,
                                    hedefKullaniciAdi: kullaniciAdi,
                                  ),
                                ),
                              );
                            },
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            color: const Color(0xFF141419),
                            height: 0.5,
                          ),
                        ],
                      );
                    },
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
        title: const Text('MESAJLAR', style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0E),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AramaEkran()),
              );
            },
          ),
        ],
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
