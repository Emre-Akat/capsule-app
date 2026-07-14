import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class MagazaEkran extends StatefulWidget {
  const MagazaEkran({super.key});

  @override
  State<MagazaEkran> createState() => _MagazaEkranState();
}

class _MagazaEkranState extends State<MagazaEkran> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _mevcutUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _loadRewardedAd() {
    if (_isAdLoading) return;
    _isAdLoading = true;
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isAdLoading = false;
          });
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          setState(() {
            _rewardedAd = null;
            _isAdLoading = false;
          });
        },
      ),
    );
  }

  void _jetonGuncelle(int miktar) async {
    if (_mevcutUid.isEmpty) return;
    try {
      final userRef = _firestore.collection('kullanicilar').doc(_mevcutUid);
      await _firestore.runTransaction((transaction) async {
        transaction.update(userRef, {
          'jeton': FieldValue.increment(miktar),
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFFFF453A),
          ),
        );
      }
    }
  }

  void _reklamIzle() {
    if (_rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reklam yükleniyor, lütfen birazdan tekrar deneyin...', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFFFF9500),
          duration: Duration(seconds: 2),
        ),
      );
      _loadRewardedAd();
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _jetonGuncelle(10);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reklam izlendi! +10 Jeton eklendi. 💰', style: TextStyle(color: Colors.white)),
              backgroundColor: Color(0xFF30D158),
            ),
          );
        }
      },
    );
  }

  void _paketSatinAl(String paketAdi, int miktar, double fiyat) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
        );
      },
    );

    final navigator = Navigator.of(context);
    String productId = 'kapsul_${miktar}_jeton';

    try {
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) {
        throw Exception('Ürün bulunamadı.');
      }
      await Purchases.purchaseStoreProduct(products.first);
      
      if (!mounted) return;
      navigator.pop(); // Close loading dialog

      _jetonGuncelle(miktar);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satın alma başarılı! Jetonlar eklendi. 💸', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF30D158),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma başarısız oldu: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    }
  }

  void _urunSatinAl(String urunKey, String urunAdi, int jetonMaliyeti, int currentJeton, int sparkPuani) async {
    if (currentJeton < jetonMaliyeti) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yetersiz Jeton! Lütfen daha fazla jeton kazanın veya satın alın. 🪙', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFFFF453A),
        ),
      );
      return;
    }

    if (urunKey == 'altin_cerceve' && sparkPuani < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kilitli! Bu rozeti almak için en az 1000 Spark puanına sahip olmalısınız. ⚡', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFFFF453A),
        ),
      );
      return;
    }

    try {
      final userRef = _firestore.collection('kullanicilar').doc(_mevcutUid);
      await _firestore.runTransaction((transaction) async {
        if (urunKey == 'kalkan') {
          transaction.update(userRef, {
            'jeton': FieldValue.increment(-jetonMaliyeti),
            'kalkanSayisi': FieldValue.increment(1),
          });
        } else if (urunKey == 'altin_cerceve') {
          transaction.update(userRef, {
            'jeton': FieldValue.increment(-jetonMaliyeti),
            'rozetler': FieldValue.arrayUnion(['altin_cerceve']),
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$urunAdi başarıyla alındı! 🎉', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF30D158),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem başarısız oldu: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFFFF453A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('kullanicilar').doc(_mevcutUid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
          }

          int jeton = 0;
          int sparkPuani = 0;
          List<dynamic> rozetler = [];
          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            jeton = data['jeton'] ?? 0;
            sparkPuani = data['sparkPuani'] ?? 0;
            rozetler = data['rozetler'] ?? [];
          }

          bool hasAltinCerceve = rozetler.contains('altin_cerceve');

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom Silver AppBar
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF0A0A0E),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141419),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          '$jeton Jeton',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                flexibleSpace: const FlexibleSpaceBar(
                  title: Text(
                    'Kapsül Market',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  centerTitle: true,
                  titlePadding: EdgeInsets.only(bottom: 14),
                  background: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF141419), Color(0xFF0A0A0E)],
                      ),
                    ),
                  ),
                ),
              ),

              // Divider
              SliverToBoxAdapter(
                child: Container(
                  height: 0.5,
                  color: const Color(0xFF2A2A35),
                ),
              ),

              // Store Sections
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ─── SECTION A: JETON KAZAN (FREE) ───
                    _buildSectionHeader('💎 JETON KAZAN'),
                    const SizedBox(height: 12),
                    _buildAdRewardCard(),
                    const SizedBox(height: 32),

                    // ─── SECTION B: JETON SATIN AL (REAL MONEY) ───
                    _buildSectionHeader('🛒 JETON SATIN AL'),
                    const SizedBox(height: 12),
                    _buildIAPGrid(),
                    const SizedBox(height: 32),

                    // ─── SECTION C: JETON HARCA (PREMIUM ITEMS) ───
                    _buildSectionHeader('🛡️ PREMIUM EŞYALAR'),
                    const SizedBox(height: 12),
                    _buildPremiumItemCard(
                      title: 'Seri Koruma Kalkanı',
                      desc: 'Bir gün odaklanmayı kaçırırsan serin bozulmaz.',
                      icon: '🛡️',
                      price: 50,
                      onPurchase: () => _urunSatinAl('kalkan', 'Seri Koruma Kalkanı', 50, jeton, sparkPuani),
                    ),
                    const SizedBox(height: 12),
                    _buildPremiumItemCard(
                      title: 'Altın Profil Çerçevesi',
                      desc: 'Profilinizde parıldayan şık bir altın çerçeve ve özel rozet.',
                      icon: '✨',
                      price: 500,
                      isLocked: sparkPuani < 1000,
                      lockText: '1000 Spark Puanı Gereklidir (Mevcut: $sparkPuani)',
                      isOwned: hasAltinCerceve,
                      onPurchase: () => _urunSatinAl('altin_cerceve', 'Altın Profil Çerçevesi', 500, jeton, sparkPuani),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF71717A),
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildAdRewardCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.03),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.play_circle_fill_rounded, color: Color(0xFF4A90E2), size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Günlük Ödül',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Bir kısa reklam izleyerek ücretsiz jeton kazan.',
                  style: TextStyle(color: Color(0xFF71717A), fontSize: 11.5, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              elevation: 0,
            ),
            onPressed: _reklamIzle,
            child: const Text(
              '+10 🪙',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIAPGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.72,
      children: [
        _buildIAPCard(
          title: '100 Jeton',
          price: '19.99 ₺',
          amount: 100,
          borderColor: const Color(0xFF2A2A35),
        ),
        _buildIAPCard(
          title: '500 Jeton',
          price: '89.99 ₺',
          amount: 500,
          borderColor: const Color(0xFF4A90E2),
          badgeText: 'En Popüler',
        ),
        _buildIAPCard(
          title: '1000 Jeton',
          price: '149.99 ₺',
          amount: 1000,
          borderColor: const Color(0xFFFFD700),
          badgeText: 'Avantajlı',
        ),
      ],
    );
  }

  Widget _buildIAPCard({
    required String title,
    required String price,
    required int amount,
    required Color borderColor,
    String? badgeText,
  }) {
    final bool hasBadge = badgeText != null;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: hasBadge ? 1.5 : 1.0),
        boxShadow: hasBadge
            ? [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text(
                    '🪙',
                    style: TextStyle(fontSize: 28),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: hasBadge ? borderColor : const Color(0xFFA1A1AA), fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A0A0E),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: borderColor, width: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  onPressed: () => _paketSatinAl(title, amount, 0.0),
                  child: const Text(
                    'Satın Al',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Badge banner
          if (hasBadge)
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: borderColor == const Color(0xFFFFD700) ? Colors.black : Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumItemCard({
    required String title,
    required String desc,
    required String icon,
    required int price,
    bool isLocked = false,
    String? lockText,
    bool isOwned = false,
    required VoidCallback onPurchase,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A35), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0E),
              shape: BoxShape.circle,
              border: Border.all(color: isLocked ? Colors.transparent : const Color(0xFF2A2A35), width: 0.8),
            ),
            child: Center(
              child: Text(
                icon,
                style: TextStyle(fontSize: 22, color: isLocked ? Colors.white24 : Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isLocked ? Colors.white38 : Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLocked ? (lockText ?? 'Gereksinimler karşılanmadı.') : desc,
                  style: TextStyle(
                    color: isLocked ? const Color(0xFFFF453A).withValues(alpha: 0.7) : const Color(0xFF71717A),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isOwned
                  ? const Color(0xFF141419)
                  : isLocked
                      ? const Color(0xFF141419)
                      : const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              side: isOwned || isLocked ? const BorderSide(color: Color(0xFF2A2A35), width: 0.8) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 0,
            ),
            onPressed: isOwned || isLocked ? null : onPurchase,
            child: isOwned
                ? const Text(
                    'Sahipsiniz',
                    style: TextStyle(fontSize: 11, color: Color(0xFF71717A), fontWeight: FontWeight.bold),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$price',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isLocked ? Colors.white24 : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '🪙',
                        style: TextStyle(fontSize: 12, color: isLocked ? Colors.transparent : Colors.white),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
