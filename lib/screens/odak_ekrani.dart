import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _kullaniciAboneligi;

  final int _toplamSaniye = 10;
  int _kalanSaniye = 10;
  bool _calisiyorMu = false;
  Timer? _zamanlayici;

  int _kazanilanXp = 0;
  int _chatJetonu = 0;
  int _gunlukOdakDakikasi = 0;
  int _seriSayisi = 0;
  Timestamp? _sonOdakTarihi;
  int _kalkanSayisi = 0;

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _verileriCanliDinle();
  }

  @override
  void dispose() {
    _kullaniciAboneligi?.cancel();
    _zamanlayici?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _verileriCanliDinle() {
    String mevcutUid = FirebaseAuth.instance.currentUser!.uid;

    _kullaniciAboneligi = _firestore
        .collection('kullanicilar')
        .doc(mevcutUid)
        .snapshots()
        .listen((belge) {
      if (belge.exists && mounted) {
        setState(() {
          _kazanilanXp = belge.data()?['xp'] ?? 0;
          _chatJetonu = belge.data()?['jeton'] ?? 0;
          _gunlukOdakDakikasi = belge.data()?['gunlukOdakDakikasi'] ?? 0;
          _seriSayisi = belge.data()?['seriSayisi'] ?? 0;
          _sonOdakTarihi = belge.data()?['sonOdakTarihi'] as Timestamp?;
          _kalkanSayisi = belge.data()?['kalkanSayisi'] ?? 0;
        });
      }
    });
  }

  String _zamanFormatla(int saniye) {
    int dakika = saniye ~/ 60;
    int kalan = saniye % 60;
    return '${dakika.toString().padLeft(2, '0')}:${kalan.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _sayaciBaslat() {
    setState(() {
      _calisiyorMu = true;
    });

    _zamanlayici = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_kalanSaniye > 0) {
        setState(() {
          _kalanSaniye--;
        });
      } else {
        _sayaciDurdur();
        setState(() {
          _kalanSaniye = _toplamSaniye;
        });

        // Anti-Cheat & Streak Logic
        DateTime now = DateTime.now();
        int currentDailyMinutes = _gunlukOdakDakikasi;

        if (_sonOdakTarihi != null) {
          DateTime lastDate = _sonOdakTarihi!.toDate();
          if (!_isSameDay(lastDate, now)) {
            // New day, reset minutes
            currentDailyMinutes = 0;
          }
        } else {
          currentDailyMinutes = 0;
        }

        if (currentDailyMinutes >= 600) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Günlük maksimum sınır (10 Saat). XP/Jeton kazanımı yarına kadar durduruldu.',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Color(0xFFFF453A),
              ),
            );
          }

          // Still save date and reset minutes in case of daily limit
          String mevcutUid = FirebaseAuth.instance.currentUser!.uid;
          await _firestore.collection('kullanicilar').doc(mevcutUid).set({
            'sonOdakTarihi': Timestamp.fromDate(now),
            'gunlukOdakDakikasi': currentDailyMinutes,
          }, SetOptions(merge: true));
        } else {
          int newXp = _kazanilanXp + 50;
          int newJeton = _chatJetonu + 1;
          int newDailyMinutes = currentDailyMinutes + 25; // Standard 25-minute Pomodoro session length

          int newStreak = 1;
          int consumedKalkan = 0;
          if (_sonOdakTarihi != null) {
            DateTime lastDate = _sonOdakTarihi!.toDate();
            DateTime lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
            DateTime nowDateOnly = DateTime(now.year, now.month, now.day);
            int dayDifference = nowDateOnly.difference(lastDateOnly).inDays;

            if (dayDifference == 1) {
              newStreak = _seriSayisi + 1;
            } else if (dayDifference == 0) {
              newStreak = _seriSayisi == 0 ? 1 : _seriSayisi;
            } else {
              // > 1 day gap
              if (_kalkanSayisi > 0) {
                newStreak = _seriSayisi == 0 ? 1 : _seriSayisi;
                consumedKalkan = 1;
              } else {
                newStreak = 1;
              }
            }
          }

          String mevcutUid = FirebaseAuth.instance.currentUser!.uid;
          Map<String, dynamic> updateData = {
            'xp': newXp,
            'jeton': newJeton,
            'gunlukOdakDakikasi': newDailyMinutes,
            'seriSayisi': newStreak,
            'sonOdakTarihi': Timestamp.fromDate(now),
            'sonGirisTarihi': Timestamp.fromDate(now),
          };

          if (consumedKalkan > 0) {
            updateData['kalkanSayisi'] = FieldValue.increment(-1);
          }

          await _firestore.collection('kullanicilar').doc(mevcutUid).set(updateData, SetOptions(merge: true));

          if (consumedKalkan > 0 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Seri Koruma Kalkanı kullanıldı! Serin korundu. 🛡️', style: TextStyle(color: Colors.white)),
                backgroundColor: Color(0xFF4A90E2),
              ),
            );
          }

          _confettiController.play();
          _tebrikPenceresiGoster();
        }
      }
    });
  }

  void _sayaciDurdur() {
    _zamanlayici?.cancel();
    setState(() {
      _calisiyorMu = false;
    });
  }

  double _cemberIlerlemesi() {
    return _kalanSaniye / _toplamSaniye;
  }

  void _tebrikPenceresiGoster() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2C2C2E), width: 1.0),
          ),
          title: Row(
            children: const [
              Text('🎉 ', style: TextStyle(fontSize: 22)),
              Text(
                'Tebrikler!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Odak seansını başarıyla tamamladın.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 12),
              Text(
                '• +50 XP kazandın!\n• +1 Sohbet Jetonu kazandın!',
                style: TextStyle(color: Color(0xFF30D158), fontSize: 13, height: 1.4, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'HARİKA',
                style: TextStyle(color: Color(0xFF0A84FF), fontWeight: FontWeight.bold),
              ),
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
        title: const Text(
          'ODAK KAPSÜLÜ',
          style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Circle Timer representation
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: _cemberIlerlemesi(),
                          strokeWidth: 8,
                          backgroundColor: const Color(0xFF1C1C1E),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _zamanFormatla(_kalanSaniye),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _calisiyorMu ? 'ODAKLANILIYOR' : 'HAZIR',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Color(0xFF71717A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  // Controls
                  GestureDetector(
                    onTap: _calisiyorMu ? _sayaciDurdur : _sayaciBaslat,
                    child: Container(
                      width: 140,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _calisiyorMu ? const Color(0xFFFF453A) : const Color(0xFF0A84FF),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(
                          _calisiyorMu ? 'DURDUR' : 'BAŞLAT',
                          style: const TextStyle(
                            color: Colors.white,
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
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
