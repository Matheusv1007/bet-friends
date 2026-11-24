import 'package:betfriends/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('o MaterialApp usa a transição de página configurada no tema', (tester) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.escuro,
        home: Builder(
          builder: (c) {
            contexto = c;
            return const Scaffold(body: Text('Origem'));
          },
        ),
      ),
    );

    final builders = Theme.of(contexto).pageTransitionsTheme.builders;
    expect(builders[TargetPlatform.android], isA<FadeForwardsPageTransitionsBuilder>());
  });

  testWidgets('abrir uma tela anima a transição e termina na tela nova', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.escuro,
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(c).push(
                MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Destino'))),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(find.text('Destino'), findsOneWidget);
  });
}
