import 'dart:async';

import 'package:betfriends/app.dart';
import 'package:betfriends/telas_autenticacao/cadastro_page.dart';
import 'package:betfriends/telas_autenticacao/login_page.dart';
import 'package:betfriends/tema/tema.dart';
import 'package:betfriends/widgets/componentes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

/// `signIn` que só termina quando o teste manda.
class _AuthLento extends FakeAuthService {
  final liberar = Completer<void>();

  @override
  Future<UserCredential> signIn({required String identifier, required String password}) async {
    signInCalls++;
    await liberar.future;
    throw FirebaseAuthException(code: 'invalid-credential');
  }
}

final _identificador = find.byKey(const Key('login_identificador'));
final _senha = find.byKey(const Key('login_senha'));
final _entrar = find.byKey(const Key('login_entrar'));

/// Texto de erro inline de um campo (o coral ao lado do ícone de erro).
String? _erroDe(WidgetTester tester, Finder campo) {
  final erro = find.descendant(
    of: campo,
    matching: find.byWidgetPredicate((w) => w is Text && w.style?.color == CoresApp.destrutivo),
  );
  return erro.evaluate().isEmpty ? null : tester.widget<Text>(erro).data;
}

Future<void> _avancar(WidgetTester tester, [int quadros = 5]) async {
  for (var i = 0; i < quadros; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _abrir(WidgetTester tester, FakeAuthService auth) async {
  await tester.pumpWidget(App(authService: auth, partidasService: CountingPartidasService()));
  await _avancar(tester);
  expect(find.byType(LoginPage), findsOneWidget);
}

Future<void> _entrarCom(WidgetTester tester, String identificador, String senha) async {
  await tester.enterText(_identificador, identificador);
  await tester.enterText(_senha, senha);
  await tester.ensureVisible(_entrar);
  await tester.tap(_entrar);
  await _avancar(tester);
}

void main() {
  late FakeAuthService auth;

  setUp(() => auth = FakeAuthService());

  testWidgets('mostra a logo, o subtítulo, os campos com rótulo e o botão "Entrar"', (tester) async {
    await _abrir(tester, auth);

    expect(find.byType(LogoBetFriends), findsOneWidget);
    expect(find.text('Aposte e desafie seus amigos'), findsOneWidget);
    expect(find.text('E-mail ou usuário'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    expect(find.text('Não tem uma conta?'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
  });

  testWidgets('alterna a visibilidade da senha', (tester) async {
    await _abrir(tester, auth);

    TextField campo() => tester.widget<TextField>(find.descendant(of: _senha, matching: find.byType(TextField)));
    expect(campo().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(campo().obscureText, isFalse);
  });

  for (final code in ['invalid-credential', 'wrong-password', 'user-not-found']) {
    testWidgets('$code: erro sob a senha, sem aviso, e some ao editar', (tester) async {
      auth.signInError = FirebaseAuthException(code: code);
      await _abrir(tester, auth);
      await _entrarCom(tester, 'ana@example.com', 'errada');

      expect(_erroDe(tester, _senha), 'E-mail, usuário ou senha incorretos.');
      expect(_erroDe(tester, _identificador), isNull);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.enterText(_senha, 'errada2');
      await _avancar(tester);
      expect(_erroDe(tester, _senha), isNull);
    });
  }

  testWidgets('editar o e-mail também limpa o erro de credencial', (tester) async {
    auth.signInError = FirebaseAuthException(code: 'invalid-credential');
    await _abrir(tester, auth);
    await _entrarCom(tester, 'ana@example.com', 'errada');
    expect(_erroDe(tester, _senha), isNotNull);

    await tester.enterText(_identificador, 'ana@example.com.br');
    await _avancar(tester);
    expect(_erroDe(tester, _senha), isNull);
  });

  testWidgets('invalid-email: erro sob o primeiro campo', (tester) async {
    auth.signInError = FirebaseAuthException(code: 'invalid-email');
    await _abrir(tester, auth);
    await _entrarCom(tester, 'ana@', 'senha123');

    expect(_erroDe(tester, _identificador), 'E-mail inválido.');
    expect(_erroDe(tester, _senha), isNull);
  });

  testWidgets('campos vazios marcam cada campo e não chamam o Auth', (tester) async {
    await _abrir(tester, auth);
    await tester.tap(_entrar);
    await _avancar(tester);

    expect(_erroDe(tester, _identificador), 'Informe seu e-mail ou usuário.');
    expect(_erroDe(tester, _senha), 'Informe sua senha.');
    expect(auth.signInCalls, 0);

    await tester.enterText(_identificador, 'ana');
    await tester.tap(_entrar);
    await _avancar(tester);
    expect(_erroDe(tester, _identificador), isNull);
    expect(_erroDe(tester, _senha), 'Informe sua senha.');
  });

  for (final (code, mensagem) in [
    ('user-disabled', 'Esta conta foi desativada.'),
    ('too-many-requests', 'Muitas tentativas. Tente novamente mais tarde.'),
    ('network-request-failed', 'Erro de conexão. Verifique sua internet.'),
    ('operation-not-allowed', 'Não foi possível entrar. Tente novamente.'),
  ]) {
    testWidgets('$code vira aviso, sem erro nos campos', (tester) async {
      auth.signInError = FirebaseAuthException(code: code);
      await _abrir(tester, auth);
      await _entrarCom(tester, 'ana@example.com', 'senha123');

      expect(find.descendant(of: find.byType(SnackBar), matching: find.text(mensagem)), findsOneWidget);
      expect(_erroDe(tester, _senha), isNull);
      expect(_erroDe(tester, _identificador), isNull);
    });
  }

  testWidgets('erro inesperado vira aviso', (tester) async {
    auth.signInError = StateError('falha simulada');
    await _abrir(tester, auth);
    await _entrarCom(tester, 'ana@example.com', 'senha123');

    expect(find.text('Ocorreu um erro inesperado. Tente novamente.'), findsOneWidget);
  });

  testWidgets('durante o envio mostra o indicador e ignora toques repetidos', (tester) async {
    final lento = _AuthLento();
    await _abrir(tester, lento);
    await tester.enterText(_identificador, 'ana@example.com');
    await tester.enterText(_senha, 'senha123');
    await tester.tap(_entrar);
    await tester.pump();

    expect(find.descendant(of: _entrar, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    await tester.tap(_entrar, warnIfMissed: false);
    await tester.pump();
    expect(lento.signInCalls, 1);

    lento.liberar.complete();
    await _avancar(tester);
    expect(find.descendant(of: _entrar, matching: find.byType(CircularProgressIndicator)), findsNothing);
    expect(_erroDe(tester, _senha), 'E-mail, usuário ou senha incorretos.');
  });

  for (final tamanho in [const Size(320, 568), const Size(360, 800)]) {
    for (final escala in [1.0, 1.5, 2.0]) {
      testWidgets(
        'sem estouro em ${tamanho.width.toInt()} dp com fonte ${escala}x; "Criar conta" alcançável e abre o Cadastro',
        (tester) async {
          tester.view.physicalSize = tamanho * tester.view.devicePixelRatio;
          tester.platformDispatcher.textScaleFactorTestValue = escala;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          auth.signInError = FirebaseAuthException(code: 'invalid-credential');

          await _abrir(tester, auth);
          await _entrarCom(tester, 'ana@example.com', 'errada'); // com o erro inline aberto
          expect(tester.takeException(), isNull);

          final criar = find.byKey(const Key('login_criar_conta'));
          await tester.ensureVisible(criar);
          await tester.pump();
          final caixa = tester.getRect(criar);
          expect(caixa.left, greaterThanOrEqualTo(0));
          expect(caixa.right, lessThanOrEqualTo(tamanho.width));
          expect(caixa.height, greaterThan(47.99));
          expect(tester.takeException(), isNull);

          await tester.tap(criar);
          await tester.pumpAndSettle();
          expect(find.byType(CadastroPage), findsOneWidget);
        },
      );
    }
  }

  testWidgets('a logo encolhe em vez de estourar em 320 dp', (tester) async {
    tester.view.physicalSize = const Size(320, 568) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await _abrir(tester, auth);

    final logo = tester.getRect(find.byType(LogoBetFriends));
    expect(logo.left, greaterThanOrEqualTo(0));
    expect(logo.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });
}
