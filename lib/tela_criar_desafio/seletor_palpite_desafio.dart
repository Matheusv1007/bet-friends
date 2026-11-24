import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import 'grupo_segmentado.dart';

/// Palpite do criador como grupo segmentado: mandante, empate e visitante,
/// com o nome dos times da partida escolhida.
class SeletorPalpiteDesafio extends StatelessWidget {
  final Palpite palpiteSelecionado;
  final String labelMandante;
  final String labelVisitante;
  final ValueChanged<Palpite> onChanged;

  const SeletorPalpiteDesafio({
    super.key,
    required this.palpiteSelecionado,
    required this.labelMandante,
    required this.labelVisitante,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GrupoSegmentado<Palpite>(
      selecionado: palpiteSelecionado,
      onChanged: onChanged,
      opcoes: [
        OpcaoSegmentada(Palpite.homeWin, labelMandante, const Key('palpite_home_win')),
        const OpcaoSegmentada(Palpite.draw, 'Empate', Key('palpite_draw')),
        OpcaoSegmentada(Palpite.awayWin, labelVisitante, const Key('palpite_away_win')),
      ],
    );
  }
}
