import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odak_kapsulu/screens/lobi_ekrani.dart';
import 'package:odak_kapsulu/screens/dm_listesi_ekrani.dart';
import 'package:odak_kapsulu/screens/bildirim_ekrani.dart';
import 'package:odak_kapsulu/screens/siralama_ekrani.dart';

class TerminalEkran extends StatefulWidget {
  const TerminalEkran({super.key});

  @override
  State<TerminalEkran> createState() => _TerminalEkranState();
}

class _TerminalEkranState extends State<TerminalEkran> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _bildirimleriOku() async {
    if (_mevcutUid.isEmpty) return;
    var snap = await _firestore
        .collection('kullanicilar')
        .doc(_mevcutUid)
        .collection('bildirimler')
        .where('okunduMu', isEqualTo: false)
        .get();
    
    if (snap.docs.isNotEmpty) {
      WriteBatch batch = _firestore.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'okunduMu': true});
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0E),
        appBar: AppBar(
          title: const Text('TERMİNAL', style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFF0A0A0E),
          elevation: 0,
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2A35), width: 0.5),
                ),
              ),
              child: TabBar(
                isScrollable: true,
                indicatorColor: const Color(0xFF4A90E2),
                indicatorWeight: 2,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF71717A),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                onTap: (index) {
                  if (index == 2) {
                    _bildirimleriOku();
                  }
                },
                tabs: [
                  const Tab(text: 'Odalar'),
                  const Tab(text: 'Mesajlar'),
                  Tab(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('kullanicilar')
                          .doc(_mevcutUid)
                          .collection('bildirimler')
                          .where('okunduMu', isEqualTo: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        int count = snapshot.data?.docs.length ?? 0;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Bildirimler'),
                            if (count > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4A90E2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.emoji_events, size: 15, color: Color(0xFF4A90E2)),
                        SizedBox(width: 4),
                        Text('Sıralama'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            LobiEkran(nested: true),
            DmListesiEkran(nested: true),
            BildirimEkran(nested: true),
            SiralamaEkran(nested: true),
          ],
        ),
      ),
    );
  }
}
