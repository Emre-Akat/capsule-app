import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odak_kapsulu/screens/oda_ici_ekrani.dart';

class LobiEkran extends StatefulWidget {
  final bool nested;
  const LobiEkran({super.key, this.nested = false});

  @override
  State<LobiEkran> createState() => _LobiEkranState();
}

class _LobiEkranState extends State<LobiEkran> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _seciliKategori = 'Tümü';
  final List<String> _kategoriler = ['Tümü', 'YKS', 'Tıp', 'Yazılım', 'Girişimcilik', 'Yabancı Dil'];

  void _odaKurKontrol() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String mevcutUid = user.uid;
    final String email = user.email ?? '';

    // SUPER ADMIN OVERRIDE (GOD MODE)
    final bool isSuperAdmin = email == 'yunusemreakattt@gmail.com';

    if (!isSuperAdmin) {
      var userBelge = await _firestore.collection('kullanicilar').doc(mevcutUid).get();
      int xp = userBelge.data()?['xp'] ?? 0;
      if (xp < 1000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Oda kurmak için Seviye 3 (1000 XP) olmalısın!'),
              backgroundColor: Color(0xFFFF453A),
            ),
          );
        }
        return;
      }
    }
    _odaKurDialogGoster();
  }

  void _odaKurDialogGoster() {
    final TextEditingController adiController = TextEditingController();
    String seciliDialogKat = 'YKS';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141419),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF2A2A35), width: 1.0),
              ),
              title: const Text('Yeni Oda Kur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: adiController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Oda Adı',
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
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF141419),
                    initialValue: seciliDialogKat,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      labelStyle: const TextStyle(color: Color(0xFF71717A)),
                      filled: true,
                      fillColor: const Color(0xFF0A0A0E),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2A2A35)),
                      ),
                    ),
                    items: _kategoriler.where((k) => k != 'Tümü').map((k) {
                      return DropdownMenuItem(
                        value: k,
                        child: Text(k),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          seciliDialogKat = val;
                        });
                      }
                    },
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
                    String odaAdi = adiController.text.trim();
                    if (odaAdi.isNotEmpty) {
                      final navigator = Navigator.of(context);
                      final String mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                      
                      await _firestore.collection('odalar').add({
                        'adi': odaAdi,
                        'kategori': seciliDialogKat,
                        'kurucuUid': mevcutUid,
                        'durum': 'MOLA',
                        'zaman': FieldValue.serverTimestamp(),
                      });
                      
                      navigator.pop();
                    }
                  },
                  child: const Text('KUR', style: TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget bodyContent = Column(
      children: [
        // Horizontal Category Filter Slider
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _kategoriler.length,
            itemBuilder: (context, index) {
              final String kat = _kategoriler[index];
              final bool isSelected = _seciliKategori == kat;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _seciliKategori = kat;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF141419),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF2A2A35),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    kat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Rooms List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('odalar').orderBy('zaman', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Henüz hiç oda açılmamış. İlkini sen kur!',
                    style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                  ),
                );
              }

              var documents = snapshot.data!.docs;
              if (_seciliKategori != 'Tümü') {
                documents = documents.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['kategori'] == _seciliKategori;
                }).toList();
              }

              if (documents.isEmpty) {
                return const Center(
                  child: Text(
                    'Bu kategoride oda bulunamadı.',
                    style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                  ),
                );
              }

              return ListView.builder(
                itemCount: documents.length,
                padding: const EdgeInsets.only(bottom: 24),
                itemBuilder: (context, index) {
                  var doc = documents[index];
                  var data = doc.data() as Map<String, dynamic>;
                  final String durum = data['durum'] ?? 'MOLA';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OdaIciEkran(
                            odaId: doc.id,
                            odaAdi: data['adi'] ?? 'İsimsiz Oda',
                            kurucuUid: data['kurucuUid'] ?? '',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141419),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['adi'] ?? 'İsimsiz Oda',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['kategori'] ?? 'Genel',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: durum == 'MOLA'
                                  ? const Color(0xFF30D158).withValues(alpha: 0.1)
                                  : const Color(0xFFFF453A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: durum == 'MOLA' ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              durum,
                              style: TextStyle(
                                color: durum == 'MOLA' ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5,
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
      ],
    );

    if (widget.nested) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0E),
        body: bodyContent,
        floatingActionButton: FloatingActionButton(
          onPressed: _odaKurKontrol,
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: AppBar(
        title: const Text('ÇALIŞMA ODALARI', style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0E),
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF2A2A35),
            height: 0.5,
          ),
        ),
      ),
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
        onPressed: _odaKurKontrol,
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
