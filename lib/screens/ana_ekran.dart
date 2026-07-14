import 'package:flutter/material.dart';
import 'package:odak_kapsulu/screens/akis_ekrani.dart';
import 'package:odak_kapsulu/screens/odak_ekrani.dart';
import 'package:odak_kapsulu/screens/terminal_ekrani.dart';
import 'package:odak_kapsulu/screens/profil_ekrani.dart';

class AnaIskelet extends StatefulWidget {
  const AnaIskelet({super.key});

  @override
  State<AnaIskelet> createState() => _AnaIskeletState();
}

class _AnaIskeletState extends State<AnaIskelet> {
  int _seciliSayfa = 0; // Default Screen: Akış (Index 0)

  final List<Widget> _sayfalar = [
    const AkisEkran(),
    const AnaEkran(),
    const TerminalEkran(),
    const ProfilEkran(),
  ];

  Widget _navItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final bool isSelected = _seciliSayfa == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _seciliSayfa = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF71717A),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF71717A),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _seciliSayfa,
        children: _sayfalar,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141419),
          border: Border(
            top: BorderSide(
              color: Color(0xFF2A2A35),
              width: 0.5,
          ),
        ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_outlined, Icons.home, 'Akış'),
              _navItem(1, Icons.timer_outlined, Icons.timer, 'Odak'),
              _navItem(2, Icons.hub_outlined, Icons.hub, 'Terminal'),
              _navItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}
