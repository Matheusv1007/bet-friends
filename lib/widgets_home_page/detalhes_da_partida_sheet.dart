import 'package:flutter/material.dart';

import '../models/partida_model.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import '../widgets/texto_sem_corte.dart';
import 'card_de_partidas.dart';
import 'escudo_do_time.dart';

/// Bottom sheet com os detalhes de uma partida, a partir dos dados normalizados
/// do domínio (KAN-43; RF-008, RN-MAT-005, RNF-005, RNF-013).
///
/// Diretrizes:
/// - Exibe mandante e visitante com destaque, em colunas.
/// - Data e horário no fuso do dispositivo, cada um numa linha (RN-MAT-005).
/// - Status exibido a partir do enum/domínio interno (RF-008, RNF-013).
/// - Placar e resultado normalizado apresentados quando disponíveis.
/// - Nenhum enum ou payload bruto do provedor externo é exposto (RN-MAT-002, RNF-013).
class DetalhesDaPartidaSheet extends StatelessWidget {
  final PartidaModel partida;

  const DetalhesDaPartidaSheet({
    super.key,
    required this.partida,
  });

  /// Abre os detalhes da [partida] num bottom sheet.
  static Future<void> exibir(BuildContext context, PartidaModel partida) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DetalhesDaPartidaSheet(partida: partida),
    );
  }

  static const _diasDaSemana = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  static String _doisDigitos(int n) => n.toString().padLeft(2, '0');

  /// "Domingo, 23/11/2026", no fuso do dispositivo; sem data, o horário
  /// informado pelo provedor ou "A definir".
  static String dataLocal(PartidaModel partida) {
    final inicio = partida.startsAtUtc;
    if (inicio == null) return partida.horario ?? 'A definir';
    final local = inicio.toLocal();
    return '${_diasDaSemana[local.weekday - 1]}, '
        '${_doisDigitos(local.day)}/${_doisDigitos(local.month)}/${local.year}';
  }

  /// "22:39", no fuso do dispositivo; `null` sem data de início.
  static String? horarioLocal(PartidaModel partida) {
    final inicio = partida.startsAtUtc;
    if (inicio == null) return null;
    final local = inicio.toLocal();
    return '${_doisDigitos(local.hour)}:${_doisDigitos(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final temPlacar = partida.golsMandante != null && partida.golsVisitante != null;
    final resultado = partida.resultadoNormalizadoDescricao;
    final horario = horarioLocal(partida);
    final rodada = partida.matchday;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        EspacosApp.e20,
        0,
        EspacosApp.e20,
        EspacosApp.e20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: EspacosApp.e12,
            runSpacing: EspacosApp.e4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Detalhes da partida',
                  style: TextoApp.tituloDeBarra.copyWith(color: CoresApp.texto),
                ),
              ),
              TagDaPartida(partida),
            ],
          ),
          const SizedBox(height: EspacosApp.e4),
          Text(
            '${partida.nomeDoCampeonato}${rodada != null ? ' · Rodada $rodada' : ''}',
            style: TextoApp.secundario,
          ),
          const SizedBox(height: EspacosApp.e24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Clube(
                  chaveDoEscudo: const Key('detalhes_partida_escudo_mandante'),
                  chaveDoNome: const Key('detalhes_partida_mandante'),
                  nome: partida.timeMandante,
                  escudo: partida.logoMandante,
                  papel: 'Mandante',
                ),
              ),
              SizedBox(
                height: 56,
                child: Center(
                  child: temPlacar
                      ? Text(
                          partida.placarTexto,
                          key: const Key('detalhes_partida_placar'),
                          style: TextoApp.placar.copyWith(color: CoresApp.texto),
                        )
                      : Text(
                          'x',
                          style: TextoApp.corpo.copyWith(color: CoresApp.textoSuave),
                        ),
                ),
              ),
              Expanded(
                child: _Clube(
                  chaveDoEscudo: const Key('detalhes_partida_escudo_visitante'),
                  chaveDoNome: const Key('detalhes_partida_visitante'),
                  nome: partida.timeVisitante,
                  escudo: partida.logoVisitante,
                  papel: 'Visitante',
                ),
              ),
            ],
          ),
          const SizedBox(height: EspacosApp.e20),
          const Divider(height: 1),
          _LinhaDeInformacao(
            rotulo: 'Data',
            valor: dataLocal(partida),
            chave: const Key('detalhes_partida_data'),
          ),
          if (horario != null)
            _LinhaDeInformacao(
              rotulo: 'Horário (local)',
              valor: horario,
              chave: const Key('detalhes_partida_horario'),
            ),
          _LinhaDeInformacao(
            rotulo: 'Status',
            valor: partida.statusDominio.rotulo,
            chave: const Key('detalhes_partida_status'),
          ),
          if (resultado != null)
            _LinhaDeInformacao(
              rotulo: 'Resultado',
              valor: resultado,
              chave: const Key('detalhes_partida_resultado'),
              quebraLinha: true,
            )
          else if (!temPlacar) ...[
            const SizedBox(height: EspacosApp.e12),
            const Text(
              'Partida ainda não iniciada ou sem placar confirmado.',
              key: Key('detalhes_partida_sem_placar'),
              style: TextoApp.secundario,
            ),
          ],
          const SizedBox(height: EspacosApp.e20),
          if (partida.podeCriarDesafio) ...[
            BotaoPrimario(
              key: const Key('btn_desafiar_partida'),
              rotulo: 'Desafiar nesta partida',
              larguraTotal: true,
              onPressed: () {
                Navigator.pop(context);
                abrirDesafioNaPartida(context, partida);
              },
            ),
            const SizedBox(height: EspacosApp.e8),
          ],
          BotaoSecundario(
            key: const Key('btn_fechar_detalhes_partida'),
            rotulo: 'Fechar',
            larguraTotal: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _Clube extends StatelessWidget {
  final Key chaveDoEscudo;
  final Key chaveDoNome;
  final String nome;
  final String? escudo;
  final String papel;

  const _Clube({
    required this.chaveDoEscudo,
    required this.chaveDoNome,
    required this.nome,
    required this.escudo,
    required this.papel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EscudoDoTime(key: chaveDoEscudo, url: escudo, nome: nome, tamanho: 56),
        const SizedBox(height: EspacosApp.e8),
        TextoSemCorte(
          nome,
          key: chaveDoNome,
          alinhamento: TextAlign.center,
          estilo: TextoApp.corpoForte.copyWith(color: CoresApp.texto, height: 1.25),
        ),
        const SizedBox(height: 2),
        Text(papel, style: TextoApp.secundario),
      ],
    );
  }
}

/// Rótulo à esquerda e valor à direita, com filete embaixo. Data e horário
/// ficam numa linha só; só o resultado, que é uma frase, pode quebrar.
class _LinhaDeInformacao extends StatelessWidget {
  final String rotulo;
  final String valor;
  final Key chave;
  final bool quebraLinha;

  const _LinhaDeInformacao({
    required this.rotulo,
    required this.valor,
    required this.chave,
    this.quebraLinha = false,
  });

  @override
  Widget build(BuildContext context) {
    final textoDoValor = Text(
      valor,
      key: chave,
      textAlign: TextAlign.end,
      softWrap: quebraLinha,
      style: TextoApp.corpoForte.copyWith(color: CoresApp.texto),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: EspacosApp.alvoDeToque),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: EspacosApp.e12),
            child: Row(
              children: [
                Text(rotulo, style: TextoApp.secundario),
                const SizedBox(width: EspacosApp.e16),
                Expanded(
                  child: quebraLinha
                      ? textoDoValor
                      : Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(fit: BoxFit.scaleDown, child: textoDoValor),
                        ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
