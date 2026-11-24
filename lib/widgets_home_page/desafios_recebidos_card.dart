import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'apresentacao_desafios.dart';
import 'desafio_resumo_item.dart';

/// Desafios recebidos aguardando resposta: quem desafiou, a partida, a tabela
/// com o palpite do rival e as ações Responder e Recusar.
class DesafiosRecebidosCard extends StatelessWidget {
  final List<ChallengeModel> desafios;
  final ValueChanged<ChallengeModel> onResponder;
  final ValueChanged<ChallengeModel> onRecusar;
  final Set<String> recusando;

  const DesafiosRecebidosCard({
    super.key,
    required this.desafios,
    required this.onResponder,
    required this.onRecusar,
    this.recusando = const {},
  });

  @override
  Widget build(BuildContext context) {
    final dados = ApresentacaoDesafios.of(context);
    return Padding(
      key: const Key('home_desafios_recebidos_pendentes'),
      padding: const EdgeInsets.only(bottom: EspacosApp.e16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CabecalhoDeDesafios(
            'Recebidos',
            complemento: '${desafios.length} aguardando',
            complementoKey: const Key('badge_desafios_pendentes'),
            corDoTitulo: CoresApp.atencao,
          ),
          const SizedBox(height: EspacosApp.e4),
          ...desafios.map((c) {
            final nome = dados?.nome(c.challengerId) ?? 'Jogador';
            final primeiroNome = nome.split(' ').first;
            final ocupado = recusando.contains(c.id);
            return DesafioResumoItem(
              itemKey: Key('card_desafio_pendente_${c.id}'),
              destaque: CoresApp.atencao,
              titulo: Row(
                children: [
                  DiscoDeIniciais(nome, tamanho: 28),
                  const SizedBox(width: EspacosApp.e8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: nome,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: CoresApp.texto),
                        ),
                        const TextSpan(text: ' te desafiou'),
                      ]),
                      key: Key('desafio_pendente_challenger_${c.id}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextoApp.secundario.copyWith(fontSize: 15),
                    ),
                  ),
                ],
              ),
              lateral: Padding(
                padding: const EdgeInsets.only(top: EspacosApp.e4),
                child: Text(tempoRelativo(c.createdAt), style: TextoApp.minimo.copyWith(color: CoresApp.textoSuave)),
              ),
              partida: dados?.confronto(c.matchId) ?? 'Partida indisponível',
              contexto: dados?.contextoDaPartida(c.matchId),
              tabela: TabelaDoDesafio(
                key: Key('desafio_pendente_info_${c.id}'),
                rotuloDoPalpite: 'Palpite de $primeiroNome',
                palpite: dados?.palpite(c.challengerPrediction, c.matchId) ?? c.challengerPrediction.label,
                valor: c.amount,
              ),
              rodape: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: BotaoPrimario(
                      key: Key('btn_responder_desafio_${c.id}'),
                      rotulo: 'Responder',
                      pequeno: true,
                      larguraTotal: true,
                      onPressed: ocupado ? null : () => onResponder(c),
                    ),
                  ),
                  const SizedBox(width: EspacosApp.e8),
                  Expanded(
                    flex: 2,
                    child: BotaoSecundario(
                      key: Key('btn_recusar_desafio_${c.id}'),
                      rotulo: 'Recusar',
                      pequeno: true,
                      larguraTotal: true,
                      carregando: ocupado,
                      onPressed: () => onRecusar(c),
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
