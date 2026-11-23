import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import 'apresentacao_desafios.dart';
import 'desafio_resumo_item.dart';

class DesafiosEmAbertoSecao extends StatelessWidget {
  final List<ChallengeModel> desafios;
  final ValueChanged<ChallengeModel> onDetalhes;

  const DesafiosEmAbertoSecao({super.key, required this.desafios, required this.onDetalhes});

  @override
  Widget build(BuildContext context) {
    final dados = ApresentacaoDesafios.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "DESAFIOS EM ABERTO",
              key: Key('home_desafios_em_aberto'),
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
                color: const Color(0xFF00D084).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF00D084).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                "${desafios.length} ATIVO(S)",
                style: const TextStyle(
                  color: Color(0xFF00D084),
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (desafios.isEmpty)
          Container(
            key: const Key('home_desafios_em_aberto_vazio'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF151E2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.sports_kabaddi, color: Color(0xFF94A3B8), size: 24),
                SizedBox(width: 12),
                Text(
                  "Nenhum desafio em aberto",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ...desafios.map((c) {
            return DesafioResumoItem(
              itemKey: Key('card_desafio_aberto_${c.id}'),
              botaoKey: Key('btn_detalhes_desafio_${c.id}'),
              jogador1: dados?.nome(c.challengerId) ?? 'Jogador',
              jogador2: dados?.nome(c.challengedId) ?? 'Jogador',
              subtitulo: "${dados?.partida(c.matchId) ?? 'Partida indisponível'} • ${c.amount} BetCoins",
              statusLabel: c.status.label,
              statusColor: const Color(0xFF00D084),
              botaoLabel: "Detalhes do Desafio",
              onTap: () => onDetalhes(c),
            );
          }),
      ],
    );
  }
}

