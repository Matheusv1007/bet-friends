import 'package:flutter/material.dart';

class DesafiosVazios extends StatelessWidget {
  final VoidCallback onCriarDesafio;

  const DesafiosVazios({super.key, required this.onCriarDesafio});

  @override
  Widget build(BuildContext context) {
      return Column(
        key: const Key('home_desafios_em_aberto'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DESAFIOS EM ABERTO",
            style: TextStyle(
              color: Color(0xFF8E9CAE),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('home_desafios_vazio'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF151E2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sports_kabaddi,
                  color: Color(0xFF64748B),
                  size: 36,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Nenhum desafio no momento",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Crie um desafio com seus amigos para começar a apostar BetCoins!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8E9CAB),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const Key('btn_home_criar_desafio'),
                  onPressed: onCriarDesafio,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    "CRIAR DESAFIO",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D084),
                    foregroundColor: const Color(0xFF062319),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
  }
}

