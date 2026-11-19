import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import 'apresentacao_desafios.dart';

class DetalhesDoDesafioDialog extends StatelessWidget {
  final ChallengeModel desafio;

  const DetalhesDoDesafioDialog({super.key, required this.desafio});

  @override
  Widget build(BuildContext context) {
    final dados = ApresentacaoDesafios.of(context);
    final c = desafio;
    return AlertDialog(
        backgroundColor: const Color(0xFF151E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Detalhes do Desafio",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Partida: ${dados?.partida(c.matchId) ?? 'Partida indisponível'}", style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text("Aposta: ${c.amount} BetCoins", style: const TextStyle(color: Color(0xFF00D084), fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("Status: ${c.status.label}", style: const TextStyle(color: Colors.white70)),
            if (c.motivoDoCancelamento != null) ...[
              const SizedBox(height: 6),
              Text(c.motivoDoCancelamento!, style: const TextStyle(color: Color(0xFFF59E0B))),
            ],
            const SizedBox(height: 6),
            Text("Criador: ${dados?.nome(c.challengerId) ?? 'Amigo'} (${c.challengerPrediction.label})", style: const TextStyle(color: Colors.white70)),
            if (c.challengedPrediction != null) ...[
              const SizedBox(height: 6),
              Text("Desafiado: ${dados?.nome(c.challengedId) ?? 'Amigo'} (${c.challengedPrediction!.label})", style: const TextStyle(color: Colors.white70)),
            ],
            if (c.winnerId != null) ...[
              const SizedBox(height: 8),
              Text("Vencedor: ${dados?.nome(c.winnerId!) ?? 'Amigo'}", style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fechar", style: TextStyle(color: Color(0xFF00D084))),
          ),
        ],
      );
  }
}

