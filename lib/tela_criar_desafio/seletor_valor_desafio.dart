import 'package:flutter/material.dart';

import '../tema/tema.dart';
import 'grupo_segmentado.dart';

/// Valor do desafio (10, 25, 50 ou 100 BetCoins) e o resumo "Você aposta ·
/// Prêmio se acertar". O prêmio é o ganho líquido: igual ao valor apostado,
/// porque não há taxa.
class SeletorValorDesafio extends StatelessWidget {
  final int valor;
  final ValueChanged<int> onChanged;

  const SeletorValorDesafio({
    super.key,
    required this.valor,
    required this.onChanged,
  });

  /// Valores oferecidos, em BetCoins.
  static const valores = [10, 25, 50, 100];

  @override
  Widget build(BuildContext context) {
    final destaque = TextoApp.tabular(TextoApp.secundario).copyWith(
      fontWeight: FontWeight.w700,
      color: CoresApp.texto,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GrupoSegmentado<int>(
          numerico: true,
          selecionado: valor,
          onChanged: onChanged,
          opcoes: [
            for (final v in valores) OpcaoSegmentada(v, '$v', Key('chip_valor_$v')),
          ],
        ),
        const SizedBox(height: EspacosApp.e12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: EspacosApp.e12,
          runSpacing: EspacosApp.e4,
          children: [
            Text.rich(
              key: const Key('valor_selecionado_label'),
              TextSpan(
                text: 'Você aposta ',
                children: [TextSpan(text: '$valor', style: destaque)],
              ),
              style: TextoApp.secundario,
            ),
            Text.rich(
              key: const Key('valor_premio_label'),
              TextSpan(
                text: 'Prêmio se acertar ',
                children: [
                  TextSpan(
                    text: '+$valor',
                    style: destaque.copyWith(color: CoresApp.primario),
                  ),
                ],
              ),
              style: TextoApp.secundario,
            ),
          ],
        ),
      ],
    );
  }
}
