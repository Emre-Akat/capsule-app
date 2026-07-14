import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:odak_kapsulu/screens/diger_profil_ekrani.dart';

class OdaIciEkran extends StatefulWidget {
  final String odaId;
  final String odaAdi;
  final String kurucuUid;

  const OdaIciEkran({
    super.key,
    required this.odaId,
    required this.odaAdi,
    required this.kurucuUid,
  });

  @override
  State<OdaIciEkran> createState() => _OdaIciEkranState();
}

class _OdaIciEkranState extends State<OdaIciEkran> {
  final TextEditingController _mesajKontrolcusu = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription? _mevcutKullaniciSub;
  List<dynamic> _engellenenler = [];

  @override
  void initState() {
    super.initState();
    _mevcutKullaniciDinle();
  }

  @override
  void dispose() {
    _mevcutKullaniciSub?.cancel();
    _mesajKontrolcusu.dispose();
    super.dispose();
  }

  void _mevcutKullaniciDinle() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _mevcutKullaniciSub = _firestore
        .collection('kullanicilar')
        .doc(user.uid)
        .snapshots()
        .listen((belge) {
      if (belge.exists && mounted) {
        setState(() {
          _engellenenler = belge.data()?['engellenenler'] ?? [];
        });
      }
    });
  }

  void _mesajGonder(String durum) async {
    if (_mesajKontrolcusu.text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String mevcutUid = user.uid;
    final String email = user.email ?? '';

    // SUPER ADMIN MESSAGE BYPASS (GOD MODE)
    final bool isSuperAdmin = email == 'yunusemreakattt@gmail.com';

    var userBelge = await _firestore.collection('kullanicilar').doc(mevcutUid).get();
    int guncelJeton = userBelge.data()?['jeton'] ?? 0;
    String aktifKullaniciAdi = userBelge.data()?['kullaniciAdi'] ?? "Anonim Kapsülcü";

    if (durum == 'MOLA' || isSuperAdmin) {
      await _firestore.collection('odalar').doc(widget.odaId).collection('mesajlar').add({
        'metin': _mesajKontrolcusu.text,
        'isImage': false,
        'imageUrl': '',
        'gonderen': aktifKullaniciAdi,
        'zaman': FieldValue.serverTimestamp(),
        'uid': mevcutUid,
      });

      // Post Counter Increments
      await _firestore.collection('kullanicilar').doc(mevcutUid).update({
        'gonderiSayisi': FieldValue.increment(1)
      });

      _mesajKontrolcusu.clear();
    } else {
      if (guncelJeton >= 1) {
        await _firestore.collection('kullanicilar').doc(mevcutUid).update({
          'jeton': guncelJeton - 1,
        });

        await _firestore.collection('odalar').doc(widget.odaId).collection('mesajlar').add({
          'metin': _mesajKontrolcusu.text,
          'isImage': false,
          'imageUrl': '',
          'gonderen': aktifKullaniciAdi,
          'zaman': FieldValue.serverTimestamp(),
          'uid': mevcutUid,
        });

        // Post Counter Increments
        await _firestore.collection('kullanicilar').doc(mevcutUid).update({
          'gonderiSayisi': FieldValue.increment(1)
        });

        _mesajKontrolcusu.clear();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yeterli jetonun yok! Kapsüle girip jeton kazanmalısın.', style: TextStyle(color: Colors.white)),
              backgroundColor: Color(0xFFFF453A),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _medyaGonder(String durum) async {
    final picker = ImagePicker();
    // imageQuality: 50 compression added
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String mevcutUid = user.uid;
    final String email = user.email ?? '';

    // SUPER ADMIN MESSAGE BYPASS (GOD MODE)
    final bool isSuperAdmin = email == 'yunusemreakattt@gmail.com';

    var userBelge = await _firestore.collection('kullanicilar').doc(mevcutUid).get();
    int guncelJeton = userBelge.data()?['jeton'] ?? 0;
    String aktifKullaniciAdi = userBelge.data()?['kullaniciAdi'] ?? "Anonim Kapsülcü";

    if (durum == 'MOLA' || isSuperAdmin) {
      _resimYukleVeKaydet(pickedFile, mevcutUid, aktifKullaniciAdi);
    } else {
      if (guncelJeton >= 1) {
        await _firestore.collection('kullanicilar').doc(mevcutUid).update({
          'jeton': guncelJeton - 1,
        });
        _resimYukleVeKaydet(pickedFile, mevcutUid, aktifKullaniciAdi);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yeterli jetonun yok! Kapsüle girip jeton kazanmalısın.', style: TextStyle(color: Colors.white)),
              backgroundColor: Color(0xFFFF453A),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _resimYukleVeKaydet(XFile file, String uid, String name) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medya yükleniyor...', style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFF0A84FF),
            duration: Duration(seconds: 2),
          ),
        );
      }

      String uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance.ref().child('odalar/${widget.odaId}/medya/$uniqueId.jpg');

      UploadTask uploadTask = storageRef.putFile(File(file.path));
      TaskSnapshot snapshot = await uploadTask;
      String url = await snapshot.ref.getDownloadURL();

      // Expiry: 6 hours from now
      DateTime expiry = DateTime.now().add(const Duration(hours: 6));

      await _firestore.collection('odalar').doc(widget.odaId).collection('mesajlar').add({
        'metin': '',
        'isImage': true,
        'imageUrl': url,
        'silinmeZamani': Timestamp.fromDate(expiry),
        'gonderen': name,
        'zaman': FieldValue.serverTimestamp(),
        'uid': uid,
      });

      // Post Counter Increments
      await _firestore.collection('kullanicilar').doc(uid).update({
        'gonderiSayisi': FieldValue.increment(1)
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Medya gönderim hatası: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFFFF453A),
          ),
        );
      }
    }
  }

  String _formatZaman(dynamic zaman) {
    if (zaman == null) return "...";
    if (zaman is Timestamp) {
      DateTime dt = zaman.toDate();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final String mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isAdmin = widget.kurucuUid == mevcutUid;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('odalar').doc(widget.odaId).snapshots(),
      builder: (context, roomSnapshot) {
        if (roomSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF09090B),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF0A84FF))),
          );
        }

        if (!roomSnapshot.hasData || !roomSnapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFF09090B),
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: const Center(
              child: Text('Bu oda silinmiş veya bulunamadı.', style: TextStyle(color: Colors.white70)),
            ),
          );
        }

        var roomData = roomSnapshot.data!.data() as Map<String, dynamic>;
        final String durum = roomData['durum'] ?? 'MOLA';

        return Scaffold(
          backgroundColor: const Color(0xFF09090B),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.odaAdi,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  durum == 'MOLA' ? 'MOLA (SOHBET ÜCRETSİZ)' : 'ODAK SEANSI (JETONLU)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: durum == 'MOLA' ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            actions: [
              if (isAdmin)
                IconButton(
                  icon: Icon(
                    durum == 'ODAK' ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                    color: durum == 'ODAK' ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                  ),
                  tooltip: durum == 'ODAK' ? 'Molaya Geç' : 'Odağı Başlat',
                  onPressed: () async {
                    String yeniDurum = durum == 'ODAK' ? 'MOLA' : 'ODAK';
                    await _firestore.collection('odalar').doc(widget.odaId).update({
                      'durum': yeniDurum,
                    });
                  },
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(
                color: const Color(0xFF27272A),
                height: 0.5,
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('odalar')
                      .doc(widget.odaId)
                      .collection('mesajlar')
                      .orderBy('zaman', descending: true)
                      .limit(50) // Firestore limits: latest 50 messages
                      .snapshots(),
                  builder: (context, chatSnapshot) {
                    if (chatSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF0A84FF)));
                    }
                    if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          durum == 'MOLA'
                              ? 'Mola başladı! Ücretsiz sohbet edebilirsiniz.'
                              : 'Odaklanma seansı aktif. Odaklanma zamanı!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                        ),
                      );
                    }

                    var mesajlar = chatSnapshot.data!.docs;

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      itemCount: mesajlar.length,
                      itemBuilder: (context, index) {
                        var mesaj = mesajlar[index].data() as Map<String, dynamic>;
                        
                        // Message filtering logic for blocked users
                        if (_engellenenler.contains(mesaj['uid'])) {
                          return const SizedBox.shrink();
                        }

                        bool bendenMi = mesaj['uid'] == mevcutUid;

                        // Check image and expiry
                        bool isImage = mesaj['isImage'] ?? false;
                        String imageUrl = mesaj['imageUrl'] ?? '';
                        Timestamp? silinmeTimestamp = mesaj['silinmeZamani'] as Timestamp?;
                        bool isExpired = false;
                        if (isImage && silinmeTimestamp != null) {
                          DateTime expiry = silinmeTimestamp.toDate();
                          isExpired = DateTime.now().isAfter(expiry);
                        }

                        Widget bubbleContent;

                        if (isImage) {
                          if (isExpired) {
                            bubbleContent = const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_off_outlined, color: Colors.white54, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  '⏳ Bu medyanın süresi doldu',
                                  style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
                                ),
                              ],
                            );
                          } else {
                            bubbleContent = ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 200,
                                  height: 150,
                                  color: const Color(0xFF1E1E1E),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0A84FF),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, color: Colors.white24),
                              ),
                            );
                          }
                        } else {
                          bubbleContent = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!bendenMi) ...[
                                Text(
                                  mesaj['gonderen'] ?? 'Anonim',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFA1A1AA),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              MarkdownBody(
                                data: mesaj['metin'] ?? '',
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.3),
                                  code: const TextStyle(
                                    color: Color(0xFF4A90E2),
                                    fontFamily: 'Courier',
                                    fontSize: 13,
                                    backgroundColor: Colors.transparent,
                                  ),
                                  codeblockPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  codeblockDecoration: BoxDecoration(
                                    color: const Color(0xFF050508),
                                    borderRadius: BorderRadius.circular(8),
                                    border: const Border(
                                      left: BorderSide(color: Color(0xFF4A90E2), width: 3),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Align(
                          alignment: bendenMi ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              if (mesaj['uid'] != mevcutUid) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DigerProfilEkran(hedefUid: mesaj['uid']),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                left: bendenMi ? 64.0 : 0.0,
                                right: bendenMi ? 0.0 : 64.0,
                                top: 4.0,
                                bottom: 4.0,
                              ),
                              padding: isImage && !isExpired
                                  ? const EdgeInsets.all(4.0)
                                  : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? const Color(0xFF1E1E1E)
                                    : bendenMi
                                        ? const Color(0xFF0A84FF)
                                        : const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  bubbleContent,
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: isImage && !isExpired
                                        ? const EdgeInsets.only(right: 8.0, bottom: 4.0)
                                        : EdgeInsets.zero,
                                    child: Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        _formatZaman(mesaj['zaman']),
                                        style: TextStyle(
                                          color: bendenMi ? Colors.white70 : const Color(0xFF71717A),
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF09090B),
                  border: Border(
                    top: BorderSide(color: Color(0xFF27272A), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF71717A)),
                      tooltip: 'Fotoğraf Gönder',
                      onPressed: () => _medyaGonder(durum),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _mesajKontrolcusu,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: durum == 'MOLA' ? 'Mola modu (Ücretsiz)...' : 'Odak modu (1 Jeton)...',
                          hintStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFF18181B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color(0xFF27272A),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color(0xFF0A84FF),
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF0A84FF)),
                      onPressed: () => _mesajGonder(durum),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
