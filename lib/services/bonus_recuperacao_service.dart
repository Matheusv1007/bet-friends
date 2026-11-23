import '../models/carteira.dart';
import 'functions/functions_service.dart';

/// Recuperação confirmada exclusivamente pela callable (RN-OFF-002/003).
class BonusRecuperacaoService {
  FunctionsService? _functions;

  BonusRecuperacaoService({FunctionsService? functionsService})
      : _functions = functionsService;

  Future<BonusRecuperacao> resgatar() async {
    try {
      final resposta = await (_functions ??= FunctionsService())
          .call(CallableNames.claimRecoveryBonus);
      return BonusRecuperacao.fromMap(resposta);
    } on FunctionsException catch (e) {
      throw BonusRecuperacaoException.fromFunctions(e);
    } on FormatException {
      throw const BonusRecuperacaoException(
        'resposta-invalida',
        'Não foi possível confirmar o bônus. Atualize a carteira antes de tentar novamente.',
      );
    }
  }
}

class BonusRecuperacao {
  final String transacaoId;
  final int amount;
  final Carteira carteira;
  final DateTime concedidoEm;
  final DateTime proximaRecuperacaoEm;

  const BonusRecuperacao({
    required this.transacaoId,
    required this.amount,
    required this.carteira,
    required this.concedidoEm,
    required this.proximaRecuperacaoEm,
  });

  factory BonusRecuperacao.fromMap(Map<String, dynamic> mapa) {
    final id = mapa['transacaoId'];
    final concedido = mapa['concedidoEm'];
    final proxima = mapa['proximaRecuperacaoEm'];
    if (id is! String || id.isEmpty || mapa['amount'] != 100 ||
        concedido is! String || proxima is! String) {
      throw const FormatException('Resposta de recuperação inválida.');
    }
    final carteira = Carteira.fromMap(mapa);
    if (mapa['saldoDisponivel'] != carteira.saldoDisponivel) {
      throw const FormatException('Saldo de recuperação inconsistente.');
    }
    return BonusRecuperacao(
      transacaoId: id,
      amount: 100,
      carteira: carteira,
      concedidoEm: DateTime.parse(concedido).toUtc(),
      proximaRecuperacaoEm: DateTime.parse(proxima).toUtc(),
    );
  }
}

class BonusRecuperacaoException implements Exception {
  final String motivo;
  final String message;
  final bool semConfirmacaoDoServidor;

  const BonusRecuperacaoException(this.motivo, this.message,
      {this.semConfirmacaoDoServidor = false});

  factory BonusRecuperacaoException.fromFunctions(FunctionsException erro) {
    if (erro.semConfirmacaoDoServidor) {
      return const BonusRecuperacaoException(
        'sem-confirmacao',
        'Sem confirmação do servidor. Verifique sua conexão e a carteira antes de tentar novamente.',
        semConfirmacaoDoServidor: true,
      );
    }
    if (erro.code == 'failed-precondition') {
      final mensagem = switch (erro.motivo) {
        'saldo-reservado' => 'Você tem BetCoins reservadas em desafios abertos.',
        'saldo-suficiente' => 'O bônus só está disponível com menos de 10 BetCoins livres.',
        'intervalo-nao-cumprido' => 'Aguarde 24 horas desde o último bônus para resgatar novamente.',
        'perfil-inexistente' => 'Seu perfil e sua carteira ainda não foram criados.',
        _ => null,
      };
      if (mensagem != null) {
        return BonusRecuperacaoException(erro.motivo!, mensagem);
      }
    }
    if (erro.isUnauthenticated) {
      return const BonusRecuperacaoException(
        'nao-autenticado', 'Entre na sua conta para resgatar o bônus.',
      );
    }
    return const BonusRecuperacaoException(
      'desconhecido', 'Não foi possível resgatar o bônus agora. Tente novamente mais tarde.',
    );
  }
}
