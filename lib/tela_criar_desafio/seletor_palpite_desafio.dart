import 'package:flutter/material.dart';

import '../models/challenge_model.dart';

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
    return Row(
      children: [
        BotaoPalpiteDesafio(
          palpite: Palpite.homeWin,
          selecionado: palpiteSelecionado,
          onChanged: onChanged,
          label: labelMandante,
          chave: const Key('palpite_home_win'),
        ),
        const SizedBox(width: 8),
        BotaoPalpiteDesafio(
          palpite: Palpite.draw,
          selecionado: palpiteSelecionado,
          onChanged: onChanged,
          label: 'Empate',
          chave: const Key('palpite_draw'),
        ),
        const SizedBox(width: 8),
        BotaoPalpiteDesafio(
          palpite: Palpite.awayWin,
          selecionado: palpiteSelecionado,
          onChanged: onChanged,
          label: labelVisitante,
          chave: const Key('palpite_away_win'),
        ),
      ],
    );
  }
}

class BotaoPalpiteDesafio extends StatelessWidget {
  final Palpite palpite;
  final Palpite selecionado;
  final String label;
  final Key chave;
  final ValueChanged<Palpite> onChanged;

  const BotaoPalpiteDesafio({
    super.key,
    required this.palpite,
    required this.selecionado,
    required this.label,
    required this.chave,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selecionado == palpite;
    const primaryGreen = Color(0xFF00D084);
    const cardBg = Color(0xFF151E2E);

    return Expanded(
      child: InkWell(
        key: chave,
        onTap: () => onChanged(palpite),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: sel ? primaryGreen : cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? primaryGreen : Colors.white.withValues(alpha: 0.08),
              width: sel ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: sel ? const Color(0xFF062319) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
