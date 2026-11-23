import 'package:cloud_firestore/cloud_firestore.dart';

/// O sinal representa o efeito no total, não a variação do reservado.
enum TipoDoLancamento {
  saldoInicial('INITIAL_BALANCE', 'Saldo inicial', 1),
  reserva('RESERVE', 'Reserva para desafio', 0),
  liberacao('RELEASE', 'Liberação de reserva', 0),
  premio('WIN', 'Prêmio por vitória', 1),
  perda('LOSS', 'Perda no desafio', -1),
  reembolso('REFUND', 'Reembolso por empate', 0),
  bonus('RECOVERY_BONUS', 'Bônus de recuperação', 1),
  reposicao('DEV_TOP_UP', 'Reposição de desenvolvimento', 1);

  final String valor;
  final String rotulo;
  final int sinal;
  const TipoDoLancamento(this.valor, this.rotulo, this.sinal);

  String get explicacao => switch (this) {
    reserva => 'Reservado; saldo total não alterado.',
    liberacao || reembolso => 'Reserva devolvida ao disponível; saldo total não alterado.',
    _ => '',
  };
}

class LancamentoDoExtrato {
  final String id;
  final String userId;
  final TipoDoLancamento tipo;
  final int amount;
  final int saldoTotalDepois;
  final String? challengeId;
  final DateTime createdAt;

  const LancamentoDoExtrato({
    required this.id,
    required this.userId,
    required this.tipo,
    required this.amount,
    required this.saldoTotalDepois,
    required this.challengeId,
    required this.createdAt,
  });

  String get valorFormatado => '${switch (tipo.sinal) { 1 => '+', -1 => '−', _ => '' }}$amount BC';

  factory LancamentoDoExtrato.fromMap(String id, Map<String, dynamic> dados) {
    final tipos = TipoDoLancamento.values.where((t) => t.valor == dados['type']);
    final usuario = dados['userId'];
    final valor = dados['amount'];
    final depois = dados['balanceAfter'];
    final data = dados['createdAt'];
    final desafio = dados['challengeId'];
    if (tipos.isEmpty || usuario is! String || usuario.isEmpty ||
        valor is! int || valor <= 0 || depois is! Map ||
        depois['saldoTotal'] is! int || (depois['saldoTotal'] as int) < 0 ||
        data is! Timestamp || (desafio != null && (desafio is! String || desafio.isEmpty))) {
      throw const FormatException('Lançamento inválido no extrato.');
    }
    return LancamentoDoExtrato(
      id: id, userId: usuario, tipo: tipos.single, amount: valor,
      saldoTotalDepois: depois['saldoTotal'] as int,
      challengeId: desafio as String?, createdAt: data.toDate(),
    );
  }
}
