/// Saldos de BetCoins lidos de `users/{uid}` (docs/firestore-schema.md §3.1;
/// Plano §8.1). Somente leitura: o app nunca grava saldos (RN-SEC-001); quem
/// altera é o backend (functions/src/betcoins/saldos.ts, KAN-73).
///
/// [saldoDisponivel] é calculado e não existe no documento.
class Carteira {
  final int saldoTotal;
  final int saldoReservado;

  /// Lança [FormatException] se os valores violarem as invariantes:
  /// total ≥ 0, reservado ≥ 0 e reservado ≤ total.
  Carteira({required this.saldoTotal, required this.saldoReservado}) {
    if (saldoTotal < 0 || saldoReservado < 0) {
      throw const FormatException('Saldos não podem ser negativos.');
    }
    if (saldoReservado > saldoTotal) {
      throw const FormatException('Saldo reservado maior que o saldo total.');
    }
  }

  int get saldoDisponivel => saldoTotal - saldoReservado;

  /// Converte os campos de `users/{uid}`. Campos ausentes, de outro tipo ou
  /// inconsistentes resultam em [FormatException]: o valor nunca é corrigido.
  factory Carteira.fromMap(Map<String, dynamic> data) {
    return Carteira(
      saldoTotal: _inteiro(data, 'saldoTotal'),
      saldoReservado: _inteiro(data, 'saldoReservado'),
    );
  }

  static int _inteiro(Map<String, dynamic> data, String campo) {
    final valor = data[campo];
    if (valor is! int) {
      throw FormatException('Campo "$campo" ausente ou não inteiro na carteira.');
    }
    return valor;
  }

  @override
  bool operator ==(Object other) =>
      other is Carteira &&
      other.saldoTotal == saldoTotal &&
      other.saldoReservado == saldoReservado;

  @override
  int get hashCode => Object.hash(saldoTotal, saldoReservado);
}
