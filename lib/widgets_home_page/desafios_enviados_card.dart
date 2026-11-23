import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import 'apresentacao_desafios.dart';

class DesafiosEnviadosCard extends StatelessWidget {
  final List<ChallengeModel> desafios;
  final ValueChanged<ChallengeModel> onCancelar;
  final Set<String> cancelando;

  const DesafiosEnviadosCard({super.key, required this.desafios, required this.onCancelar, this.cancelando = const {}});

  @override
  Widget build(BuildContext context) {
    final dados = ApresentacaoDesafios.of(context);
    return Container(
            key: const Key('home_desafios_enviados_pendentes'),
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF151E2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DESAFIOS ENVIADOS",
                  style: TextStyle(
                    color: Color(0xFF8E9CAE),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                ...desafios.map((c) {
                  return Container(
                    key: Key('card_desafio_enviado_${c.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1420),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Aguardando ${dados?.nome(c.challengedId) ?? 'Jogador'}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${dados?.partida(c.matchId) ?? 'Partida indisponível'} • ${c.amount} BetCoins",
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Seu palpite: ${c.challengerPrediction.label}",
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          key: Key('btn_cancelar_desafio_${c.id}'),
                          onPressed: cancelando.contains(c.id) ? null : () => onCancelar(c),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "CANCELAR",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
  }
}

