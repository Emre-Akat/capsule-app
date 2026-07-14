import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GirisEkran extends StatefulWidget {
  const GirisEkran({super.key});

  @override
  State<GirisEkran> createState() => _GirisEkranState();
}

class _GirisEkranState extends State<GirisEkran> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailKontrol = TextEditingController();
  final TextEditingController _sifreKontrol = TextEditingController();
  final TextEditingController _kullaniciAdiKontrol = TextEditingController();

  bool _kayitModuMu = false;
  bool _yukleniyor = false;
  bool _sifreGorunur = false;

  void _authIslemiYap() async {
    String email = _emailKontrol.text.trim();
    String sifre = _sifreKontrol.text.trim();
    String kullaniciAdi = _kullaniciAdiKontrol.text.trim();

    if (email.isEmpty || sifre.isEmpty) {
      _hataGoster('Lütfen tüm alanları doldurun.');
      return;
    }

    if (_kayitModuMu && kullaniciAdi.isEmpty) {
      _hataGoster('Lütfen bir kullanıcı adı seçin.');
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      if (_kayitModuMu) {
        UserCredential sonuc = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: sifre,
        );

        if (sonuc.user != null) {
          await _firestore.collection('kullanicilar').doc(sonuc.user!.uid).set({
            'xp': 0,
            'jeton': 5,
            'kullaniciAdi': kullaniciAdi,
            'email': email,
            'kayitTarihi': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await _auth.signInWithEmailAndPassword(email: email, password: sifre);
      }
    } catch (hata) {
      if (mounted) {
        _hataGoster(hata.toString().split(']').last.trim());
      }
    } finally {
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: const Color(0xFFFF453A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.blur_on_rounded, size: 64, color: Colors.white),
              const SizedBox(height: 24),
              Text(
                _kayitModuMu ? 'Kapsüle Kaydol' : 'Kapsüle Giriş Yap',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              if (_kayitModuMu) ...[
                TextField(
                  controller: _kullaniciAdiKontrol,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: _inputDekorasyonu('Kullanıcı Adı'),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailKontrol,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _inputDekorasyonu('E-posta Adresi'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sifreKontrol,
                obscureText: !_sifreGorunur,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _inputDekorasyonu('Şifre').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _sifreGorunur ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF71717A),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _sifreGorunur = !_sifreGorunur),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _yukleniyor ? null : _authIslemiYap,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _yukleniyor ? const Color(0x800A84FF) : const Color(0xFF0A84FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _yukleniyor
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _kayitModuMu ? 'KAYIT OL' : 'GİRİŞ YAP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _kayitModuMu = !_kayitModuMu;
                  });
                },
                child: Text(
                  _kayitModuMu ? 'Zaten hesabın var mı? Giriş yap' : 'Hesabın yok mu? Kayıt ol',
                  style: const TextStyle(color: Color(0xFF0A84FF), fontSize: 13, fontWeight: FontWeight.normal),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDekorasyonu(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF71717A)),
      filled: true,
      fillColor: const Color(0xFF18181B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFF27272A),
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFF0A84FF),
          width: 1.0,
        ),
      ),
    );
  }
}
