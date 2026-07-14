import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:odak_kapsulu/screens/diger_profil_ekrani.dart';
import 'package:odak_kapsulu/screens/dm_sohbet_ekrani.dart';

class BildirimEkran extends StatefulWidget {
  final bool nested;
  const BildirimEkran({super.key, this.nested = false});

  @override
  State<BildirimEkran> createState() => _BildirimEkranState();
}

class _BildirimEkranState extends State<BildirimEkran> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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

  /// Returns the leading icon widget for a notification type
  Widget _notifIcon(String tip, String foto) {
    if (tip == 'sistem_dedikodu') {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFFF453A).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🧯', style: TextStyle(fontSize: 20)),
        ),
      );
    }

    if (tip == 'stalker_gizli') {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4A90E2).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('👁️', style: TextStyle(fontSize: 20)),
        ),
      );
    }

    if (tip == 'stalker_acik') {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4A90E2).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('✨', style: TextStyle(fontSize: 20)),
        ),
      );
    }

    // Default: user avatar
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFF0A0A0E),
      backgroundImage: foto.isNotEmpty ? CachedNetworkImageProvider(foto) : null,
      child: foto.isEmpty ? const Icon(Icons.person, color: Color(0xFFA1A1AA)) : null,
    );
  }

  /// Returns RichText widget for the notification body
  Widget _notifBody(String tip, String isim, String mesaj) {
    if (tip == 'sistem_dedikodu') {
      // Dramatic look: broken fire icon label + orange-tinted username
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('👀 ', style: TextStyle(fontSize: 12)),
              const Text(
                'Dedikodu Motoru',
                style: TextStyle(
                  color: Color(0xFFFF8C00),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13.5, height: 1.3),
              children: [
                // Extract and highlight the name within the message
                TextSpan(text: mesaj),
              ],
            ),
          ),
        ],
      );
    }

    if (tip == 'stalker_gizli' || tip == 'stalker_acik' || tip == 'sistem' || tip == 'unfollow') {
      return RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3),
          children: [
            TextSpan(
              text: '🔔 Sistem',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: '  '),
            TextSpan(text: mesaj),
          ],
        ),
      );
    }

    // Standard: user did something
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3),
        children: [
          TextSpan(
            text: isim,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: ' '),
          TextSpan(text: mesaj),
        ],
      ),
    );
  }

  /// Returns the left accent border color for a notification type
  Color _accentColor(String tip) {
    switch (tip) {
      case 'sistem_dedikodu':
        return const Color(0xFFFF453A);
      case 'begen':
        return Colors.orangeAccent;
      case 'takip':
        return const Color(0xFF30D158);
      case 'yorum':
        return const Color(0xFF4A90E2);
      case 'repost':
        return const Color(0xFF30D158);
      case 'stalker_gizli':
      case 'stalker_acik':
        return const Color(0xFF4A90E2);
      default:
        return const Color(0xFF4A90E2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget bodyContent = _mevcutUid.isEmpty
        ? const Center(child: Text('Giriş yapmalısınız.', style: TextStyle(color: Colors.white60)))
        : StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('kullanicilar')
                .doc(_mevcutUid)
                .collection('bildirimler')
                .orderBy('tarih', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
              }

              var docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Henüz bir hareket bulunmuyor.',
                    style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var doc = docs[index];
                  var notification = doc.data() as Map<String, dynamic>;
                  String tip = notification['tip'] ?? '';
                  String gonderenId = notification['gonderenId'] ?? '';
                  String mesaj = notification['mesaj'] ?? '';
                  bool okunduMu = notification['okunduMu'] ?? false;
                  String zaman = _formatZaman(notification['tarih']);

                  final Color accentColor = _accentColor(tip);

                  // For system / gossip notifications, no need for user stream
                  if (tip == 'sistem_dedikodu' || tip == 'stalker_gizli') {
                    return _buildNotifTile(
                      tip: tip,
                      gonderenId: gonderenId,
                      isim: 'Dedikodu',
                      foto: '',
                      mesaj: mesaj,
                      zaman: zaman,
                      okunduMu: okunduMu,
                      accentColor: accentColor,
                      doc: doc,
                      notification: notification,
                    );
                  }

                  return StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('kullanicilar').doc(gonderenId).snapshots(),
                    builder: (context, userSnap) {
                      String isim = 'Kapsülcü';
                      String foto = '';
                      if (userSnap.hasData && userSnap.data!.exists) {
                        var uData = userSnap.data!.data() as Map<String, dynamic>;
                        isim = uData['kullaniciAdi'] ?? 'Kapsülcü';
                        foto = uData['profilFotoUrl'] ?? '';
                      }

                      return _buildNotifTile(
                        tip: tip,
                        gonderenId: gonderenId,
                        isim: isim,
                        foto: foto,
                        mesaj: mesaj,
                        zaman: zaman,
                        okunduMu: okunduMu,
                        accentColor: accentColor,
                        doc: doc,
                        notification: notification,
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
        title: const Text('HAREKET MERKEZİ', style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildNotifTile({
    required String tip,
    required String gonderenId,
    required String isim,
    required String foto,
    required String mesaj,
    required String zaman,
    required bool okunduMu,
    required Color accentColor,
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> notification,
  }) {
    final bool isDedikodu = tip == 'sistem_dedikodu';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDedikodu
            ? const Color(0xFF1A0D0D)  // Subtly red-tinted background for drama
            : const Color(0xFF141419),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDedikodu
              ? const Color(0xFFFF453A).withValues(alpha: 0.35)
              : const Color(0xFF2A2A35),
          width: isDedikodu ? 0.8 : 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: okunduMu
                ? null
                : Border(
                    left: BorderSide(
                      color: accentColor,
                      width: 3.5,
                    ),
                  ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: _notifIcon(tip, foto),
            title: _notifBody(tip, isim, mesaj),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                zaman,
                style: const TextStyle(color: Color(0xFF71717A), fontSize: 11),
              ),
            ),
            onTap: () {
              if (!okunduMu) {
                doc.reference.update({'okunduMu': true});
              }
              if (gonderenId.isNotEmpty && gonderenId != 'sistem') {
                if (tip == 'stalker_acik') {
                  String dmId = _mevcutUid.compareTo(gonderenId) < 0
                      ? '${_mevcutUid}_$gonderenId'
                      : '${gonderenId}_$_mevcutUid';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DmSohbetEkran(
                        dmId: dmId,
                        hedefUid: gonderenId,
                        hedefKullaniciAdi: isim,
                      ),
                    ),
                  );
                } else if (tip == 'sistem_dedikodu') {
                  // Navigate to the profile of the person who broke their streak
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DigerProfilEkran(hedefUid: gonderenId),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DigerProfilEkran(hedefUid: gonderenId),
                    ),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
