import 'package:flutter/material.dart';

class SaldoDesafio extends StatelessWidget {
  final int? saldoDisponivel;

  const SaldoDesafio({super.key, required this.saldoDisponivel});

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2624),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryGreen.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 20,
              color: primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SALDO DISPONÍVEL',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                saldoDisponivel != null
                    ? '$saldoDisponivel BetCoins'
                    : 'Carregando...',
                key: const Key('criar_desafio_saldo'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
