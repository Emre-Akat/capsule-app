import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:odak_kapsulu/screens/dm_sohbet_ekrani.dart';
import 'package:odak_kapsulu/screens/takip_yonetimi_ekrani.dart';

class DigerProfilEkran extends StatefulWidget {
  final String hedefUid;

  const DigerProfilEkran({super.key, required this.hedefUid});

  @override
  State<DigerProfilEkran> createState() => _DigerProfilEkranState();
}

class _DigerProfilEkranState extends State<DigerProfilEkran> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  StreamSubscription? _mevcutKullaniciSub;
  List<dynamic> _engellenenler = [];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _mevcutKullaniciDinle();
    _ziyaretKaydet();
  }

  @override
  void dispose() {
    _mevcutKullaniciSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _mevcutKullaniciDinle() {
    if (_mevcutUid.isEmpty) return;
    _mevcutKullaniciSub = _firestore
        .collection('kullanicilar')
        .doc(_mevcutUid)
        .snapshots()
        .listen((belge) {
      if (belge.exists && mounted) {
        setState(() {
          _engellenenler = belge.data()?['engellenenler'] ?? [];
        });
      }
    });
  }

  void _ziyaretKaydet() async {
    if (_mevcutUid.isEmpty || _mevcutUid == widget.hedefUid) return;

    // Fetch visitor's username first
    final visitorSnap = await _firestore.collection('kullanicilar').doc(_mevcutUid).get();
    final String visitorName = visitorSnap.data()?['kullaniciAdi'] ?? 'Bir Kapsülcü';

    final docRef = _firestore
        .collection('kullanicilar')
        .doc(widget.hedefUid)
        .collection('profilZiyaretleri')
        .doc(_mevcutUid);

    await _firestore.runTransaction((transaction) async {
      var snap = await transaction.get(docRef);
      int sayac = 1;
      if (snap.exists) {
        sayac = (snap.data()?['ziyaretSayisi'] ?? 0) + 1;
      }

      transaction.set(docRef, {
        'ziyaretSayisi': sayac,
        'sonZiyaret': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Trigger stalker alert exactly ONCE per threshold
      if (sayac == 3) {
        final notifyRef = _firestore
            .collection('kullanicilar')
            .doc(widget.hedefUid)
            .collection('bildirimler')
            .doc();
        transaction.set(notifyRef, {
          'tip': 'stalker_gizli',
          'gonderenId': 'sistem',
          'mesaj': 'Biri profilini gözetliyor... 👁️',
          'tarih': FieldValue.serverTimestamp(),
          'okunduMu': false,
        });
      } else if (sayac == 6) {
        final notifyRef = _firestore
            .collection('kullanicilar')
            .doc(widget.hedefUid)
            .collection('bildirimler')
            .doc();
        transaction.set(notifyRef, {
          'tip': 'stalker_acik',
          'gonderenId': _mevcutUid,
          'mesaj': 'Gizli bir hayranın var galiba! $visitorName profilini 5\'ten fazla kez inceledi. İstersen bir selam ver ✨',
          'tarih': FieldValue.serverTimestamp(),
          'okunduMu': false,
        });
      }
    });
  }

  void _takipDurumuDegistir(bool takipEdiliyorMu) async {
    if (_mevcutUid.isEmpty) return;

    final targetRef = _firestore.collection('kullanicilar').doc(widget.hedefUid);
    final currentUserRef = _firestore.collection('kullanicilar').doc(_mevcutUid);

    if (takipEdiliyorMu) {
      // Unfollow
      await _firestore.runTransaction((transaction) async {
        transaction.update(targetRef, {
          'takipciler': FieldValue.arrayRemove([_mevcutUid])
        });
        transaction.update(currentUserRef, {
          'takipEdilenler': FieldValue.arrayRemove([widget.hedefUid])
        });
      });

      // Write 'sistem' notification (unfollow)
      await _firestore.collection('kullanicilar').doc(widget.hedefUid).collection('bildirimler').add({
        'tip': 'unfollow',
        'gonderenId': _mevcutUid,
        'mesaj': 'Bir kullanıcı seni takipten çıktı.',
        'tarih': FieldValue.serverTimestamp(),
        'okunduMu': false,
      });
    } else {
      // Follow
      await _firestore.runTransaction((transaction) async {
        transaction.update(targetRef, {
          'takipciler': FieldValue.arrayUnion([_mevcutUid])
        });
        transaction.update(currentUserRef, {
          'takipEdilenler': FieldValue.arrayUnion([widget.hedefUid])
        });
      });

      // Write 'takip' notification to User B
      await _firestore.collection('kullanicilar').doc(widget.hedefUid).collection('bildirimler').add({
        'tip': 'takip',
        'gonderenId': _mevcutUid,
        'mesaj': 'seni takip etmeye başladı.',
        'tarih': FieldValue.serverTimestamp(),
        'okunduMu': false,
      });
    }
  }

  void _engelleDurumuDegistir(bool engellenmisMi) async {
    if (_mevcutUid.isEmpty) return;
    final userRef = _firestore.collection('kullanicilar').doc(_mevcutUid);
    final messenger = ScaffoldMessenger.of(context);

    if (engellenmisMi) {
      await userRef.update({
        'engellenenler': FieldValue.arrayRemove([widget.hedefUid])
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Kullanıcının engeli kaldırıldı.', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF30D158),
        ),
      );
    } else {
      await userRef.update({
        'engellenenler': FieldValue.arrayUnion([widget.hedefUid])
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı engellendi.', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFFFF453A),
        ),
      );
    }
  }

  void _sikayetEtDialogGoster() {
    final TextEditingController sebepController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141419),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A2A35), width: 1),
          ),
          title: const Text('Şikayet Et', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: sebepController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Şikayet sebebini yazın...',
              hintStyle: const TextStyle(color: Color(0xFF71717A)),
              filled: true,
              fillColor: const Color(0xFF0A0A0E),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A2A35)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4A90E2)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İPTAL', style: TextStyle(color: Color(0xFF71717A))),
            ),
            TextButton(
              onPressed: () async {
                String sebep = sebepController.text.trim();
                if (sebep.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  await _firestore.collection('sikayetler').add({
                    'raporEden': _mevcutUid,
                    'raporEdilen': widget.hedefUid,
                    'sebep': sebep,
                    'tarih': FieldValue.serverTimestamp(),
                  });
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Şikayetiniz incelemeye alındı.', style: TextStyle(color: Colors.white)),
                      backgroundColor: Color(0xFF30D158),
                    ),
                  );
                }
              },
              child: const Text('GÖNDER', style: TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _secenekleriGoster() {
    bool engellenmisMi = _engellenenler.contains(widget.hedefUid);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141419),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.white70),
                title: const Text('Şikayet Et', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(context);
                  _sikayetEtDialogGoster();
                },
              ),
              ListTile(
                leading: Icon(
                  engellenmisMi ? Icons.check_circle_outline : Icons.block_flipped,
                  color: const Color(0xFFFF453A),
                ),
                title: Text(
                  engellenmisMi ? 'Engeli Kaldır' : 'Engelle',
                  style: const TextStyle(color: Color(0xFFFF453A)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _engelleDurumuDegistir(engellenmisMi);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _likeToggled(String postId, List<dynamic> begenenler, String postGonderenUid) async {
    if (_mevcutUid.isEmpty) return;

    final bool begenmisMi = begenenler.contains(_mevcutUid);
    final postRef = _firestore.collection('gonderiler').doc(postId);

    if (begenmisMi) {
      await postRef.update({
        'begenenler': FieldValue.arrayRemove([_mevcutUid])
      });
    } else {
      await postRef.update({
        'begenenler': FieldValue.arrayUnion([_mevcutUid])
      });

      // Send notification if not self
      if (postGonderenUid != _mevcutUid) {
        await _firestore.collection('kullanicilar').doc(postGonderenUid).collection('bildirimler').add({
          'tip': 'begen',
          'gonderenId': _mevcutUid,
          'mesaj': 'gönderini beğendi 🔥',
          'tarih': FieldValue.serverTimestamp(),
          'okunduMu': false,
        });
      }
    }
  }

  void _repostToggled(String postId, List<dynamic> yenidenPaylasanlar, String postGonderenUid) async {
    if (_mevcutUid.isEmpty) return;

    final bool isReposted = yenidenPaylasanlar.contains(_mevcutUid);
    final postRef = _firestore.collection('gonderiler').doc(postId);

    if (isReposted) {
      await postRef.update({
        'yenidenPaylasanlar': FieldValue.arrayRemove([_mevcutUid])
      });
    } else {
      await postRef.update({
        'yenidenPaylasanlar': FieldValue.arrayUnion([_mevcutUid])
      });

      // Send notification if not self
      if (postGonderenUid != _mevcutUid) {
        await _firestore.collection('kullanicilar').doc(postGonderenUid).collection('bildirimler').add({
          'tip': 'repost',
          'gonderenId': _mevcutUid,
          'mesaj': 'gönderini yeniden paylaştı 🔁',
          'tarih': FieldValue.serverTimestamp(),
          'okunduMu': false,
        });
      }
    }
  }

  void _yorumYap(String postId, String commentText, String postGonderenUid, String myUsername, String myFoto) async {
    if (commentText.isEmpty || _mevcutUid.isEmpty) return;

    final postRef = _firestore.collection('gonderiler').doc(postId);
    final commentRef = postRef.collection('yorumlar').doc();
    final userRef = _firestore.collection('kullanicilar').doc(_mevcutUid);

    await _firestore.runTransaction((transaction) async {
      transaction.set(commentRef, {
        'yorumcuId': _mevcutUid,
        'yorumcuIsim': myUsername,
        'yorumcuProfilFoto': myFoto,
        'metin': commentText,
        'tarih': FieldValue.serverTimestamp(),
      });
      transaction.update(postRef, {
        'yorumSayisi': FieldValue.increment(1)
      });
      transaction.update(userRef, {
        'sparkPuani': FieldValue.increment(5)
      });
    });

    if (postGonderenUid != _mevcutUid) {
      await _firestore.collection('kullanicilar').doc(postGonderenUid).collection('bildirimler').add({
        'tip': 'yorum',
        'gonderenId': _mevcutUid,
        'mesaj': 'gönderine yorum yaptı: "$commentText"',
        'tarih': FieldValue.serverTimestamp(),
        'okunduMu': false,
      });
    }
  }

  String _formatZaman(dynamic zaman) {
    if (zaman == null) return "Şimdi";
    if (zaman is Timestamp) {
      DateTime dt = zaman.toDate();
      Duration diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return "${diff.inMinutes}d";
      if (diff.inHours < 24) return "${diff.inHours}sa";
      return "${diff.inDays}g";
    }
    return "";
  }

  void _yorumBottomSheetGoster(String postId, String postGonderenUid, String myUsername, String myFoto) {
    final TextEditingController yorumController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141419),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Container(
              height: 400,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Yorumlar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('gonderiler')
                          .doc(postId)
                          .collection('yorumlar')
                          .orderBy('tarih', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
                        }

                        var yorumDocs = snapshot.data?.docs ?? [];
                        if (yorumDocs.isEmpty) {
                          return const Center(
                            child: Text(
                              'İlk yorumu sen yaz.',
                              style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: yorumDocs.length,
                          itemBuilder: (context, index) {
                            var yData = yorumDocs[index].data() as Map<String, dynamic>;
                            String yIsim = yData['yorumcuIsim'] ?? 'Kapsülcü';
                            String yFoto = yData['yorumcuProfilFoto'] ?? '';
                            String yMetin = yData['metin'] ?? '';
                            String yZaman = _formatZaman(yData['tarih']);

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF0A0A0E),
                                    backgroundImage: yFoto.isNotEmpty
                                        ? CachedNetworkImageProvider(yFoto)
                                        : null,
                                    child: yFoto.isEmpty
                                        ? const Icon(Icons.person, size: 16, color: Color(0xFFA1A1AA))
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              yIsim,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              yZaman,
                                              style: const TextStyle(color: Color(0xFF71717A), fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          yMetin,
                                          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF2A2A35), width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: yorumController,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: 'Yorum yazın...',
                              hintStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF0A0A0E),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Color(0xFF2A2A35)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Color(0xFF4A90E2)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFF4A90E2), size: 20),
                          onPressed: () {
                            String text = yorumController.text.trim();
                            if (text.isNotEmpty) {
                              _yorumYap(postId, text, postGonderenUid, myUsername, myFoto);
                              yorumController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int getSeviye(int xp) => (xp / 500).floor() + 1;

  /// Returns the frame color based on Spark score.
  Color? getAvatarFrameColor(int spark) {
    if (spark >= 1000) return const Color(0xFFFFD700);
    if (spark >= 500)  return const Color(0xFFB026FF);
    if (spark >= 100)  return const Color(0xFF00FFFF);
    return null;
  }

  /// Maps a badge key to its display label.
  String _prestijRozetAdi(String key) {
    switch (key) {
      case '30_gun_seri':   return '🔥 Kapsül Lordu (30 Gün)';
      case 'ilk_100_pilot': return '🚀 Öncü Pilot';
      case '1000_spark':    return '⚡ Yüksek Frekans';
      default:              return '🏆 $key';
    }
  }

  Widget _buildBadgeShowcase(List<dynamic> rozetler) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'PRESTİJ VİTRİNİ',
          style: TextStyle(
            color: Color(0xFF71717A),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        if (rozetler.isEmpty)
          const Text(
            'Rozetler keşfedilmeyi bekliyor...',
            style: TextStyle(color: Color(0xFF4A4A56), fontSize: 13, fontStyle: FontStyle.italic),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rozetler.map((r) {
              final String label = _prestijRozetAdi(r.toString());
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF141419),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildCountdownSection(List<dynamic> hedefler) {
    if (hedefler.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          '🎯 YAKLAŞAN HEDEFLER',
          style: TextStyle(
            color: Color(0xFF71717A),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        ...hedefler.map((h) {
          final map = h as Map<String, dynamic>;
          final String baslik = map['baslik'] ?? 'Hedef';
          bool completed = false;
          int kalanGun = 0;
          if (map['hedefTarih'] != null) {
            final DateTime hedefTarih = (map['hedefTarih'] as Timestamp).toDate();
            final hedefOnly = DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);
            kalanGun = hedefOnly.difference(today).inDays;
            completed = kalanGun < 0;
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF141419),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: completed ? const Color(0xFF4CAF50).withValues(alpha: 0.3) : const Color(0xFF2A2A35),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    baslik,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  completed ? '✔️ Tamamlandı' : '⚡ $kalanGun Gün Kaldı',
                  style: TextStyle(
                    color: completed ? const Color(0xFF4CAF50) : const Color(0xFF4A90E2),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String getUnvan(int seviye) {
    if (seviye == 1) return "Çaylak Kapsülcü";
    if (seviye == 2) return "Deneyimli Pilot";
    if (seviye >= 3) return "Usta Odaklayıcı";
    return "Gezgin";
  }

  Widget _buildOtherPostList({
    required String filterMode,
    required String targetUid,
    required String targetUsername,
    required String myUsername,
    required String myFoto,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('gonderiler').orderBy('zaman', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
        }
        var allPosts = snapshot.data?.docs ?? [];
        List<QueryDocumentSnapshot> displayPosts = [];

        if (filterMode == 'gonderi') {
          displayPosts = allPosts.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            return d['gonderenUid'] == targetUid;
          }).toList();
        } else if (filterMode == 'repost') {
          displayPosts = allPosts.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            List<dynamic> reposters = d['yenidenPaylasanlar'] ?? [];
            return reposters.contains(targetUid);
          }).toList();
        } else {
          displayPosts = allPosts.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            String metin = d['metin'] ?? '';
            return metin.toLowerCase().contains('@${targetUsername.toLowerCase()}');
          }).toList();
        }

        if (displayPosts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                filterMode == 'gonderi'
                    ? 'Henüz bir gönderi paylaşılmamış.'
                    : filterMode == 'repost'
                        ? 'Yeniden paylaştığı bir gönderi bulunmuyor.'
                        : 'Etiketlendikleri bir gönderi bulunmuyor.',
                style: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: displayPosts.length,
          itemBuilder: (context, index) {
            var doc = displayPosts[index];
            var post = doc.data() as Map<String, dynamic>;
            String postId = doc.id;
            String gProfilFoto = post['gonderenProfilFoto'] ?? '';
            String gIsim = post['gonderenIsim'] ?? 'Anonim';
            String metin = post['metin'] ?? '';
            String zamanText = _formatZaman(post['zaman']);
            List<dynamic> begenenler = post['begenenler'] ?? [];
            List<dynamic> yenidenPaylasanlar = post['yenidenPaylasanlar'] ?? [];
            int yorumSayisi = post['yorumSayisi'] ?? 0;
            String postGonderenUid = post['gonderenUid'] ?? '';

            bool isLiked = begenenler.contains(_mevcutUid);
            bool isReposted = yenidenPaylasanlar.contains(_mevcutUid);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A35), width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (filterMode == 'repost') ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.repeat_rounded, color: Color(0xFF30D158), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '$targetUsername yeniden paylaştı',
                            style: const TextStyle(color: Color(0xFF30D158), fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFF2A2A35), height: 1.0, thickness: 0.5),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF0A0A0E),
                        backgroundImage: gProfilFoto.isNotEmpty ? CachedNetworkImageProvider(gProfilFoto) : null,
                        child: gProfilFoto.isEmpty ? const Icon(Icons.person, size: 16, color: Color(0xFFA1A1AA)) : null,
                      ),
                      const SizedBox(width: 10),
                      Text(gIsim, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                      const Spacer(),
                      Text(zamanText, style: const TextStyle(color: Color(0xFF71717A), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 42.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(metin, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _likeToggled(postId, begenenler, postGonderenUid),
                              child: Row(
                                children: [
                                  Icon(
                                    isLiked ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
                                    color: isLiked ? Colors.orangeAccent : const Color(0xFF71717A), size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('${begenenler.length}', style: TextStyle(color: isLiked ? Colors.orangeAccent : const Color(0xFF71717A), fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () => _yorumBottomSheetGoster(postId, postGonderenUid, myUsername, myFoto),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF71717A), size: 16),
                                  const SizedBox(width: 5),
                                  Text('$yorumSayisi', style: const TextStyle(color: Color(0xFF71717A), fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () => _repostToggled(postId, yenidenPaylasanlar, postGonderenUid),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.repeat_rounded,
                                    color: isReposted ? const Color(0xFF30D158) : const Color(0xFF71717A), size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('${yenidenPaylasanlar.length}', style: TextStyle(color: isReposted ? const Color(0xFF30D158) : const Color(0xFF71717A), fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: AppBar(
        title: const Text('KULLANICI PROFİLİ', style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0E),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _secenekleriGoster,
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('kullanicilar').doc(widget.hedefUid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Kullanıcı bulunamadı.', style: TextStyle(color: Colors.white60)));
          }

          var targetData = snapshot.data!.data() as Map<String, dynamic>;
          final String kullaniciAdi = targetData['kullaniciAdi'] ?? 'Kapsülcü';
          final String biyografi = targetData['biyografi'] ?? 'Henüz bir hedef belirlenmemiş.';
          final String profilFotoUrl = targetData['profilFotoUrl'] ?? '';
          final int xp = targetData['xp'] ?? 0;
          final int seviye = getSeviye(xp);
          final String unvan = getUnvan(seviye);
          final int gonderiSayisi = targetData['gonderiSayisi'] ?? 0;
          final int sparkPuani = targetData['sparkPuani'] ?? 0;
          final List<dynamic> rozetler = targetData['rozetler'] ?? [];
          final List<dynamic> hedefler = targetData['hedefler'] ?? [];

          final List<dynamic> takipciler = targetData['takipciler'] ?? [];
          final List<dynamic> takipEdilenler = targetData['takipEdilenler'] ?? [];

          final bool takipEdiliyorMu = takipciler.contains(_mevcutUid);

          return StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('kullanicilar').doc(_mevcutUid).snapshots(),
            builder: (context, mySnap) {
              String myUsername = 'Kapsülcü';
              String myFoto = '';
              if (mySnap.hasData && mySnap.data!.exists) {
                var myData = mySnap.data!.data() as Map<String, dynamic>;
                myUsername = myData['kullaniciAdi'] ?? 'Kapsülcü';
                myFoto = myData['profilFotoUrl'] ?? '';
              }

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Avatar & horizontal stats
                          Row(
                            children: [
                              Builder(builder: (ctx) {
                                final Color? frameColor = getAvatarFrameColor(sparkPuani);
                                final bool isGold = sparkPuani >= 1000;
                                return Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: frameColor != null ? Border.all(color: frameColor, width: 3) : null,
                                    boxShadow: (frameColor != null && isGold)
                                        ? [BoxShadow(color: frameColor.withValues(alpha: 0.55), blurRadius: 18, spreadRadius: 2)]
                                        : (frameColor != null)
                                            ? [BoxShadow(color: frameColor.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: 1)]
                                            : null,
                                  ),
                                  child: CircleAvatar(
                                    radius: 36,
                                    backgroundColor: const Color(0xFF141419),
                                    backgroundImage: profilFotoUrl.isNotEmpty ? CachedNetworkImageProvider(profilFotoUrl) : null,
                                    child: profilFotoUrl.isEmpty ? const Icon(Icons.person, size: 36, color: Color(0xFFA1A1AA)) : null,
                                  ),
                                );
                              }),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _tabController.animateTo(0),
                                      child: Column(
                                        children: [
                                          Text('$gonderiSayisi',
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                          const SizedBox(height: 4),
                                          const Text('Gönderi', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => TakipYonetimiEkran(uid: widget.hedefUid, isFollowersDefault: true))),
                                      child: Column(
                                        children: [
                                          Text('${takipciler.length}',
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                          const SizedBox(height: 4),
                                          const Text('Takipçi', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => TakipYonetimiEkran(uid: widget.hedefUid, isFollowersDefault: false))),
                                      child: Column(
                                        children: [
                                          Text('${takipEdilenler.length}',
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                          const SizedBox(height: 4),
                                          const Text('Takip', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Username
                          Text(kullaniciAdi,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(unvan,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF71717A), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Text('⚡ $sparkPuani Spark',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF4A90E2), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(biyografi,
                              style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4)),
                          _buildBadgeShowcase(rozetler),
                          _buildCountdownSection(hedefler),
                          const SizedBox(height: 24),
                          // Follow / Unfollow Button
                          GestureDetector(
                            onTap: () => _takipDurumuDegistir(takipEdiliyorMu),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: takipEdiliyorMu ? Colors.transparent : const Color(0xFF4A90E2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: takipEdiliyorMu ? const Color(0xFF2A2A35) : Colors.transparent,
                                  width: 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  takipEdiliyorMu ? 'Takipten Çık' : 'Takip Et',
                                  style: TextStyle(
                                    color: takipEdiliyorMu ? const Color(0xFFA1A1AA) : Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (takipciler.contains(_mevcutUid) && takipEdilenler.contains(_mevcutUid)) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                String dmId = _mevcutUid.compareTo(widget.hedefUid) < 0
                                    ? '${_mevcutUid}_${widget.hedefUid}'
                                    : '${widget.hedefUid}_$_mevcutUid';
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => DmSohbetEkran(
                                    dmId: dmId,
                                    hedefUid: widget.hedefUid,
                                    hedefKullaniciAdi: kullaniciAdi,
                                  ),
                                ));
                              },
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141419),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
                                ),
                                child: const Center(
                                  child: Text('Mesaj Gönder',
                                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Level & Progress
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141419),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Seviye $seviye',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                    Text('$xp / ${seviye * 500} XP',
                                        style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    height: 6,
                                    child: LinearProgressIndicator(
                                      value: (xp % 500) / 500.0,
                                      backgroundColor: const Color(0xFF0A0A0E),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
                body: Column(
                  children: [
                    Container(
                      color: const Color(0xFF0A0A0E),
                      child: Column(
                        children: [
                          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFF2A2A35)),
                          TabBar(
                            controller: _tabController,
                            indicatorColor: const Color(0xFF4A90E2),
                            indicatorWeight: 2.5,
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFF71717A),
                            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(icon: Icon(Icons.grid_on_rounded, size: 18), text: 'Gönderiler'),
                              Tab(icon: Icon(Icons.repeat_rounded, size: 18), text: 'Repostlar'),
                              Tab(icon: Icon(Icons.person_pin_outlined, size: 18), text: 'Etiketler'),
                            ],
                          ),
                          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFF2A2A35)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOtherPostList(filterMode: 'gonderi', targetUid: widget.hedefUid, targetUsername: kullaniciAdi, myUsername: myUsername, myFoto: myFoto),
                          _buildOtherPostList(filterMode: 'repost', targetUid: widget.hedefUid, targetUsername: kullaniciAdi, myUsername: myUsername, myFoto: myFoto),
                          _buildOtherPostList(filterMode: 'etiket', targetUid: widget.hedefUid, targetUsername: kullaniciAdi, myUsername: myUsername, myFoto: myFoto),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
