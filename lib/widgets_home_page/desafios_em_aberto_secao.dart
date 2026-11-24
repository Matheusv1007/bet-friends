import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'apresentacao_desafios.dart';
import 'desafio_resumo_item.dart';

/// Desafios aceitos, em andamento ou aguardando resultado.
class DesafiosEmAbertoSecao extends StatelessWidget {
  final List<ChallengeModel> desafios;
  final ValueChanged<ChallengeModel> onDetalhes;

  const DesafiosEmAbertoSecao({super.key, required this.desafios, required this.onDetalhes});

  @override
  Widget build(BuildContext context) {
    final dados = ApresentacaoDesafios.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: EspacosApp.e16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CabecalhoDeDesafios(
            'Em aberto',
            tituloKey: const Key('home_desafios_em_aberto'),
            complemento: desafios.length == 1 ? '1 ativo' : '${desafios.length} ativos',
          ),
          const SizedBox(height: EspacosApp.e4),
          if (desafios.isEmpty)
            Container(
              key: const Key('home_desafios_em_aberto_vazio'),
              padding: const EdgeInsets.all(EspacosApp.e16),
              decoration: const BoxDecoration(
                color: CoresApp.superficie1,
                borderRadius: RaiosApp.bordaCartao,
              ),
              child: const Text('Nenhum desafio em aberto', style: TextoApp.secundario),
            )
          else
            ...desafios.map((c) {
              final souCriador = c.challengerId == dados?.currentUserId;
              final meuPalpite = souCriador ? c.challengerPrediction : c.challengedPrediction;
              return DesafioResumoItem(
                itemKey: Key('card_desafio_aberto_${c.id}'),
                botaoKey: Key('btn_detalhes_desafio_${c.id}'),
                onTap: () => onDetalhes(c),
                titulo: Text(
                  '${dados?.nome(c.challengerId) ?? 'Jogador'} x ${dados?.nome(c.challengedId) ?? 'Jogador'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextoApp.corpo.copyWith(color: CoresApp.texto),
                ),
                lateral: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TagDeStatus(
                      c.status.label,
                      c.status == StatusDesafio.inProgress ? Tom.atencao : Tom.neutro,
                    ),
                    const Icon(Icons.chevron_right, color: CoresApp.textoSuave, semanticLabel: 'Detalhes do desafio'),
                  ],
                ),
                partida: dados?.confronto(c.matchId, comPlacar: true) ?? 'Partida indisponível',
                contexto: dados?.contextoDaPartida(c.matchId),
                tabela: meuPalpite == null
                    ? null
                    : TabelaDoDesafio(
                        rotuloDoPalpite: 'Seu palpite',
                        palpite: dados?.palpite(meuPalpite, c.matchId) ?? meuPalpite.label,
                        valor: c.amount,
                      ),
              );
            }),
        ],
      ),
    );
  }
}
