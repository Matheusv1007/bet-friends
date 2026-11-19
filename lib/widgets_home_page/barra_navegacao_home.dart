import 'package:flutter/material.dart';

/// Navegação inferior da Home, sem controlar o índice selecionado.
class BarraNavegacaoHome extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BarraNavegacaoHome({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E1420),
        border: Border(top: BorderSide(color: Color(0xFF1B2536), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        // Ranking é pós-MVP (D-002, RN-RNK-001): Home, Desafios e Perfil
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00D084),
        unselectedItemColor: const Color(0xFF64748B),
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_kabaddi_outlined),
            activeIcon: Icon(Icons.sports_kabaddi),
            label: "Desafios",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Perfil",
          ),
        ],
      ),
    );
  }
}
