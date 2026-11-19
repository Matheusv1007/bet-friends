import 'package:flutter/material.dart';

import '../models/carteira.dart';

/// Card para visualização clara e consistente dos saldos de BetCoins (RF-003, RN-BET-004, RNF-007).
///
/// Apresenta:
/// - Saldo Total
/// - Saldo Reservado
/// - Saldo Disponível (calculado estritamente como saldoTotal - saldoReservado)
///
/// Diretrizes de Segurança e Domínio:
/// - Interface 100% somente leitura: não permite alteração direta de saldos pelo cliente.
/// - Invariantes respeitadas: saldoDisponivel >= 0, nenhum saldo negativo.
class Carddecarteira extends StatelessWidget {
  final Carteira carteira;
  final bool semConexao;

  const Carddecarteira({
    super.key,
    required this.carteira,
    this.semConexao = false,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const amberReserved = Color(0xFFF59E0B);
    const textMuted = Color(0xFF8E9CAB);

    return Container(
      key: const Key('card_carteira_container'),
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do Card
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2624),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primaryGreen.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARTEIRA BETCOINS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Regras oficiais do plano BetFriends',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (semConexao)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2012),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: amberReserved.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'OFFLINE',
                    style: TextStyle(
                      color: amberReserved,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // 1. Destaque: Saldo Disponível (livre para apostar / desafiar)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2422),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primaryGreen.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALDO DISPONÍVEL',
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Livre para novos desafios',
                      style: TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${carteira.saldoDisponivel} BetCoins',
                  key: const Key('carteira_saldo_disponivel'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. Linhas de Saldo Total e Saldo Reservado
          Row(
            children: [
              // Saldo Reservado
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RESERVADO',
                        style: TextStyle(
                          color: amberReserved,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${carteira.saldoReservado} BetCoins',
                        key: const Key('carteira_saldo_reservado'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Em desafios',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Saldo Total
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${carteira.saldoTotal} BetCoins',
                        key: const Key('carteira_saldo_total'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Total da conta',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. Fórmula de consistência e regra de negócio (RN-BET-004, RNF-007)
          Container(
            key: const Key('carteira_consistencia'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 13,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Disponível (${carteira.saldoDisponivel}) = Total (${carteira.saldoTotal}) − Reservado (${carteira.saldoReservado})',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
