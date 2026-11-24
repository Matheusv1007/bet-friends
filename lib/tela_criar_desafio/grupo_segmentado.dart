import 'package:flutter/material.dart';

import '../tema/tema.dart';

/// Uma opção do [GrupoSegmentado].
class OpcaoSegmentada<T> {
  final T valor;
  final String rotulo;
  final Key chave;

  const OpcaoSegmentada(this.valor, this.rotulo, this.chave);
}

/// Grupo segmentado de Criar Desafio (palpite e valor): segmentos de mesma
/// largura e altura numa moldura de superfície 1; o escolhido fica em verde.
/// Em larguras pequenas ou texto ampliado, empilha as opções sem reduzir a fonte.
class GrupoSegmentado<T> extends StatelessWidget {
  final List<OpcaoSegmentada<T>> opcoes;
  final T selecionado;
  final ValueChanged<T> onChanged;

  /// Números tabulares e maiores (valores em BetCoins).
  final bool numerico;

  const GrupoSegmentado({
    super.key,
    required this.opcoes,
    required this.selecionado,
    required this.onChanged,
    this.numerico = false,
  });

  static const double _moldura = EspacosApp.e4;
  static const double _respiro = EspacosApp.e4;

  TextStyle _estilo(bool escolhido) {
    final cor = escolhido ? CoresApp.sobrePrimario : CoresApp.texto;
    return numerico
        ? TextoApp.tabular(TextoApp.corpoForte)
              .copyWith(fontSize: 17, color: cor)
        : TextoApp.corpo.copyWith(
            fontWeight: escolhido ? FontWeight.w600 : FontWeight.w500,
            color: cor,
            height: 1.2,
          );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CoresApp.superficie1,
        borderRadius: RaiosApp.bordaBotao,
        border: Border.all(color: CoresApp.filete),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_moldura),
        child: LayoutBuilder(
          builder: (context, restricoes) {
            final escala = MediaQuery.textScalerOf(context).scale(1);
            final empilhar =
                restricoes.maxWidth / escala < (numerico ? 240 : 440);
            if (empilhar) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final o in opcoes) _segmento(o, o.valor == selecionado),
                ],
              );
            }
            return Row(
              children: [
                for (final o in opcoes)
                  Expanded(child: _segmento(o, o.valor == selecionado)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _segmento(OpcaoSegmentada<T> opcao, bool escolhido) {
    return Material(
      color: escolhido ? CoresApp.primario : Colors.transparent,
      borderRadius: RaiosApp.bordaChip,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        selected: escolhido,
        button: true,
        inMutuallyExclusiveGroup: true,
        child: InkWell(
          key: opcao.chave,
          onTap: () => onChanged(opcao.valor),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: _respiro,
              vertical: EspacosApp.e8,
            ),
            child: Text(
              opcao.rotulo,
              textAlign: TextAlign.center,
              style: _estilo(escolhido),
            ),
          ),
        ),
      ),
    );
  }
}
