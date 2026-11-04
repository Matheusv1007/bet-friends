import 'package:betfriends/models/carteira.dart';
import 'package:betfriends/widgets_homePage/cardDeCarteira.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget montarWidget(Carteira carteira, {bool semConexao = false}) {
    return MaterialApp(
      home: Scaffold(
        body: Carddecarteira(
          carteira: carteira,
          semConexao: semConexao,
        ),
      ),
    );
  }

  group('Visualizar saldo de BetCoins - Carddecarteira (RF-003, RN-BET-004, RNF-007)', () {
    testWidgets('cenário 1: carteira recém-criada exibe saldo total, reservado zerado e disponível integral', (tester) async {
      // Carteira inicial padrão de novo cadastro (1000 BetCoins de bônus de boas-vindas, 0 reservado)
      final carteira = Carteira(saldoTotal: 1000, saldoReservado: 0);

      await tester.pumpWidget(montarWidget(carteira));

      // Saldo Disponível (saldoDisponivel = saldoTotal - saldoReservado = 1000)
      expect(find.byKey(const Key('carteira_saldo_disponivel')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('carteira_saldo_disponivel'))).data, '1000 BetCoins');

      // Saldo Reservado
      expect(find.byKey(const Key('carteira_saldo_reservado')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('carteira_saldo_reservado'))).data, '0 BetCoins');

      // Saldo Total
      expect(find.byKey(const Key('carteira_saldo_total')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('carteira_saldo_total'))).data, '1000 BetCoins');

      // Fórmula de consistência exibida
      expect(find.byKey(const Key('carteira_consistencia')), findsOneWidget);
      expect(
        tester.widget<Text>(find.descendant(
          of: find.byKey(const Key('carteira_consistencia')),
          matching: find.byType(Text),
        )).data,
        'Disponível (1000) = Total (1000) − Reservado (0)',
      );
    });

    testWidgets('cenário 2: usuário com saldo reservado em desafios ativos', (tester) async {
      // Total 1000, com 250 reservados em desafios pendentes
      final carteira = Carteira(saldoTotal: 1000, saldoReservado: 250);

      await tester.pumpWidget(montarWidget(carteira));

      // Disponível = 1000 - 250 = 750
      expect(carteira.saldoDisponivel, 750);
      expect(tester.widget<Text>(find.byKey(const Key('carteira_saldo_disponivel'))).data, '750 BetCoins');
      expect(tester.widget<Text>(find.byKey(const Key('carteira_saldo_reservado'))).data, '250 BetCoins');
      expect(tester.widget<Text>(find.byKey(const Key('carteira_saldo_total'))).data, '1000 BetCoins');

      expect(
        tester.widget<Text>(find.descendant(
          of: find.byKey(const Key('carteira_consistencia')),
          matching: find.byType(Text),
        )).data,
        'Disponível (750) = Total (1000) − Reservado (250)',
      );
    });

    testWidgets('cenário 3: usuário sem reservas (desafios todos liquidados)', (tester) async {
      // Saldo total de 500 sem reservas ativas
      final carteira = Carteira(saldoTotal: 500, saldoReservado: 0);

      await tester.pumpWidget(montarWidget(carteira));

      expect(carteira.saldoDisponivel, 500);
      expect(tester.widget<Text>(find.byKey(const Key('carteira_saldo_disponivel'))).data, '500 BetCoins');
      expect(tester.widget<Text>(find.byKey(const Key('carteira_saldo_reservado'))).data, '0 BetCoins');
      expect(tester.widget<Text>(find.byKey(const Key('carteira_saldo_total'))).data, '500 BetCoins');

      expect(
        tester.widget<Text>(find.descendant(
          of: find.byKey(const Key('carteira_consistencia')),
          matching: find.byType(Text),
        )).data,
        'Disponível (500) = Total (500) − Reservado (0)',
      );
    });

    testWidgets('cenário 4: validar consistência matemática e integridade entre os três saldos', (tester) async {
      final casos = [
        Carteira(saldoTotal: 0, saldoReservado: 0),
        Carteira(saldoTotal: 100, saldoReservado: 100),
        Carteira(saldoTotal: 3000, saldoReservado: 1200),
      ];

      for (final carteira in casos) {
        await tester.pumpWidget(montarWidget(carteira));

        expect(carteira.saldoDisponivel, carteira.saldoTotal - carteira.saldoReservado);
        expect(carteira.saldoDisponivel, greaterThanOrEqualTo(0));
        expect(carteira.saldoTotal, greaterThanOrEqualTo(0));
        expect(carteira.saldoReservado, greaterThanOrEqualTo(0));

        expect(
          tester.widget<Text>(find.byKey(const Key('carteira_saldo_disponivel'))).data,
          '${carteira.saldoDisponivel} BetCoins',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('carteira_saldo_reservado'))).data,
          '${carteira.saldoReservado} BetCoins',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('carteira_saldo_total'))).data,
          '${carteira.saldoTotal} BetCoins',
        );
      }
    });

    testWidgets('critério de segurança: interface não permite alteração direta de saldos (somente leitura)', (tester) async {
      final carteira = Carteira(saldoTotal: 1000, saldoReservado: 200);

      await tester.pumpWidget(montarWidget(carteira));

      // Garante ausência total de campos de entrada ou formulários de alteração
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(EditableText), findsNothing);

      // Garante ausência de botões para alterar saldo
      expect(find.textContaining('Editar'), findsNothing);
      expect(find.textContaining('Alterar'), findsNothing);
      expect(find.textContaining('Depositar'), findsNothing);
      expect(find.textContaining('Sacar'), findsNothing);
    });

    testWidgets('indicador de offline: exibido apenas quando semConexao for verdadeiro', (tester) async {
      final carteira = Carteira(saldoTotal: 1000, saldoReservado: 0);

      // Modo online
      await tester.pumpWidget(montarWidget(carteira, semConexao: false));
      expect(find.text('OFFLINE'), findsNothing);

      // Modo offline (dados em cache)
      await tester.pumpWidget(montarWidget(carteira, semConexao: true));
      expect(find.text('OFFLINE'), findsOneWidget);
    });
  });
}
