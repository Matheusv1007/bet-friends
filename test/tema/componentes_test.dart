import 'dart:async';

import 'package:betfriends/tema/tema.dart';
import 'package:betfriends/widgets/componentes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget filho) => MaterialApp(
      theme: TemaApp.escuro,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: filho),
      ),
    );

void main() {
  group('CampoDeTexto', () {
    testWidgets('mostra o rótulo acima do campo e repassa texto e Keys', (tester) async {
      final controle = TextEditingController();
      addTearDown(controle.dispose);
      String? digitado;
      await tester.pumpWidget(_app(CampoDeTexto(
        key: const Key('campo_email'),
        rotulo: 'E-mail ou usuário',
        dica: 'voce@exemplo.com',
        ajuda: 'Use o e-mail do cadastro',
        controller: controle,
        onChanged: (v) => digitado = v,
      )));

      final rotulo = tester.getRect(find.text('E-mail ou usuário'));
      final campo = tester.getRect(find.byType(TextField));
      expect(rotulo.bottom, lessThanOrEqualTo(campo.top));
      expect(find.text('voce@exemplo.com'), findsOneWidget);
      expect(find.text('Use o e-mail do cadastro'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('campo_email')), 'ana');
      expect(controle.text, 'ana');
      expect(digitado, 'ana');
      final interno = find.descendant(
        of: find.byKey(const Key('campo_email')),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(interno).controller, same(controle));
    });

    testWidgets('mostra o erro inline em coral, com ícone, abaixo do campo', (tester) async {
      await tester.pumpWidget(_app(const CampoDeTexto(
        rotulo: 'Senha',
        senha: true,
        erro: 'E-mail, usuário ou senha incorretos.',
      )));

      final erro = find.text('E-mail, usuário ou senha incorretos.');
      expect(erro, findsOneWidget);
      expect(tester.widget<Text>(erro).style!.color, CoresApp.destrutivo);
      final icone = find.byIcon(Icons.error_outline);
      expect(icone, findsOneWidget);
      expect(tester.widget<Icon>(icone).color, CoresApp.destrutivo);
      expect(
        tester.getRect(erro).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(EditableText)).bottom),
      );
    });

    testWidgets('mostra o erro do validator do Form da mesma forma', (tester) async {
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(_app(Form(
        key: form,
        child: CampoDeTexto(
          rotulo: 'Nome',
          validator: (v) => (v ?? '').isEmpty ? 'Informe o nome.' : null,
        ),
      )));
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Informe o nome.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('alterna a visibilidade da senha', (tester) async {
      await tester.pumpWidget(_app(const CampoDeTexto(rotulo: 'Senha', senha: true)));
      bool oculta() => tester.widget<EditableText>(find.byType(EditableText)).obscureText;

      expect(oculta(), isTrue);
      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pump();
      expect(oculta(), isFalse);
      await tester.tap(find.byTooltip('Ocultar senha'));
      await tester.pump();
      expect(oculta(), isTrue);
    });

    testWidgets('enabled false bloqueia a edição', (tester) async {
      await tester.pumpWidget(_app(const CampoDeTexto(rotulo: 'Nome', enabled: false)));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  group('Botões', () {
    testWidgets('BotaoPrimario carregando mostra o indicador e não dispara onPressed',
        (tester) async {
      var toques = 0;
      await tester.pumpWidget(_app(BotaoPrimario(
        key: const Key('entrar'),
        rotulo: 'Entrar',
        carregando: true,
        onPressed: () => toques++,
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const Key('entrar')), warnIfMissed: false);
      await tester.tap(find.byKey(const Key('entrar')), warnIfMissed: false);
      expect(toques, 0);
    });

    testWidgets('BotaoPrimario com ação assíncrona não dispara onPressed duas vezes',
        (tester) async {
      var toques = 0;
      final conclusao = Completer<void>();
      await tester.pumpWidget(_app(BotaoPrimario(
        key: const Key('enviar'),
        rotulo: 'Enviar desafio',
        onPressed: () {
          toques++;
          return conclusao.future;
        },
      )));

      await tester.tap(find.byKey(const Key('enviar')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('enviar')), warnIfMissed: false);
      await tester.pump();
      expect(toques, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      conclusao.complete();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byKey(const Key('enviar')));
      expect(toques, 2);
    });

    testWidgets('as quatro variantes respeitam o alvo de toque e o tema', (tester) async {
      await tester.pumpWidget(_app(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BotaoPrimario(key: const Key('p'), rotulo: 'Primário', onPressed: () {}, larguraTotal: true),
          BotaoSecundario(key: const Key('s'), rotulo: 'Secundário', onPressed: () {}),
          BotaoDestrutivo(key: const Key('d'), rotulo: 'Excluir conta', onPressed: () {}),
          BotaoTexto(key: const Key('t'), rotulo: 'Ver todas', onPressed: () {}, pequeno: true),
          BotaoPrimario(
            key: const Key('pp'),
            rotulo: 'Novo desafio',
            icone: Icons.add,
            onPressed: () {},
            pequeno: true,
          ),
          const BotaoSecundario(key: Key('off'), rotulo: 'Desligado', onPressed: null),
        ],
      )));

      for (final k in ['p', 's', 'd', 't', 'pp', 'off']) {
        expect(tester.getSize(find.byKey(Key(k))).height, greaterThanOrEqualTo(48), reason: k);
      }
      expect(tester.getSize(find.byKey(const Key('p'))).width,
          tester.getSize(find.byType(Column)).width);
      expect(find.byIcon(Icons.add), findsOneWidget);

      final primario = tester.widget<FilledButton>(
        find.descendant(of: find.byKey(const Key('p')), matching: find.byType(FilledButton)),
      );
      expect(primario.onPressed, isNotNull);
      final desligado = tester.widget<OutlinedButton>(
        find.descendant(of: find.byKey(const Key('off')), matching: find.byType(OutlinedButton)),
      );
      expect(desligado.onPressed, isNull);

      Color corDoTexto(String rotulo) => DefaultTextStyle.of(tester.element(find.text(rotulo))).style.color!;
      expect(corDoTexto('Primário'), CoresApp.sobrePrimario);
      expect(corDoTexto('Secundário'), CoresApp.texto);
      expect(corDoTexto('Excluir conta'), CoresApp.destrutivo);
      expect(corDoTexto('Ver todas'), CoresApp.primario);
    });
  });

  group('TagDeStatus e AvisoInline', () {
    for (final tom in Tom.values) {
      testWidgets('TagDeStatus no tom ${tom.name}', (tester) async {
        await tester.pumpWidget(_app(TagDeStatus('Ao vivo 67\'', tom, key: const Key('tag'))));
        final texto = tester.widget<Text>(find.text('AO VIVO 67\''));
        expect(texto.style!.color, tom.cor);
        expect(texto.style!.fontSize, greaterThanOrEqualTo(12));
        final caixa = tester.widget<DecoratedBox>(
          find.descendant(of: find.byKey(const Key('tag')), matching: find.byType(DecoratedBox)),
        );
        final deco = caixa.decoration as BoxDecoration;
        expect(deco.color, tom.fundo);
        expect(deco.borderRadius, RaiosApp.bordaTag);
      });

      testWidgets('AvisoInline no tom ${tom.name}', (tester) async {
        var respondeu = false;
        await tester.pumpWidget(_app(AvisoInline(
          '2 desafios aguardando você',
          tom,
          key: const Key('aviso'),
          acao: BotaoTexto(rotulo: 'Responder', pequeno: true, onPressed: () => respondeu = true),
        )));
        expect(find.text('2 desafios aguardando você'), findsOneWidget);
        expect(tester.widget<Icon>(find.byIcon(tom.icone)).color, tom.cor);
        expect(tester.getSize(find.byKey(const Key('aviso'))).height, greaterThanOrEqualTo(48));
        await tester.tap(find.text('Responder'));
        expect(respondeu, isTrue);
      });
    }

    testWidgets('mostrarAviso abre um SnackBar flutuante com o ícone do tom', (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () => mostrarAviso(context, 'Desafio enviado.', tom: Tom.sucesso),
          child: const Text('abrir'),
        ),
      )));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Desafio enviado.'), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Tom.sucesso.icone)).color, CoresApp.primario);
      final barra = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(barra.behavior ?? TemaApp.escuro.snackBarTheme.behavior, SnackBarBehavior.floating);
    });
  });

  group('TituloDeSecao e LinhaDeLista', () {
    testWidgets('TituloDeSecao em caixa alta com ação', (tester) async {
      await tester.pumpWidget(_app(TituloDeSecao(
        'Partidas',
        key: const Key('secao'),
        acao: BotaoTexto(rotulo: 'Ver todas', pequeno: true, onPressed: () {}),
      )));
      final texto = tester.widget<Text>(find.text('PARTIDAS'));
      expect(texto.style!.fontSize, 12);
      expect(texto.style!.fontWeight, FontWeight.w600);
      expect(find.text('Ver todas'), findsOneWidget);
    });

    testWidgets('LinhaDeLista tem alvo ≥ 48, responde ao toque e mostra o divisor', (tester) async {
      var tocou = false;
      await tester.pumpWidget(_app(Column(children: [
        LinhaDeLista(
          key: const Key('linha'),
          titulo: 'Extrato de BetCoins',
          leading: const Icon(Icons.receipt_long_outlined),
          trailing: const Icon(Icons.chevron_right),
          divisor: true,
          onTap: () => tocou = true,
        ),
        const LinhaDeLista(titulo: 'Nome de exibição', subtitulo: 'Ana Lima'),
      ])));
      expect(tester.getSize(find.byKey(const Key('linha'))).height, greaterThanOrEqualTo(48));
      expect(find.byType(Divider), findsOneWidget);
      expect(find.text('Ana Lima'), findsOneWidget);
      await tester.tap(find.text('Extrato de BetCoins'));
      expect(tocou, isTrue);
    });
  });
}
