import 'package:betfriends/models/carteira.dart';
import 'package:flutter_test/flutter_test.dart';

// Valores de teste, sem relação com saldos reais
void main() {
  final formatoInvalido = throwsA(isA<FormatException>());

  test('carteira sem reservas: disponível igual ao total', () {
    final carteira = Carteira.fromMap({'saldoTotal': 1000, 'saldoReservado': 0});
    expect(carteira.saldoDisponivel, 1000);
  });

  test('carteira com reservas: disponível é total menos reservado', () {
    expect(Carteira(saldoTotal: 1000, saldoReservado: 350).saldoDisponivel, 650);
    expect(Carteira(saldoTotal: 1000, saldoReservado: 1000).saldoDisponivel, 0);
    expect(Carteira(saldoTotal: 0, saldoReservado: 0).saldoDisponivel, 0);
  });

  test('saldos negativos ou reservado acima do total são recusados', () {
    expect(() => Carteira(saldoTotal: -1, saldoReservado: 0), formatoInvalido);
    expect(() => Carteira(saldoTotal: 100, saldoReservado: -1), formatoInvalido);
    expect(() => Carteira(saldoTotal: 100, saldoReservado: 101), formatoInvalido);
  });

  test('lê o documento do schema e ignora os demais campos', () {
    final carteira = Carteira.fromMap({
      'displayName': 'X',
      'saldoTotal': 1000,
      'saldoReservado': 100,
      'lastRecoveryBonusAt': null,
    });
    expect(carteira, Carteira(saldoTotal: 1000, saldoReservado: 100));
    expect(carteira.saldoDisponivel, 900);
  });

  test('campos ausentes, não inteiros ou inconsistentes são recusados', () {
    for (final dados in <Map<String, dynamic>>[
      {},
      {'saldoTotal': 1000},
      {'saldoTotal': '1000', 'saldoReservado': 0},
      {'saldoTotal': 1000.0, 'saldoReservado': 0},
      {'saldoTotal': 1000, 'saldoReservado': null},
      {'saldoTotal': 10, 'saldoReservado': 20},
    ]) {
      expect(() => Carteira.fromMap(dados), formatoInvalido, reason: '$dados');
    }
  });
}
