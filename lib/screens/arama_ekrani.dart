import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:odak_kapsulu/screens/diger_profil_ekrani.dart';
import 'package:odak_kapsulu/screens/dm_sohbet_ekrani.dart';

class AramaEkran extends StatefulWidget {
  const AramaEkran({super.key});

  @override
  State<AramaEkran> createState() => _AramaEkranState();
}

class _AramaEkranState extends State<AramaEkran> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFF0A0A0E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF141419),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) {
                setState(() {
                  _query = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Kişi veya mesaj ara...',
                hintStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2), size: 18),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                        child: const Icon(Icons.cancel, color: Color(0xFF71717A), size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A2A35), width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF4A90E2),
              indicatorWeight: 2,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF71717A),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              tabs: const [
                Tab(text: 'Kişiler'),
                Tab(text: 'Mesajlar'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('kullanicilar').snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
          }

          // Build a helper map to resolve user information instantly in memory
          Map<String, Map<String, dynamic>> userLookup = {};
          List<DocumentSnapshot> allUsers = userSnapshot.data?.docs ?? [];
          for (var doc in allUsers) {
            userLookup[doc.id] = doc.data() as Map<String, dynamic>;
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // 1. Users Tab
              Builder(
                builder: (context) {
                  var filteredUsers = allUsers.where((doc) {
                    if (doc.id == _mevcutUid) return false; // Hide self
                    var data = doc.data() as Map<String, dynamic>;
                    String name = (data['kullaniciAdi'] ?? '').toString().toLowerCase();
                    return name.contains(_query.toLowerCase());
                  }).toList();

                  if (filteredUsers.isEmpty) {
                    return const Center(
                      child: Text(
                        'Sonuç bulunamadı.',
                        style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      var doc = filteredUsers[index];
                      var data = doc.data() as Map<String, dynamic>;
                      String kullaniciAdi = data['kullaniciAdi'] ?? 'Kapsülcü';
                      String profilFotoUrl = data['profilFotoUrl'] ?? '';
                      String biyografi = data['biyografi'] ?? 'Henüz bir biyografi yazılmamış.';

                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 20,
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
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                            subtitle: Text(
                              biyografi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DigerProfilEkran(hedefUid: doc.id),
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
              ),

              // 2. Messages Tab
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('dmler')
                    .where('katilimcilar', arrayContains: _mevcutUid)
                    .snapshots(),
                builder: (context, dmSnapshot) {
                  if (dmSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
                  }

                  var dmDocs = dmSnapshot.data?.docs ?? [];
                  var filteredDMs = dmDocs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    List<dynamic> katilimcilar = data['katilimcilar'] ?? [];
                    String targetUid = katilimcilar.firstWhere((uid) => uid != _mevcutUid, orElse: () => '');
                    
                    if (targetUid.isEmpty || !userLookup.containsKey(targetUid)) return false;

                    var targetUser = userLookup[targetUid]!;
                    String targetName = (targetUser['kullaniciAdi'] ?? '').toString().toLowerCase();
                    String sonMesaj = (data['sonMesaj'] ?? '').toString().toLowerCase();
                    
                    String q = _query.toLowerCase();
                    return targetName.contains(q) || sonMesaj.contains(q);
                  }).toList();

                  if (filteredDMs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Sonuç bulunamadı.',
                        style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredDMs.length,
                    itemBuilder: (context, index) {
                      var doc = filteredDMs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      List<dynamic> katilimcilar = data['katilimcilar'] ?? [];
                      String targetUid = katilimcilar.firstWhere((uid) => uid != _mevcutUid, orElse: () => '');

                      var targetUser = userLookup[targetUid]!;
                      String kullaniciAdi = targetUser['kullaniciAdi'] ?? 'Kapsülcü';
                      String profilFotoUrl = targetUser['profilFotoUrl'] ?? '';
                      String sonMesaj = data['sonMesaj'] ?? 'Sohbeti başlatın...';

                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 20,
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
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                            subtitle: Text(
                              sonMesaj,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
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
              ),
            ],
          );
        },
      ),
    );
  }
}
