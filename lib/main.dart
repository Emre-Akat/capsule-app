import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// Screens
import 'package:odak_kapsulu/screens/giris_ekrani.dart';
import 'package:odak_kapsulu/screens/ana_ekran.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // AdMob & RevenueCat Initialization
  await MobileAds.instance.initialize();
  await Purchases.configure(PurchasesConfiguration("api_key_here"));

  runApp(const OdakKapsuluApp());
}

class OdakKapsuluApp extends StatelessWidget {
  const OdakKapsuluApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Odak Kapsülü',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09090B),
        useMaterial3: true,
      ),
      home: const AuthGecisi(),
    );
  }
}

// --- AUTH BEKÇİSİ (OTURUM KONTROLÜ) ---
class AuthGecisi extends StatelessWidget {
  const AuthGecisi({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const AnaIskelet();
        }
        return const GirisEkran();
      },
    );
  }
}