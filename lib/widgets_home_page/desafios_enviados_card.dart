import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import '../tema/tema.dart';
import 'apresentacao_desafios.dart';
import 'desafio_resumo_item.dart';

/// Desafios enviados aguardando o amigo; o criador ainda pode cancelar.
class DesafiosEnviadosCard extends StatelessWidget {
  final List<ChallengeModel> desafios;
  final ValueChanged<ChallengeModel> onCancelar;
  final Set<String> cancelando;

  const DesafiosEnviadosCard({super.key, required this.desafios, required this.onCancelar, this.cancelando = const {}});

  @override
  Widget build(BuildContext context) {
    final dados = ApresentacaoDesafios.of(context);
    return Padding(
      key: const Key('home_desafios_enviados_pendentes'),
      padding: const EdgeInsets.only(bottom: EspacosApp.e16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CabecalhoDeDesafios('Enviados', complemento: '${desafios.length}'),
          const SizedBox(height: EspacosApp.e4),
          ...desafios.map((c) {
            final nome = dados?.nome(c.challengedId) ?? 'Jogador';
            return DesafioResumoItem(
              itemKey: Key('card_desafio_enviado_${c.id}'),
              titulo: Padding(
                padding: const EdgeInsets.only(top: EspacosApp.e12),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Aguardando '),
                    TextSpan(
                      text: nome,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: CoresApp.texto),
                    ),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextoApp.secundario.copyWith(fontSize: 15),
                ),
              ),
              lateral: TextButton(
                key: Key('btn_cancelar_desafio_${c.id}'),
                onPressed: cancelando.contains(c.id) ? null : () => onCancelar(c),
                style: TextButton.styleFrom(
                  foregroundColor: CoresApp.destrutivo,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: EspacosApp.e8),
                  textStyle: TextoApp.corpoForte,
                ),
                child: const Text('Cancelar'),
              ),
              partida: dados?.confronto(c.matchId) ?? 'Partida indisponível',
              contexto: dados?.contextoDaPartida(c.matchId),
              tabela: TabelaDoDesafio(
                rotuloDoPalpite: 'Seu palpite',
                palpite: dados?.palpite(c.challengerPrediction, c.matchId) ?? c.challengerPrediction.label,
                valor: c.amount,
              ),
            );
          }),
        ],
      ),
    );
  }
}
