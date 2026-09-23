import 'package:flutter/material.dart';

class DesafiosAtivosWidget extends StatelessWidget {
  const DesafiosAtivosWidget({super.key});

  Widget _buildDesafioItem({
    required String jogador1,
    required String jogador2,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatares sobrepostos dos dois jogadores
          SizedBox(
            width: 48,
            height: 32,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF151E2E),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(0xFF334155),
                      child: Icon(Icons.person, size: 18, color: Colors.white70),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF151E2E),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(0xFF475569),
                      child: Icon(Icons.person, size: 18, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Nomes
          Expanded(
            child: Text(
              "$jogador1 x $jogador2",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),

          // Botão "Detalhes do Desafio"
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2425),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF00D084).withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: const Text(
                "Detalhes do Desafio",
                style: TextStyle(
                  color: Color(0xFF00D084),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "DESAFIOS ATIVOS",
          style: TextStyle(
            color: Color(0xFF8E9CAE),
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _buildDesafioItem(
          jogador1: "Pedro",
          jogador2: "Lucas",
          onTap: () {},
        ),
        _buildDesafioItem(
          jogador1: "Guilherme",
          jogador2: "Gustavo",
          onTap: () {},
        ),
      ],
    );
  }
}
