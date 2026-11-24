import 'package:betfriends/tela_criar_desafio/seletor_valor_desafio.dart';
import 'package:betfriends/widgets_home_page/appbar_das_partidas.dart';
import 'package:betfriends/widgets/componentes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'rótulo externo também identifica o campo para o leitor de tela',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CampoDeTexto(
                rotulo: 'E-mail ou usuário',
                dica: 'Seu identificador',
              ),
            ),
          ),
        );
        final campo = tester.getSemantics(find.byType(TextField));
        expect(campo.label, contains('E-mail ou usuário'));
        expect(campo.flagsCollection.isTextField, isTrue);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('N-23: ações expõem semântica e alvos de pelo menos 48dp', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SeletorValorDesafio(valor: 50, onChanged: (_) {}),
              Appbardaspartidas(onVerTodasPressed: () {}),
            ],
          ),
        ),
      ),
    );
    final chip = find.byKey(const Key('chip_valor_100'));
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(chip).width, greaterThanOrEqualTo(48));
    expect(tester.getSemantics(chip).label, '100');
    expect(tester.getSemantics(chip).flagsCollection.isButton, isTrue);
    expect(
      tester.getSemantics(chip).flagsCollection.isInMutuallyExclusiveGroup,
      isTrue,
    );
    final botao = find.widgetWithText(TextButton, 'Ver todas');
    expect(tester.getSize(botao).height, greaterThanOrEqualTo(48));
    expect(tester.getSemantics(botao).flagsCollection.isButton, isTrue);
    semantics.dispose();
  });
}
