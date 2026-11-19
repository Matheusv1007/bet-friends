import 'package:betfriends/tela_criar_desafio/seletor_valor_desafio.dart';
import 'package:betfriends/widgets_home_page/appbar_das_partidas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('N-23: ações expõem semântica e alvos de pelo menos 48dp', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      SeletorValorDesafio(valor: 50, onChanged: (_) {}),
      Appbardaspartidas(onVerTodasPressed: () {}),
    ]))));
    final chip = find.byKey(const Key('chip_valor_100'));
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(chip).width, greaterThanOrEqualTo(48));
    expect(tester.getSemantics(chip), matchesSemantics(
      label: '100', hasTapAction: true, hasFocusAction: true, isFocusable: true,
    ));
    final botao = find.widgetWithText(TextButton, 'Ver todas');
    expect(tester.getSize(botao).height, greaterThanOrEqualTo(48));
    expect(tester.getSemantics(botao).flagsCollection.isButton, isTrue);
    semantics.dispose();
  });
}
