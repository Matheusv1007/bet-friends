import 'package:flutter/material.dart';

import '../tema/tema.dart';
import '../widgets/texto_sem_corte.dart';

/// Uma opção do [GrupoSegmentado].
class OpcaoSegmentada<T> {
  final T valor;
  final String rotulo;
  final Key chave;

  const OpcaoSegmentada(this.valor, this.rotulo, this.chave);
}

/// Grupo segmentado de Criar Desafio (palpite e valor): segmentos de mesma
/// largura e altura numa moldura de superfície 1; o escolhido fica em verde.
/// Rótulos em até 2 linhas, sem quebrar palavra.
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
        ? TextoApp.tabular(TextoApp.corpoForte).copyWith(fontSize: 17, color: cor)
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
            final largura = restricoes.maxWidth / opcoes.length - 2 * _respiro;
            // Tamanho medido aqui, fora do Row: o IntrinsicHeight, que iguala
            // a altura dos segmentos, não atravessa um LayoutBuilder.
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final o in opcoes)
                    Expanded(
                      child: _segmento(
                        o,
                        o.valor == selecionado,
                        TextoSemCorte.tamanhoQueCabe(
                          context,
                          o.rotulo,
                          _estilo(o.valor == selecionado),
                          largura,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _segmento(OpcaoSegmentada<T> opcao, bool escolhido, double tamanho) {
    return Material(
      color: escolhido ? CoresApp.primario : Colors.transparent,
      borderRadius: RaiosApp.bordaChip,
      clipBehavior: Clip.antiAlias,
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
            textScaler: TextScaler.noScaling,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _estilo(escolhido).copyWith(fontSize: tamanho),
          ),
        ),
      ),
    );
  }
}
