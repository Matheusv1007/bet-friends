import 'package:flutter/material.dart';

class SeletorValorDesafio extends StatelessWidget {
  final int valor;
  final ValueChanged<int> onChanged;

  const SeletorValorDesafio({
    super.key,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VALOR DO DESAFIO (BetCoins)',
          style: TextStyle(
            color: textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BetCoins apostadas',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$valor BetCoins',
                key: const Key('valor_selecionado_label'),
                style: const TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [10, 25, 50, 100].map((v) {
            final sel = valor == v;
            return Expanded(
              child: InkWell(
                key: Key('chip_valor_$v'),
                onTap: () => onChanged(v),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? primaryGreen : cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel
                          ? primaryGreen
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$v',
                    style: TextStyle(
                      color: sel ? const Color(0xFF062319) : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
