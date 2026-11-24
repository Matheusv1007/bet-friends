import 'package:flutter/material.dart';

/// Navegação inferior da Home, sem controlar o índice selecionado.
/// Cores e rótulos vêm do `bottomNavigationBarTheme` do tema.
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
    // Ranking é pós-MVP (D-002, RN-RNK-001): Home, Desafiar e Perfil
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        // Desafiar abre Criar Desafio por cima da Home
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          activeIcon: Icon(Icons.add_circle),
          label: 'Desafiar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}
