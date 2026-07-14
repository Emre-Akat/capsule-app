import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:odak_kapsulu/screens/arama_ekrani.dart';
import 'package:odak_kapsulu/screens/diger_profil_ekrani.dart';

class AkisEkran extends StatefulWidget {
  const AkisEkran({super.key});

  @override
  State<AkisEkran> createState() => _AkisEkranState();
}

class _AkisEkranState extends State<AkisEkran> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _mevcutIsim = 'Kapsülcü';
  String _mevcutFotoUrl = '';

  final TextEditingController _postInputController = TextEditingController();
  Timer? _botSimilatorTimer;

  @override
  void initState() {
    super.initState();
    _mevcutKullaniciBilgileriniCek();
    _botKullanicilariOlustur();
    _botSimilatorunuBaslat();
  }

  @override
  void dispose() {
    _botSimilatorTimer?.cancel();
    _postInputController.dispose();
    super.dispose();
  }

  void _mevcutKullaniciBilgileriniCek() async {
    if (_mevcutUid.isEmpty) return;
    var snap = await _firestore.collection('kullanicilar').doc(_mevcutUid).get();
    if (snap.exists && mounted) {
      setState(() {
        _mevcutIsim = snap.data()?['kullaniciAdi'] ?? 'Kapsülcü';
        _mevcutFotoUrl = snap.data()?['profilFotoUrl'] ?? '';
      });
    }
  }

  void _botKullanicilariOlustur() async {
    final bots = {
      'bot_kozmik': {
        'kullaniciAdi': 'Kozmik Kapsülcü',
        'biyografi': 'Derin uzayda odak seansları düzenliyorum. 🚀',
        'profilFotoUrl': 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=150',
        'xp': 1200,
        'sparkPuani': 240,
        'takipciler': [_mevcutUid],
        'takipEdilenler': [_mevcutUid],
        'gonderiSayisi': 14,
      },
      'bot_odak_ustasi': {
        'kullaniciAdi': 'Odak Ustası',
        'biyografi': 'Günde 8 saat kesintisiz odaklanma uzmanıyım. ⚡',
        'profilFotoUrl': 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=150',
        'xp': 2300,
        'sparkPuani': 420,
        'takipciler': [_mevcutUid],
        'takipEdilenler': [_mevcutUid],
        'gonderiSayisi': 38,
      },
      'bot_derin_kodcu': {
        'kullaniciAdi': 'Derin Kodcu',
        'biyografi': 'Böcekleri temizler, kahveyi koda dönüştürürüm. 💻',
        'profilFotoUrl': 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?auto=format&fit=crop&w=150',
        'xp': 1850,
        'sparkPuani': 310,
        'takipciler': [_mevcutUid],
        'takipEdilenler': [_mevcutUid],
        'gonderiSayisi': 22,
      },
      'bot_sanal_mimar': {
        'kullaniciAdi': 'Sanal Tasarımcı',
        'biyografi': 'Minimalist arayüzler ve piksel sanatı. 🎨',
        'profilFotoUrl': 'https://images.unsplash.com/photo-1507238691740-187a5b1d37b8?auto=format&fit=crop&w=150',
        'xp': 950,
        'sparkPuani': 180,
        'takipciler': [_mevcutUid],
        'takipEdilenler': [_mevcutUid],
        'gonderiSayisi': 9,
      },
      'bot_hizli_ogrenci': {
        'kullaniciAdi': 'Sürekli Öğrenen',
        'biyografi': 'Her gün 1 yeni makale okumadan uyumam. 📚',
        'profilFotoUrl': 'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?auto=format&fit=crop&w=150',
        'xp': 1400,
        'sparkPuani': 275,
        'takipciler': [_mevcutUid],
        'takipEdilenler': [_mevcutUid],
        'gonderiSayisi': 17,
      },
      'bot_zen_master': {
        'kullaniciAdi': 'Zen Kapsülü',
        'biyografi': 'Nefes al, odaklan, kodunu yaz. 🧘‍♂️',
        'profilFotoUrl': 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?auto=format&fit=crop&w=150',
        'xp': 2800,
        'sparkPuani': 510,
        'takipciler': [_mevcutUid],
        'takipEdilenler': [_mevcutUid],
        'gonderiSayisi': 45,
      }
    };

    // Ensure bots exist
    for (var entry in bots.entries) {
      await _firestore.collection('kullanicilar').doc(entry.key).set(entry.value, SetOptions(merge: true));
    }

    // Auto follow back
    if (_mevcutUid.isNotEmpty) {
      await _firestore.collection('kullanicilar').doc(_mevcutUid).set({
        'takipciler': FieldValue.arrayUnion([
          'bot_kozmik',
          'bot_odak_ustasi',
          'bot_derin_kodcu',
          'bot_sanal_mimar',
          'bot_hizli_ogrenci',
          'bot_zen_master'
        ]),
        'takipEdilenler': FieldValue.arrayUnion([
          'bot_kozmik',
          'bot_odak_ustasi',
          'bot_derin_kodcu',
          'bot_sanal_mimar',
          'bot_hizli_ogrenci',
          'bot_zen_master'
        ]),
      }, SetOptions(merge: true));
    }
  }

  void _botSimilatorunuBaslat() {
    // Run once immediately after 1 second
    Timer(const Duration(seconds: 1), () => _botEylemiGerceklestir());

    // Triggers periodically every 12 seconds for high activity
    _botSimilatorTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      _botEylemiGerceklestir();
    });
  }

  void _botEylemiGerceklestir() async {
    final random = DateTime.now().millisecondsSinceEpoch;
    
    // Pick a random bot
    final botUids = [
      'bot_kozmik',
      'bot_odak_ustasi',
      'bot_derin_kodcu',
      'bot_sanal_mimar',
      'bot_hizli_ogrenci',
      'bot_zen_master'
    ];
    final botUid = botUids[random % botUids.length];
    
    var botSnap = await _firestore.collection('kullanicilar').doc(botUid).get();
    if (!botSnap.exists) return;
    var botData = botSnap.data()!;
    String botName = botData['kullaniciAdi'] ?? 'Kapsülcü';
    String botFoto = botData['profilFotoUrl'] ?? '';

    // Check existing posts count
    var postsSnap = await _firestore.collection('gonderiler').limit(10).get();
    
    // 0: Post, 1: Like, 2: Comment, 3: Repost
    final int actionType = postsSnap.docs.isEmpty ? 0 : (random % 4);

    if (actionType == 0) {
      // Share a new post based on role
      String text = "";
      if (botUid == 'bot_kozmik') {
        final options = [
          "Derin uzayda odak seansı başladı, katılmak isteyenler lobiye! 🚀",
          "Kozmik odadaki pomodoro seansı bitti! ☕ Şimdi 5 dakika mola.",
          "Telefondan bildirimleri kapatınca odak seviyem 3 katına çıktı, tavsiye ederim."
        ];
        text = options[random % options.length];
      } else if (botUid == 'bot_odak_ustasi') {
        final options = [
          "Bugün 400 dakikayı geçtik, odaklanma limitlerimi zorluyorum. ⚡",
          "Seri sayımı 14 güne çıkardım! Focus timer'ı kurdum ve telefondan uzaklaştım.",
          "Bugün hedeflerinize ulaştınız mı? Ben neredeyse bitirdim."
        ];
        text = options[random % options.length];
      } else if (botUid == 'bot_derin_kodcu') {
        final options = [
          "Flutter ile state management refactoring yapıyorum, beynim yandı.",
          "Temiz kod yazmak zaman alır ama daha az baş ağrıtır. Bugün refactoring günü.",
          "StackOverflow çöktüğünde ne yapacağımı şaşırdım, neyse ki odaklanmaya devam ettim."
        ];
        text = options[random % options.length];
      } else if (botUid == 'bot_sanal_mimar') {
        final options = [
          "Yeni minimalist dark mode arayüz tasarımı bitti. Figma linkini profile ekledim. 🎨",
          "Arayüzde #0A0A0E rengini kullanmak göz yorgunluğunu aşırı azaltıyor. 💻",
          "Bugün sadece UX mimarisine odaklanıyorum. Sessizlik harika."
        ];
        text = options[random % options.length];
      } else if (botUid == 'bot_hizli_ogrenci') {
        final options = [
          "Bugün derinden öğrenme ve nöral ağlar üzerine harika bir makale okudum. 📚",
          "Yeni bir dil öğrenirken en önemli şey tutarlılık. Her gün 30 dakika odak!",
          "Teknik döküman okumak da odak seansı sayılır mı? Ben saydım."
        ];
        text = options[random % options.length];
      } else { // bot_zen_master
        final options = [
          "Zihninizi dinlendirmek için saat başı derin nefes egzersizi yapmayı unutmayın. 🧘‍♂️",
          "Nefes al, odaklan, kodunu yaz. Huzurlu bir çalışma dilerim.",
          "Kapsül içinde çalışmak sessizlik ve iç huzur getiriyor. Zihnim berrak."
        ];
        text = options[random % options.length];
      }
      
      await _firestore.collection('gonderiler').add({
        'gonderenUid': botUid,
        'gonderenIsim': botName,
        'gonderenProfilFoto': botFoto,
        'metin': text,
        'zaman': FieldValue.serverTimestamp(),
        'begenenler': [],
        'yorumSayisi': 0,
        'yenidenPaylasanlar': [],
      });
    } else {
      var randomPostDoc = postsSnap.docs[random % postsSnap.docs.length];
      String postId = randomPostDoc.id;
      String postGonderenUid = randomPostDoc.data()['gonderenUid'] ?? '';

      if (actionType == 1) {
        // Like a post
        List<dynamic> begenenler = randomPostDoc.data()['begenenler'] ?? [];
        if (!begenenler.contains(botUid)) {
          await _firestore.collection('gonderiler').doc(postId).update({
            'begenenler': FieldValue.arrayUnion([botUid])
          });
          // Write notification to owner if not self
          if (postGonderenUid.isNotEmpty && postGonderenUid != botUid) {
            await _firestore.collection('kullanicilar').doc(postGonderenUid).collection('bildirimler').add({
              'tip': 'begen',
              'gonderenId': botUid,
              'mesaj': 'gönderini beğendi 🔥',
              'tarih': FieldValue.serverTimestamp(),
              'okunduMu': false,
            });
          }
        }
      } else if (actionType == 2) {
        // Comment on a post
        String postAuthorName = randomPostDoc.data()['gonderenIsim'] ?? 'Kapsülcü';

        final comments = [
          "Harika iş @$postAuthorName! Aynen devam. 🔥",
          "Ben de katılıyorum @$postAuthorName, çok doğru bir bakış.",
          "Kolay gelsin @$postAuthorName, iyi odaklanmalar! ⚡",
          "Müthiş odak süresi @$postAuthorName, tebrik ederim!",
          "Bu konuda seninle aynı fikirdeyim @$postAuthorName.",
          "Ben de şimdi seansa başlıyorum @$postAuthorName, ilham verdin.",
          "Bir sonraki odak seansını beraber yapalım mı @$postAuthorName?",
          "Çok iyi gidiyorsun @$postAuthorName, darısı başıma.",
          "Günün en iyi paylaşımı bence @$postAuthorName, ellerine sağlık."
        ];
        String commentText = comments[random % comments.length];

        final postRef = _firestore.collection('gonderiler').doc(postId);
        final commentRef = postRef.collection('yorumlar').doc();
        final userRef = _firestore.collection('kullanicilar').doc(botUid);

        await _firestore.runTransaction((transaction) async {
          transaction.set(commentRef, {
            'yorumcuId': botUid,
            'yorumcuIsim': botName,
            'yorumcuProfilFoto': botFoto,
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

        // Write notification to owner if not self
        if (postGonderenUid.isNotEmpty && postGonderenUid != botUid) {
          await _firestore.collection('kullanicilar').doc(postGonderenUid).collection('bildirimler').add({
            'tip': 'yorum',
            'gonderenId': botUid,
            'mesaj': 'gönderine yorum yaptı: "$commentText"',
            'tarih': FieldValue.serverTimestamp(),
            'okunduMu': false,
          });
        }
      } else if (actionType == 3) {
        // Repost a post
        List<dynamic> yenidenPaylasanlar = randomPostDoc.data()['yenidenPaylasanlar'] ?? [];
        if (!yenidenPaylasanlar.contains(botUid)) {
          await _firestore.collection('gonderiler').doc(postId).update({
            'yenidenPaylasanlar': FieldValue.arrayUnion([botUid])
          });
          // Send notification if not self
          if (postGonderenUid.isNotEmpty && postGonderenUid != botUid) {
            await _firestore.collection('kullanicilar').doc(postGonderenUid).collection('bildirimler').add({
              'tip': 'repost',
              'gonderenId': botUid,
              'mesaj': 'gönderini yeniden paylaştı 🔁',
              'tarih': FieldValue.serverTimestamp(),
              'okunduMu': false,
            });
          }
        }
      }
    }
  }

  void _yeniPostPaylas() async {
    String text = _postInputController.text.trim();
    if (text.isEmpty || _mevcutUid.isEmpty) return;

    _postInputController.clear();

    await _firestore.collection('gonderiler').add({
      'gonderenUid': _mevcutUid,
      'gonderenIsim': _mevcutIsim,
      'gonderenProfilFoto': _mevcutFotoUrl,
      'metin': text,
      'zaman': FieldValue.serverTimestamp(),
      'begenenler': [],
      'yorumSayisi': 0,
      'yenidenPaylasanlar': [],
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gönderi paylaşıldı.', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF30D158),
        ),
      );
    }
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

  void _yorumYap(String postId, String commentText, String postGonderenUid) async {
    if (commentText.isEmpty || _mevcutUid.isEmpty) return;

    final postRef = _firestore.collection('gonderiler').doc(postId);
    final commentRef = postRef.collection('yorumlar').doc();
    final userRef = _firestore.collection('kullanicilar').doc(_mevcutUid);

    await _firestore.runTransaction((transaction) async {
      transaction.set(commentRef, {
        'yorumcuId': _mevcutUid,
        'yorumcuIsim': _mevcutIsim,
        'yorumcuProfilFoto': _mevcutFotoUrl,
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

    // Send notification if not commenting on own post
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: AppBar(
        title: const Text('AKIŞ', style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
      body: Column(
        children: [
          // Notion-Style Top Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF141419),
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A2A35), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF0A0A0E),
                  backgroundImage: _mevcutFotoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(_mevcutFotoUrl)
                      : null,
                  child: _mevcutFotoUrl.isEmpty
                      ? const Icon(Icons.person, size: 18, color: Color(0xFFA1A1AA))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _postInputController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Yeni bir şeyler paylaş...',
                      hintStyle: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _yeniPostPaylas(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF4A90E2), size: 20),
                  onPressed: _yeniPostPaylas,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('gonderiler').orderBy('zaman', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
                }

                var posts = snapshot.data?.docs ?? [];
                if (posts.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz bir gönderi paylaşılmamış.',
                      style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    var doc = posts[index];
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
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF141419),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF2A2A35), width: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DigerProfilEkran(hedefUid: postGonderenUid),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFF0A0A0E),
                                      backgroundImage: gProfilFoto.isNotEmpty
                                          ? CachedNetworkImageProvider(gProfilFoto)
                                          : null,
                                      child: gProfilFoto.isEmpty
                                          ? const Icon(Icons.person, size: 18, color: Color(0xFFA1A1AA))
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      gIsim,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                zamanText,
                                style: const TextStyle(color: Color(0xFF71717A), fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(left: 48.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MarkdownBody(
                                  data: metin,
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4),
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
                                const SizedBox(height: 16),
                                // Action Bar
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _likeToggled(postId, begenenler, postGonderenUid),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isLiked ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
                                            color: isLiked ? Colors.orangeAccent : const Color(0xFF71717A),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${begenenler.length}',
                                            style: TextStyle(color: isLiked ? Colors.orangeAccent : const Color(0xFF71717A), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    GestureDetector(
                                      onTap: () => _yorumBottomSheetGoster(postId, postGonderenUid),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            color: Color(0xFF71717A),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$yorumSayisi',
                                            style: const TextStyle(color: Color(0xFF71717A), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    GestureDetector(
                                      onTap: () => _repostToggled(postId, yenidenPaylasanlar, postGonderenUid),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.repeat_rounded,
                                            color: isReposted ? const Color(0xFF30D158) : const Color(0xFF71717A),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${yenidenPaylasanlar.length}',
                                            style: TextStyle(
                                              color: isReposted ? const Color(0xFF30D158) : const Color(0xFF71717A),
                                              fontSize: 12,
                                            ),
                                          ),
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
            ),
          ),
        ],
      ),
    );
  }
}
