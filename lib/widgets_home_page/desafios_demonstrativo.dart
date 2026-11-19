import 'package:flutter/material.dart';

import 'desafio_resumo_item.dart';

class DesafiosDemonstrativo extends StatelessWidget {


  const DesafiosDemonstrativo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Os desafios abaixo são exemplos fixos até existir o backend de desafios
        Row(
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "DEMONSTRATIVO",
                key: Key('desafios_ativos_demonstrativo'),
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DesafioResumoItem(
          jogador1: "Pedro",
          jogador2: "Lucas",
          onTap: () {},
        ),
        DesafioResumoItem(
          jogador1: "Guilherme",
          jogador2: "Gustavo",
          onTap: () {},
        ),
      ],
    );
  }
}

