import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:odak_kapsulu/screens/diger_profil_ekrani.dart';

class TakipYonetimiEkran extends StatefulWidget {
  final String uid;
  final bool isFollowersDefault;

  const TakipYonetimiEkran({
    super.key,
    required this.uid,
    required this.isFollowersDefault,
  });

  @override
  State<TakipYonetimiEkran> createState() => _TakipYonetimiEkranState();
}

class _TakipYonetimiEkranState extends State<TakipYonetimiEkran> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _followersFilter = 'Tümü'; // 'Tümü', 'Karşılıklı', 'Geri Takip Etmediklerim'
  String _followingFilter = 'Tümü'; // 'Tümü', 'Karşılıklı', 'Beni Takip Etmeyenler'

  void _takiptenCik(String hedefUid) async {
    if (_mevcutUid.isEmpty) return;

    final targetRef = _firestore.collection('kullanicilar').doc(hedefUid);
    final currentUserRef = _firestore.collection('kullanicilar').doc(_mevcutUid);

    // Unfollow transaction
    await _firestore.runTransaction((transaction) async {
      transaction.update(targetRef, {
        'takipciler': FieldValue.arrayRemove([_mevcutUid])
      });
      transaction.update(currentUserRef, {
        'takipEdilenler': FieldValue.arrayRemove([hedefUid])
      });
    });

    // Write unfollow notification to B
    await _firestore.collection('kullanicilar').doc(hedefUid).collection('bildirimler').add({
      'tip': 'unfollow',
      'mesaj': 'Bir kullanıcı seni takipten çıktı.',
      'tarih': FieldValue.serverTimestamp(),
      'okunduMu': false,
      'gonderenId': 'sistem',
    });
  }

  void _geriTakipEt(String hedefUid) async {
    if (_mevcutUid.isEmpty) return;

    final targetRef = _firestore.collection('kullanicilar').doc(hedefUid);
    final currentUserRef = _firestore.collection('kullanicilar').doc(_mevcutUid);

    await _firestore.runTransaction((transaction) async {
      transaction.update(targetRef, {
        'takipciler': FieldValue.arrayUnion([_mevcutUid])
      });
      transaction.update(currentUserRef, {
        'takipEdilenler': FieldValue.arrayUnion([hedefUid])
      });
    });

    // Write follow notification
    await _firestore.collection('kullanicilar').doc(hedefUid).collection('bildirimler').add({
      'tip': 'takip',
      'gonderenId': _mevcutUid,
      'mesaj': 'seni takip etmeye başladı.',
      'tarih': FieldValue.serverTimestamp(),
      'okunduMu': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.isFollowersDefault ? 0 : 1,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0E),
        appBar: AppBar(
          title: const Text('TAKİP YÖNETİMİ', style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFF0A0A0E),
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2A35), width: 0.5),
                ),
              ),
              child: const TabBar(
                indicatorColor: Color(0xFF4A90E2),
                indicatorWeight: 2,
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFF71717A),
                labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                tabs: [
                  Tab(text: 'Takipçiler'),
                  Tab(text: 'Takip Edilenler'),
                ],
              ),
            ),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('kullanicilar').doc(widget.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Kullanıcı bilgisi yüklenemedi.', style: TextStyle(color: Colors.white60)));
            }

            var userData = snapshot.data!.data() as Map<String, dynamic>;
            List<dynamic> takipciler = userData['takipciler'] ?? [];
            List<dynamic> takipEdilenler = userData['takipEdilenler'] ?? [];

            return TabBarView(
              children: [
                // Tab 1: Takipçiler
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF2A2A35), width: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _filterChip('Tümü', _followersFilter, (val) {
                            setState(() {
                              _followersFilter = val;
                            });
                          }),
                          _filterChip('Geri Takip Etmediklerim', _followersFilter, (val) {
                            setState(() {
                              _followersFilter = val;
                            });
                          }),
                          _filterChip('Karşılıklı', _followersFilter, (val) {
                            setState(() {
                              _followersFilter = val;
                            });
                          }),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildUsersList(
                        takipciler,
                        isFollowersTab: true,
                        myFollowers: takipciler,
                        myFollowing: takipEdilenler,
                        activeFilter: _followersFilter,
                      ),
                    ),
                  ],
                ),
                // Tab 2: Takip Edilenler
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF2A2A35), width: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _filterChip('Tümü', _followingFilter, (val) {
                            setState(() {
                              _followingFilter = val;
                            });
                          }),
                          _filterChip('Beni Takip Etmeyenler', _followingFilter, (val) {
                            setState(() {
                              _followingFilter = val;
                            });
                          }),
                          _filterChip('Karşılıklı', _followingFilter, (val) {
                            setState(() {
                              _followingFilter = val;
                            });
                          }),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildUsersList(
                        takipEdilenler,
                        isFollowersTab: false,
                        myFollowers: takipciler,
                        myFollowing: takipEdilenler,
                        activeFilter: _followingFilter,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUsersList(
    List<dynamic> targetUids, {
    required bool isFollowersTab,
    required List<dynamic> myFollowers,
    required List<dynamic> myFollowing,
    required String activeFilter,
  }) {
    if (targetUids.isEmpty) {
      return const Center(
        child: Text(
          'Gösterilecek kullanıcı bulunmuyor.',
          style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('kullanicilar').snapshots(),
      builder: (context, usersSnap) {
        if (usersSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
        }

        var allUsers = usersSnap.data?.docs ?? [];
        var listUsers = allUsers.where((uDoc) => targetUids.contains(uDoc.id)).toList();

        // Apply filters
        if (isFollowersTab) {
          if (activeFilter == 'Geri Takip Etmediklerim') {
            listUsers = listUsers.where((uDoc) => !myFollowing.contains(uDoc.id)).toList();
          } else if (activeFilter == 'Karşılıklı') {
            listUsers = listUsers.where((uDoc) => myFollowing.contains(uDoc.id)).toList();
          }
        } else {
          if (activeFilter == 'Beni Takip Etmeyenler') {
            listUsers = listUsers.where((uDoc) => !myFollowers.contains(uDoc.id)).toList();
          } else if (activeFilter == 'Karşılıklı') {
            listUsers = listUsers.where((uDoc) => myFollowers.contains(uDoc.id)).toList();
          }
        }

        if (listUsers.isEmpty) {
          return const Center(
            child: Text(
              'Gösterilecek kullanıcı bulunmuyor.',
              style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
            ),
          );
        }

        return ListView.builder(
          itemCount: listUsers.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            var uDoc = listUsers[index];
            var uData = uDoc.data() as Map<String, dynamic>;
            String targetId = uDoc.id;
            String isim = uData['kullaniciAdi'] ?? 'Kapsülcü';
            String foto = uData['profilFotoUrl'] ?? '';
            String biyo = uData['biyografi'] ?? '';

            bool isFollowingTarget = myFollowing.contains(targetId);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DigerProfilEkran(hedefUid: targetId),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF0A0A0E),
                    backgroundImage: foto.isNotEmpty
                        ? CachedNetworkImageProvider(foto)
                        : null,
                    child: foto.isEmpty
                        ? const Icon(Icons.person, color: Color(0xFFA1A1AA))
                        : null,
                  ),
                ),
                title: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DigerProfilEkran(hedefUid: targetId),
                      ),
                    );
                  },
                  child: Text(
                    isim,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                subtitle: Text(
                  biyo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF71717A), fontSize: 12),
                ),
                trailing: targetId == _mevcutUid
                    ? null
                    : SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowingTarget ? Colors.transparent : const Color(0xFF4A90E2),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            side: BorderSide(
                              color: isFollowingTarget ? const Color(0xFF2A2A35) : Colors.transparent,
                              width: 1.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () {
                            if (isFollowingTarget) {
                              _takiptenCik(targetId);
                            } else {
                              _geriTakipEt(targetId);
                            }
                          },
                          child: Text(
                            isFollowingTarget ? 'Takipten Çık' : 'Takip Et',
                            style: TextStyle(
                              color: isFollowingTarget ? const Color(0xFFA1A1AA) : Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChip(String text, String currentFilter, ValueChanged<String> onSelected) {
    bool active = currentFilter == text;
    return GestureDetector(
      onTap: () => onSelected(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4A90E2).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFF4A90E2) : const Color(0xFF2A2A35),
            width: 0.5,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? const Color(0xFF4A90E2) : const Color(0xFF71717A),
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
