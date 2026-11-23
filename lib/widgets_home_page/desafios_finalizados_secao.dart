import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import 'apresentacao_desafios.dart';
import 'desafio_resumo_item.dart';

class DesafiosFinalizadosSecao extends StatelessWidget {
  final List<ChallengeModel> desafios;
  final String? currentUserId;
  final ValueChanged<ChallengeModel> onDetalhes;

  const DesafiosFinalizadosSecao({super.key, required this.desafios, required this.currentUserId, required this.onDetalhes});

  @override
  Widget build(BuildContext context) {
    final dados = ApresentacaoDesafios.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                "DESAFIOS FINALIZADOS",
                key: Key('home_desafios_finalizados'),
                style: TextStyle(
                  color: Color(0xFF8E9CAE),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const Key('badge_desafios_finalizados'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: const Text(
                  "RESULTADOS",
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...desafios.map((c) {
            final venceu = currentUserId != null && c.winnerId == currentUserId;
            final efeito = currentUserId == null ? null : c.efeitoNosBetCoins(currentUserId!);
            final semVencedor = c.status == StatusDesafio.finished && c.winnerId == null;
            final resultadoLabel = c.winnerId != null
                ? (venceu
                    ? "Você venceu!${efeito == null ? '' : ' $efeito'}"
                    : "Vencedor: ${dados?.nome(c.winnerId!) ?? 'Jogador'}${efeito == null ? '' : ' • $efeito'}")
                : semVencedor
                    ? "Ninguém acertou • apostas devolvidas"
                    : c.motivoDoCancelamento ?? "Status: ${c.status.label}";
            final resultadoColor = venceu
                ? const Color(0xFF00D084)
                : (c.winnerId != null ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8));

            return DesafioResumoItem(
              itemKey: Key('card_desafio_finalizado_${c.id}'),
              botaoKey: Key('btn_detalhes_desafio_finalizado_${c.id}'),
              jogador1: dados?.nome(c.challengerId) ?? 'Jogador',
              jogador2: dados?.nome(c.challengedId) ?? 'Jogador',
              subtitulo: "${dados?.partida(c.matchId) ?? 'Partida indisponível'} • ${c.amount} BetCoins",
              statusLabel: resultadoLabel,
              statusColor: resultadoColor,
              botaoLabel: "Resultado",
              onTap: () => onDetalhes(c),
            );
          }),
      ],
    );
  }
}

