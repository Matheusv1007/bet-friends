import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import '../tema/tema.dart';
import 'apresentacao_desafios.dart';

class DetalhesDoDesafioDialog extends StatelessWidget {
  final ChallengeModel desafio;

  const DetalhesDoDesafioDialog({super.key, required this.desafio});

  @override
  Widget build(BuildContext context) {
    final dados = ApresentacaoDesafios.of(context);
    final c = desafio;
    final uid = dados?.currentUserId;
    final efeito = uid == null ? null : c.efeitoNosBetCoins(uid);
    const suave = TextStyle(color: CoresApp.textoSuave);
    const forte = TextStyle(color: CoresApp.texto, fontWeight: FontWeight.w600);
    Widget linha(String texto, [TextStyle estilo = suave]) => Padding(
          padding: const EdgeInsets.only(top: EspacosApp.e8),
          child: Text(texto, style: TextoApp.secundario.merge(estilo)),
        );
    return AlertDialog(
      title: const Text('Detalhes do desafio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dados?.confronto(c.matchId, comPlacar: true) ?? 'Partida indisponível',
              style: TextoApp.corpoForte.copyWith(color: CoresApp.texto),
            ),
            if (dados?.contextoDaPartida(c.matchId) case final contexto?)
              Text(contexto, style: TextoApp.secundario),
            const Divider(height: EspacosApp.e24),
            Text('Aposta: ${c.amount} BetCoins', style: TextoApp.secundario.merge(forte)),
            linha('Status: ${c.status.label}'),
            if (c.motivoDoCancelamento != null) linha(c.motivoDoCancelamento!),
            linha("Criador: ${dados?.nome(c.challengerId) ?? 'Jogador'} (${c.challengerPrediction.label})"),
            if (c.challengedPrediction != null)
              linha("Desafiado: ${dados?.nome(c.challengedId) ?? 'Jogador'} (${c.challengedPrediction!.label})"),
            if (c.settledResult != null) linha('Resultado oficial: ${c.settledResult!.label}'),
            if (c.winnerId != null) linha("Vencedor: ${dados?.nome(c.winnerId!) ?? 'Jogador'}", forte),
            if (efeito != null)
              linha(
                'BetCoins: $efeito',
                forte.copyWith(
                  color: efeito.startsWith('+')
                      ? CoresApp.primario
                      : efeito.startsWith('-') ? CoresApp.destrutivo : CoresApp.texto,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
