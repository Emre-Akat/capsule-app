import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AyarlarEkran extends StatefulWidget {
  const AyarlarEkran({super.key});

  @override
  State<AyarlarEkran> createState() => _AyarlarEkranState();
}

class _AyarlarEkranState extends State<AyarlarEkran> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _sikayetDialogGoster() {
    final TextEditingController sikayetController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF27272A), width: 1),
          ),
          title: const Text('Şikayet Et / Hata Bildir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: sikayetController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Şikayetinizi veya bulduğunuz hatayı buraya yazın...',
              hintStyle: const TextStyle(color: Color(0xFF71717A)),
              filled: true,
              fillColor: const Color(0xFF09090B),
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF27272A), width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 1.0),
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
                String metin = sikayetController.text.trim();
                if (metin.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  String mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';

                  await _firestore.collection('sikayetler').add({
                    'raporEdenUid': mevcutUid,
                    'metin': metin,
                    'zaman': FieldValue.serverTimestamp(),
                  });

                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Bildiriminiz başarıyla iletildi. Teşekkür ederiz!', style: TextStyle(color: Colors.white)),
                      backgroundColor: Color(0xFF30D158),
                    ),
                  );
                }
              },
              child: const Text('GÖNDER', style: TextStyle(color: Color(0xFF0A84FF), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: const Text('AYARLAR & GÜVENLİK', style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF27272A),
            height: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Engellenen Kullanıcılar Section
              const Text(
                'GÜVENLİK',
                style: TextStyle(color: Color(0xFF71717A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF27272A), width: 1.0),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Engellenen Kullanıcılar', style: TextStyle(color: Colors.white, fontSize: 14.5)),
                      subtitle: const Text('Henüz engellenmiş kimse yok.', style: TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                      leading: const Icon(Icons.block, color: Color(0xFFFF453A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Feedback & Report
              const Text(
                'GERİ BİLDİRİM & DESTEK',
                style: TextStyle(color: Color(0xFF71717A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _sikayetDialogGoster,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27272A), width: 1.0),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bug_report_outlined, color: Color(0xFF0A84FF), size: 20),
                          SizedBox(width: 12),
                          Text('Şikayet Et / Hata Bildir', style: TextStyle(color: Colors.white, fontSize: 14.5)),
                        ],
                      ),
                      Icon(Icons.chevron_right_rounded, color: Color(0xFF71717A)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Logout Action
              GestureDetector(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await FirebaseAuth.instance.signOut();
                  navigator.pop();
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF453A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF453A), width: 1.0),
                  ),
                  child: const Center(
                    child: Text(
                      'HESAPTAN ÇIKIŞ YAP',
                      style: TextStyle(
                        color: Color(0xFFFF453A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
