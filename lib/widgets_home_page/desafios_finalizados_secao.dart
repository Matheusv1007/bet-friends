import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'apresentacao_desafios.dart';
import 'desafio_resumo_item.dart';

/// Desafios encerrados com o resultado e o efeito nos BetCoins à direita.
class DesafiosFinalizadosSecao extends StatelessWidget {
  final List<ChallengeModel> desafios;
  final String? currentUserId;
  final ValueChanged<ChallengeModel> onDetalhes;
  final VoidCallback? onVerTodos;
  final bool exibirCabecalho;

  const DesafiosFinalizadosSecao({super.key, required this.desafios, required this.currentUserId, required this.onDetalhes, this.onVerTodos, this.exibirCabecalho = true});

  @override
  Widget build(BuildContext context) {
    final dados = ApresentacaoDesafios.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (exibirCabecalho) ...[
          CabecalhoDeDesafios(
            'Finalizados',
            tituloKey: const Key('home_desafios_finalizados'),
            complemento: '${desafios.length}',
            complementoKey: const Key('badge_desafios_finalizados'),
            acao: onVerTodos == null
                ? null
                : BotaoTexto(
                    key: const Key('home_ver_todos_desafios'),
                    rotulo: 'Ver todos',
                    pequeno: true,
                    onPressed: onVerTodos,
                  ),
          ),
          const SizedBox(height: EspacosApp.e4),
        ],
        ...desafios.map((c) {
          final (rotulo, valor, cor) = _resultado(c, dados);
          final liga = dados?.contextoDaPartida(c.matchId, comHorario: false);
          return DesafioResumoItem(
            itemKey: Key('card_desafio_finalizado_${c.id}'),
            botaoKey: Key('btn_detalhes_desafio_finalizado_${c.id}'),
            onTap: () => onDetalhes(c),
            titulo: Text(
              '${dados?.nome(c.challengerId) ?? 'Jogador'} x ${dados?.nome(c.challengedId) ?? 'Jogador'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextoApp.corpo.copyWith(color: CoresApp.texto),
            ),
            lateral: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rotulo,
                    key: Key('resultado_desafio_${c.id}'),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextoApp.minimo.copyWith(color: cor == CoresApp.texto ? CoresApp.textoSuave : cor),
                  ),
                  if (valor != null)
                    Text(valor, key: Key('valor_desafio_${c.id}'), style: TextoApp.placar.copyWith(color: cor)),
                ],
              ),
            ),
            partida: dados?.confronto(c.matchId, comPlacar: true) ?? 'Partida indisponível',
            contexto: [?liga, 'aposta ${c.amount}'].join(' · '),
          );
        }),
      ],
    );
  }

  /// Rótulo, valor com sinal e cor do desfecho; o valor segue [ChallengeModel.efeitoNosBetCoins].
  (String, String?, Color) _resultado(ChallengeModel c, ApresentacaoDesafios? dados) {
    final uid = currentUserId;
    final efeito = uid == null ? null : c.efeitoNosBetCoins(uid);
    final participa = uid != null && c.temParticipante(uid);
    if (c.winnerId != null) {
      if (c.winnerId == uid) return ('Você venceu!', '+${c.amount}', CoresApp.primario);
      if (participa && efeito != null) return ('Você perdeu', '−${c.amount}', CoresApp.destrutivo);
      return ('Vencedor: ${dados?.nome(c.winnerId!) ?? 'Jogador'}', null, CoresApp.texto);
    }
    final valor = participa ? '0' : null;
    if (c.status == StatusDesafio.finished) return ('Ninguém acertou', valor, CoresApp.texto);
    return (c.motivoDoCancelamento ?? c.status.label, valor, CoresApp.texto);
  }
}
