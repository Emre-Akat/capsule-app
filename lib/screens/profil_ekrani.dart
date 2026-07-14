import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:odak_kapsulu/screens/ayarlar_ekrani.dart';
import 'package:odak_kapsulu/screens/takip_yonetimi_ekrani.dart';
import 'package:odak_kapsulu/screens/diger_profil_ekrani.dart';
import 'package:odak_kapsulu/screens/magaza_ekrani.dart';

class ProfilEkran extends StatefulWidget {
  const ProfilEkran({super.key});

  @override
  State<ProfilEkran> createState() => _ProfilEkranState();
}

class _ProfilEkranState extends State<ProfilEkran> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  int _xp = 0;
  String _kullaniciAdi = "Kapsülcü";
  String _biyografi = "Henüz bir hedef belirlenmemiş.";
  String _profilFotoUrl = "";
  bool _yukleniyorMu = false;
  int _gunlukOdakDakikasi = 0;
  int _seriSayisi = 0;
  List<dynamic> _takipciler = [];
  List<dynamic> _takipEdilenler = [];
  int _gonderiSayisi = 0;
  int _sparkPuani = 0;
  int _jeton = 0;
  int _kalkanSayisi = 0;
  List<dynamic> _rozetler = [];
  List<dynamic> _hedefler = [];

  late final TabController _tabController;
  StreamSubscription? _profilAboneligi;
  bool _streakChecked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profilVerileriniDinle();
  }

  @override
  void dispose() {
    _profilAboneligi?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _profilVerileriniDinle() {
    if (_mevcutUid.isEmpty) return;
    _profilAboneligi = _firestore
        .collection('kullanicilar')
        .doc(_mevcutUid)
        .snapshots()
        .listen((belge) {
      if (belge.exists && mounted) {
        final data = belge.data()!;
        setState(() {
          _xp = data['xp'] ?? 0;
          _kullaniciAdi = data['kullaniciAdi'] ?? "Kapsülcü";
          _biyografi = data['biyografi'] ?? "Henüz bir hedef belirlenmemiş.";
          _profilFotoUrl = data['profilFotoUrl'] ?? "";
          _gunlukOdakDakikasi = data['gunlukOdakDakikasi'] ?? 0;
          _seriSayisi = data['seriSayisi'] ?? 0;
          _takipciler = data['takipciler'] ?? [];
          _takipEdilenler = data['takipEdilenler'] ?? [];
          _gonderiSayisi = data['gonderiSayisi'] ?? 0;
          _sparkPuani = data['sparkPuani'] ?? 0;
          _jeton = data['jeton'] ?? 0;
          _kalkanSayisi = data['kalkanSayisi'] ?? 0;
          _rozetler = data['rozetler'] ?? [];
          _hedefler = data['hedefler'] ?? [];
        });

        if (!_streakChecked) {
          _streakChecked = true;
          _checkStreakFreeze(data);
        }
      }
    });
  }

  void _checkStreakFreeze(Map<String, dynamic> data) async {
    DateTime now = DateTime.now();
    DateTime todayOnly = DateTime(now.year, now.month, now.day);

    DateTime? lastLoginDate;
    if (data['sonGirisTarihi'] != null) {
      lastLoginDate = (data['sonGirisTarihi'] as Timestamp).toDate();
    } else if (data['sonOdakTarihi'] != null) {
      lastLoginDate = (data['sonOdakTarihi'] as Timestamp).toDate();
    }

    if (lastLoginDate != null) {
      DateTime lastLoginOnly = DateTime(lastLoginDate.year, lastLoginDate.month, lastLoginDate.day);
      int dayDifference = todayOnly.difference(lastLoginOnly).inDays;

      if (dayDifference > 1 && (data['seriSayisi'] ?? 0) > 0) {
        int kalkanSayisi = data['kalkanSayisi'] ?? 0;
        if (kalkanSayisi > 0) {
          await _firestore.collection('kullanicilar').doc(_mevcutUid).update({
            'kalkanSayisi': FieldValue.increment(-1),
            'sonGirisTarihi': Timestamp.fromDate(now),
            'sonOdakTarihi': Timestamp.fromDate(now),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.shield_rounded, color: Color(0xFF4A90E2)),
                    SizedBox(width: 10),
                    Expanded(child: Text('Seri Koruma Kalkanı kullanıldı! Serin korundu. 🛡️', style: TextStyle(color: Colors.white))),
                  ],
                ),
                backgroundColor: Color(0xFF141419),
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          final streakAtReset = data['seriSayisi'] ?? 0;
          final alreadyBroadcast = data['dedikoduYayinlandiMi'] ?? false;

          await _firestore.collection('kullanicilar').doc(_mevcutUid).update({
            'seriSayisi': 0,
            'sonGirisTarihi': Timestamp.fromDate(now),
            'dedikoduYayinlandiMi': true,
          });

          if (streakAtReset > 0 && !alreadyBroadcast) {
            final String kullaniciAdi = data['kullaniciAdi'] ?? 'Biri';
            final List<dynamic> takipciler = data['takipciler'] ?? [];

            final WriteBatch batch = _firestore.batch();
            for (final followerUid in takipciler) {
              final notifRef = _firestore
                  .collection('kullanicilar')
                  .doc(followerUid.toString())
                  .collection('bildirimler')
                  .doc();
              batch.set(notifRef, {
                'tip': 'sistem_dedikodu',
                'gonderenId': _mevcutUid,
                'mesaj': 'Dedikoduyu duydun mu? 👀 $kullaniciAdi o efsanevi serisini bozdu!',
                'tarih': FieldValue.serverTimestamp(),
                'okunduMu': false,
              });
            }
            await batch.commit();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Odaklanma seriniz sıfırlandı. 😢 Takipçilerin haberdar edildi!', style: TextStyle(color: Colors.white)),
                backgroundColor: Color(0xFFFF453A),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        if (dayDifference != 0) {
          await _firestore.collection('kullanicilar').doc(_mevcutUid).update({
            'sonGirisTarihi': Timestamp.fromDate(now),
            'dedikoduYayinlandiMi': false,
          });
        }
      }
    } else {
      await _firestore.collection('kullanicilar').doc(_mevcutUid).update({
        'sonGirisTarihi': Timestamp.fromDate(now),
        'dedikoduYayinlandiMi': false,
      });
    }
  }

  void _profilFotoSecVeYukle() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _yukleniyorMu = true;
      });
      try {
        final storageRef = FirebaseStorage.instance.ref().child('profile_images/$_mevcutUid.jpg');
        
        UploadTask uploadTask = storageRef.putFile(File(pickedFile.path));
        TaskSnapshot snapshot = await uploadTask;
        String url = await snapshot.ref.getDownloadURL();
        
        await _firestore.collection('kullanicilar').doc(_mevcutUid).set({
          'profilFotoUrl': url,
        }, SetOptions(merge: true));
        
        setState(() {
          _profilFotoUrl = url;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil fotoğrafın güncellendi!', style: TextStyle(color: Colors.white)),
              backgroundColor: Color(0xFF30D158),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Yükleme sırasında hata oluştu: $e', style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFFFF453A),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _yukleniyorMu = false;
          });
        }
      }
    }
  }

  void _profilDuzenleDialogGoster() {
    final TextEditingController isimController = TextEditingController(text: _kullaniciAdi);
    final TextEditingController bioController = TextEditingController(text: _biyografi);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141419),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A2A35), width: 1),
          ),
          title: const Text('Profili Düzenle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: isimController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  labelStyle: const TextStyle(color: Color(0xFF71717A)),
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
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Hakkımda / Hedefler',
                  labelStyle: const TextStyle(color: Color(0xFF71717A)),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İPTAL', style: TextStyle(color: Color(0xFF71717A))),
            ),
            TextButton(
              onPressed: () async {
                String yeniIsim = isimController.text.trim();
                String yeniBio = bioController.text.trim();
                
                if (yeniIsim.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  await _firestore.collection('kullanicilar').doc(_mevcutUid).set({
                    'kullaniciAdi': yeniIsim,
                    'biyografi': yeniBio,
                  }, SetOptions(merge: true));
                  
                  navigator.pop();
                }
              },
              child: const Text('KAYDET', style: TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.bold)),
            ),
          ],
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

  void _yorumYap(String postId, String commentText, String postGonderenUid) async {
    if (commentText.isEmpty || _mevcutUid.isEmpty) return;

    final postRef = _firestore.collection('gonderiler').doc(postId);
    final commentRef = postRef.collection('yorumlar').doc();
    final userRef = _firestore.collection('kullanicilar').doc(_mevcutUid);

    await _firestore.runTransaction((transaction) async {
      transaction.set(commentRef, {
        'yorumcuId': _mevcutUid,
        'yorumcuIsim': _kullaniciAdi,
        'yorumcuProfilFoto': _profilFotoUrl,
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

  void _yorumBottomSheetGoster(String postId, String postGonderenUid) {
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
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DigerProfilEkran(hedefUid: yData['yorumcuId'] ?? ''),
                                        ),
                                      );
                                    },
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFF0A0A0E),
                                      backgroundImage: yFoto.isNotEmpty
                                          ? CachedNetworkImageProvider(yFoto)
                                          : null,
                                      child: yFoto.isEmpty
                                          ? const Icon(Icons.person, size: 16, color: Color(0xFFA1A1AA))
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => DigerProfilEkran(hedefUid: yData['yorumcuId'] ?? ''),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                yIsim,
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
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
                              _yorumYap(postId, text, postGonderenUid);
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

  void _magazaBottomSheetGoster() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MagazaEkran()),
    );
  }

  int getSeviye(int xp) => (xp / 500).floor() + 1;

  Color? getAvatarFrameColor(int spark) {
    if (spark >= 1000) return const Color(0xFFFFD700);
    if (spark >= 500)  return const Color(0xFFB026FF);
    if (spark >= 100)  return const Color(0xFF00FFFF);
    return null;
  }

  String _prestijRozetAdi(String key) {
    switch (key) {
      case '30_gun_seri':   return '🔥 Kapsül Lordu (30 Gün)';
      case 'ilk_100_pilot': return '🚀 Öncü Pilot';
      case '1000_spark':    return '⚡ Yüksek Frekans';
      case 'altin_cerceve': return '✨ Altın Profil Çerçevesi';
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
                      color: const Color(0xFF4A90E2).withOpacity(0.08),
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
    if (seviye == 1) return 'Çaylak Kapsülcü';
    if (seviye == 2) return 'Deneyimli Pilot';
    if (seviye >= 3) return 'Usta Odaklayıcı';
    return 'Gezgin';
  }

  Widget _buildPostList({required String filterMode}) {
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
            return d['gonderenUid'] == _mevcutUid;
          }).toList();
        } else if (filterMode == 'repost') {
          displayPosts = allPosts.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            List<dynamic> reposters = d['yenidenPaylasanlar'] ?? [];
            return reposters.contains(_mevcutUid);
          }).toList();
        } else {
          displayPosts = allPosts.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            String metin = d['metin'] ?? '';
            return metin.toLowerCase().contains('@${_kullaniciAdi.toLowerCase()}');
          }).toList();
        }
        if (displayPosts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                filterMode == 'gonderi'
                    ? 'Henüz bir gönderi paylaşmadınız.'
                    : filterMode == 'repost'
                        ? 'Yeniden paylaştığınız bir gönderi bulunmuyor.'
                        : 'Etiketlendiğiniz bir gönderi bulunmuyor.',
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
                            '$_kullaniciAdi yeniden paylaştı',
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
                              onTap: () => _yorumBottomSheetGoster(postId, postGonderenUid),
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
    final int seviye = getSeviye(_xp);
    final String unvan = getUnvan(seviye);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: AppBar(
        title: const Text('KAPSÜL KİMLİĞİ',
            style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0E),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Ayarlar',
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AyarlarEkran())),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: const Color(0xFF2A2A35), height: 0.5),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Avatar & Stats ──────────────────────────
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _yukleniyorMu ? null : _profilFotoSecVeYukle,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Builder(builder: (ctx) {
                              final Color? frameColor = getAvatarFrameColor(_sparkPuani);
                              final bool isGold = _sparkPuani >= 1000;
                              return Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: frameColor != null ? Border.all(color: frameColor, width: 3) : null,
                                  boxShadow: (frameColor != null && isGold)
                                      ? [BoxShadow(color: frameColor.withOpacity(0.55), blurRadius: 18, spreadRadius: 2)]
                                      : (frameColor != null)
                                          ? [BoxShadow(color: frameColor.withOpacity(0.35), blurRadius: 12, spreadRadius: 1)]
                                          : null,
                                ),
                                child: CircleAvatar(
                                  radius: 36,
                                  backgroundColor: const Color(0xFF141419),
                                  backgroundImage: _profilFotoUrl.isNotEmpty && !_yukleniyorMu
                                      ? CachedNetworkImageProvider(_profilFotoUrl)
                                      : null,
                                  child: _yukleniyorMu
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A90E2)))
                                      : _profilFotoUrl.isEmpty
                                          ? const Icon(Icons.person, size: 36, color: Color(0xFFA1A1AA))
                                          : null,
                                ),
                              );
                            }),
                            if (!_yukleniyorMu)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white70),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _tabController.animateTo(0);
                              },
                              child: Column(
                                children: [
                                  Text('$_gonderiSayisi',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  const Text('Gönderi', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                                ],
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (_mevcutUid.isNotEmpty) {
                                  Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => TakipYonetimiEkran(uid: _mevcutUid, isFollowersDefault: true)));
                                }
                              },
                              child: Column(
                                children: [
                                  Text('${_takipciler.length}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  const Text('Takipçi', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                                ],
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (_mevcutUid.isNotEmpty) {
                                  Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => TakipYonetimiEkran(uid: _mevcutUid, isFollowersDefault: false)));
                                }
                              },
                              child: Column(
                                children: [
                                  Text('${_takipEdilenler.length}',
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
                  // ─── Username & Streak ───────────────────
                  Row(
                    children: [
                      Text(_kullaniciAdi,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (_seriSayisi > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 3),
                              Text('$_seriSayisi Gün',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                            ],
                          ),
                        ),
                      ],
                      if (_kalkanSayisi > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.3), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🛡️', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 3),
                              Text('$_kalkanSayisi',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(unvan,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF71717A), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('⚡ $_sparkPuani Spark',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF4A90E2), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Text('🪙 $_jeton Jeton',
                          style: const TextStyle(fontSize: 13, color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_biyografi,
                      style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4)),
                  // Badge Showcase
                  _buildBadgeShowcase(_rozetler),
                  const SizedBox(height: 24),
                  // ─── XP Progress Card ────────────────────────
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
                            Text('$_xp / ${seviye * 500} XP',
                                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 6,
                            child: LinearProgressIndicator(
                              value: (_xp % 500) / 500.0,
                              backgroundColor: const Color(0xFF0A0A0E),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Bugünkü Odak: $_gunlukOdakDakikasi / 600 dk',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ─── Edit Profile & Market ───────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _profilDuzenleDialogGoster,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF141419),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
                            ),
                            child: const Center(
                              child: Text('Profili Düzenle',
                                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _magazaBottomSheetGoster,
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141419),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.shopping_bag_outlined, color: Color(0xFF4A90E2), size: 18),
                              SizedBox(width: 8),
                              Text('Market',
                                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCountdownSection(_hedefler),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
        // ─── Sticky TabBar ─────────────────────────────
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
                  _buildPostList(filterMode: 'gonderi'),
                  _buildPostList(filterMode: 'repost'),
                  _buildPostList(filterMode: 'etiket'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
