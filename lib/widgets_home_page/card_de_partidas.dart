import 'package:flutter/material.dart';

import '../models/partida_model.dart';
import '../tela_criar_desafio/tela_criar_desafio.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import '../widgets/texto_sem_corte.dart';
import 'detalhes_da_partida_sheet.dart';
import 'escudo_do_time.dart';

/// Etiqueta de estado da partida ("AO VIVO 67'", "PRÓXIMO JOGO"...).
class TagDaPartida extends StatelessWidget {
  final PartidaModel partida;

  const TagDaPartida(this.partida, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = partida;
    if (p.isAoVivo) {
      final minuto = p.minuto?.trim();
      return TagDeStatus(
        (minuto == null || minuto.isEmpty) ? 'Ao vivo' : 'Ao vivo $minuto',
        Tom.atencao,
      );
    }
    if (p.isFinalizado) return const TagDeStatus('Finalizado', Tom.neutro);
    if (p.isAdiado) return const TagDeStatus('Adiado', Tom.atencao);
    if (p.isCancelado) return const TagDeStatus('Cancelado', Tom.destrutivo);
    if (p.statusDominio == StatusPartida.suspensa) {
      return const TagDeStatus('Suspensa', Tom.atencao);
    }
    if (p.statusDominio == StatusPartida.revisaoNecessaria) {
      return const TagDeStatus('Em revisão', Tom.neutro);
    }
    return const TagDeStatus('Próximo jogo', Tom.neutro);
  }
}

/// Abre Criar Desafio com a [partida] já escolhida.
void abrirDesafioNaPartida(BuildContext context, PartidaModel partida) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CriarDesafioScreen(preSelectedMatchId: partida.id),
    ),
  );
}

/// Linha de partida da Home: status, liga e rodada no topo; mandante em
/// cima e visitante embaixo, cada um com disco e nome em até 2 linhas; à
/// direita o placar (ao vivo e finalizada) ou o horário e "Desafiar".
///
/// Não desenha fundo próprio: fica dentro do grupo da lista.
class Carddepartidas extends StatelessWidget {
  final PartidaModel? partida;
  final VoidCallback? onTap;

  const Carddepartidas({super.key, this.partida, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = partida;
    final comPlacar = p != null && (p.isAoVivo || p.isFinalizado);
    final golsM = comPlacar ? (p.golsMandante ?? 0) : null;
    final golsV = comPlacar ? (p.golsVisitante ?? 0) : null;
    final perdeM = golsM != null && golsV != null && golsM < golsV;
    final perdeV = golsM != null && golsV != null && golsV < golsM;

    final times = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LinhaDoTime(
          nome: p?.timeMandante ?? 'Mandante',
          escudo: p?.logoMandante,
          gols: golsM,
          apagado: perdeM,
        ),
        const SizedBox(height: EspacosApp.e8),
        _LinhaDoTime(
          nome: p?.timeVisitante ?? 'Visitante',
          escudo: p?.logoVisitante,
          gols: golsV,
          apagado: perdeV,
        ),
      ],
    );

    final conteudo = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: EspacosApp.e16,
        vertical: EspacosApp.e12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p != null) ...[
            _Cabecalho(partida: p),
            const SizedBox(height: EspacosApp.e8),
          ],
          LayoutBuilder(
            builder: (context, restricoes) {
              final lateral = p == null || comPlacar
                  ? null
                  : _ColunaDoHorario(
                      partida: p,
                      larguraMaxima: restricoes.maxWidth * 0.42,
                    );
              if (lateral != null &&
                  restricoes.maxWidth /
                          MediaQuery.textScalerOf(context).scale(1) <
                      280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    times,
                    const SizedBox(height: EspacosApp.e8),
                    Align(alignment: Alignment.centerRight, child: lateral),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: times),
                  if (lateral != null) ...[
                    const SizedBox(width: EspacosApp.e12),
                    lateral,
                  ],
                ],
              );
            },
          ),
          if (p != null && p.isAoVivo) _BarraDoMinuto(minuto: p.minuto),
        ],
      ),
    );

    return InkWell(
      key: Key('card_partida_${p?.id ?? "desconhecida"}'),
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else if (p != null) {
          DetalhesDaPartidaSheet.exibir(context, p);
        }
      },
      child: conteudo,
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final PartidaModel partida;

  const _Cabecalho({required this.partida});

  @override
  Widget build(BuildContext context) {
    final rodada = partida.matchday;
    return Wrap(
      spacing: EspacosApp.e8,
      runSpacing: EspacosApp.e4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TagDaPartida(partida),
        Text(
          partida.nomeDoCampeonato,
          key: Key('partida_campeonato_${partida.id}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextoApp.secundario,
        ),
        if (rodada != null)
          Text('· Rodada $rodada', maxLines: 1, style: TextoApp.secundario),
      ],
    );
  }
}

class _LinhaDoTime extends StatelessWidget {
  final String nome;
  final String? escudo;
  final int? gols;
  final bool apagado;

  const _LinhaDoTime({
    required this.nome,
    required this.escudo,
    required this.gols,
    required this.apagado,
  });

  @override
  Widget build(BuildContext context) {
    final cor = apagado ? CoresApp.textoSuave : CoresApp.texto;
    return Row(
      children: [
        EscudoDoTime(url: escudo, nome: nome, tamanho: 24),
        const SizedBox(width: EspacosApp.e12),
        Expanded(
          child: TextoSemCorte(
            nome,
            estilo: TextoApp.corpo.copyWith(
              color: cor,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
        if (gols != null) ...[
          const SizedBox(width: EspacosApp.e12),
          Text('$gols', style: TextoApp.placar.copyWith(color: cor)),
        ],
      ],
    );
  }
}

/// Horário e "Desafiar" das partidas que ainda não começaram.
class _ColunaDoHorario extends StatelessWidget {
  final PartidaModel partida;
  final double larguraMaxima;

  const _ColunaDoHorario({required this.partida, required this.larguraMaxima});

  @override
  Widget build(BuildContext context) {
    final agendada = partida.isAgendado;
    final podeDesafiar = agendada && partida.podeCriarDesafio;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: larguraMaxima),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            partida.horario ?? 'A definir',
            textAlign: TextAlign.end,
            maxLines: 2,
            style: TextoApp.secundario.copyWith(
              fontWeight: agendada ? FontWeight.w600 : FontWeight.w400,
              color: agendada ? CoresApp.texto : CoresApp.textoSuave,
            ),
          ),
          if (podeDesafiar) ...[
            const SizedBox(height: EspacosApp.e4),
            BotaoSecundario(
              key: Key('btn_desafiar_partida_${partida.id}'),
              rotulo: 'Desafiar',
              pequeno: true,
              onPressed: () => abrirDesafioNaPartida(context, partida),
            ),
          ],
        ],
      ),
    );
  }
}

/// Progresso do jogo ao vivo pelo minuto informado ("67'"); some se o
/// provedor não mandou um minuto numérico.
class _BarraDoMinuto extends StatelessWidget {
  final String? minuto;

  const _BarraDoMinuto({required this.minuto});

  @override
  Widget build(BuildContext context) {
    final numero = int.tryParse(
      RegExp(r'\d+').firstMatch(minuto ?? '')?.group(0) ?? '',
    );
    if (numero == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: EspacosApp.e12),
      child: ClipRRect(
        borderRadius: RaiosApp.bordaTag,
        child: LinearProgressIndicator(
          value: (numero / 90).clamp(0.0, 1.0),
          minHeight: 2,
          color: CoresApp.atencao,
          backgroundColor: CoresApp.filete,
        ),
      ),
    );
  }
}
