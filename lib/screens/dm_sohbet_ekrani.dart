import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class DmSohbetEkran extends StatefulWidget {
  final String dmId;
  final String hedefUid;
  final String hedefKullaniciAdi;

  const DmSohbetEkran({
    super.key,
    required this.dmId,
    required this.hedefUid,
    required this.hedefKullaniciAdi,
  });

  @override
  State<DmSohbetEkran> createState() => _DmSohbetEkranState();
}

class _DmSohbetEkranState extends State<DmSohbetEkran> {
  final TextEditingController _mesajKontrolcusu = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _mesajGonder() async {
    if (_mesajKontrolcusu.text.isEmpty || _mevcutUid.isEmpty) return;

    final String text = _mesajKontrolcusu.text.trim();
    _mesajKontrolcusu.clear();

    final dmRef = _firestore.collection('dmler').doc(widget.dmId);

    // Save DM update and message atomically via transaction
    await _firestore.runTransaction((transaction) async {
      transaction.set(dmRef, {
        'katilimcilar': [_mevcutUid, widget.hedefUid],
        'sonMesaj': text,
        'sonGuncelleme': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final msgRef = dmRef.collection('mesajlar').doc();
      transaction.set(msgRef, {
        'metin': text,
        'gonderenUid': _mevcutUid,
        'zaman': FieldValue.serverTimestamp(),
      });
    });

    // If target is a bot, trigger delayed automatic response
    if (widget.hedefUid.startsWith('bot_')) {
      Future.delayed(const Duration(milliseconds: 1500), () async {
        final replies = [
          "Ooo harika! Ben de tam o sırada odaklanıyordum. ⚡",
          "Şu an odak seansındayım, bittiğinde detaylı konuşalım. ⏳",
          "Harika bir gün! Bugün hedeflerine ulaştın mı? 🔥",
          "Ben de Flutter kodluyordum, senin odak nasıl gidiyor?",
          "Hedeflerine odaklan, başarı gelecektir! Devam et.",
          "Jeton kazanmak için bugün kaç dakikalık seans yaptın?",
        ];
        final random = DateTime.now().millisecondsSinceEpoch;
        final String botReply = replies[random % replies.length];

        await _firestore.runTransaction((transaction) async {
          transaction.set(dmRef, {
            'katilimcilar': [_mevcutUid, widget.hedefUid],
            'sonMesaj': botReply,
            'sonGuncelleme': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          final msgRef = dmRef.collection('mesajlar').doc();
          transaction.set(msgRef, {
            'metin': botReply,
            'gonderenUid': widget.hedefUid,
            'zaman': FieldValue.serverTimestamp(),
          });
        });
      });
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: AppBar(
        title: Text(widget.hedefKullaniciAdi, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
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
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('dmler')
                  .doc(widget.dmId)
                  .collection('mesajlar')
                  .orderBy('zaman', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, chatSnapshot) {
                if (chatSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
                }

                if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sohbeti başlatın...',
                      style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
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
                    bool bendenMi = mesaj['gonderenUid'] == _mevcutUid;

                    return Align(
                      alignment: bendenMi ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(
                          left: bendenMi ? 64.0 : 0.0,
                          right: bendenMi ? 0.0 : 64.0,
                          top: 4.0,
                          bottom: 4.0,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: bendenMi ? const Color(0xFF4A90E2) : const Color(0xFF141419),
                          borderRadius: BorderRadius.circular(16),
                          border: bendenMi
                              ? null
                              : Border.all(color: const Color(0xFF2A2A35), width: 1.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                _formatZaman(mesaj['zaman']),
                                style: TextStyle(
                                  color: bendenMi ? Colors.white70 : const Color(0xFF71717A),
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
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
              color: Color(0xFF0A0A0E),
              border: Border(
                top: BorderSide(color: Color(0xFF2A2A35), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mesajKontrolcusu,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: 'Mesaj yazın...',
                      hintStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF141419),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Color(0xFF2A2A35),
                          width: 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Color(0xFF4A90E2),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF4A90E2)),
                  onPressed: _mesajGonder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
