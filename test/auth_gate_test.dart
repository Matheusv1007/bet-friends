import 'dart:async';

import 'package:betfriends/app.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/telas_autenticacao/cadastro_page.dart';
import 'package:betfriends/telas_autenticacao/login_page.dart';
import 'package:betfriends/telas_principais/homePage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

/// Avança alguns quadros sem `pumpAndSettle`, que não termina com o
/// polling periódico e os indicadores de progresso da Home.
Future<void> avancar(WidgetTester tester, [int quadros = 5]) async {
  for (var i = 0; i < quadros; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

bool podeVoltar(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first).canPop();

Future<void> abrirApp(
  WidgetTester tester,
  FakeAuthService auth, {
  CountingPartidasService? partidas,
}) async {
  await tester.pumpWidget(
    App(authService: auth, partidasService: partidas ?? CountingPartidasService()),
  );
  await avancar(tester);
}

Future<void> sairPeloMenu(WidgetTester tester, {bool confirmar = true}) async {
  await tester.tap(find.byKey(const Key('menu_conta')));
  await avancar(tester);
  await tester.tap(find.text('Sair da conta'));
  await avancar(tester);
  await tester.tap(find.text(confirmar ? 'Sair' : 'Cancelar'));
  await avancar(tester);
}

/// Remove a árvore para descartar a Home e cancelar seus timers.
Future<void> encerrarApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  group('AuthGate - verificação de sessão', () {
    testWidgets('exibe carregamento enquanto a sessão é verificada, sem Login nem Home',
        (tester) async {
      final auth = FakeAuthService(sessaoPendente: true);
      await tester.pumpWidget(App(authService: auth, partidasService: CountingPartidasService()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(Homepage), findsNothing);

      auth.resolverSessao(null);
      await avancar(tester);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('sem sessão exibe o Login', (tester) async {
      await abrirApp(tester, FakeAuthService());

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(Homepage), findsNothing);
    });

    testWidgets('sessão já existente é restaurada direto na Home', (tester) async {
      await abrirApp(tester, FakeAuthService(usuarioInicial: FakeUser('uid-1')));

      expect(find.byType(Homepage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(podeVoltar(tester), isFalse);

      await encerrarApp(tester);
    });
  });

  group('Login', () {
    testWidgets('login bem-sucedido abre a Home uma única vez, sem rota para voltar',
        (tester) async {
      final auth = FakeAuthService();
      await abrirApp(tester, auth);

      await tester.enterText(find.byType(TextField).at(0), 'teste@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'senha-fake');
      await tester.tap(find.text('ENTRAR'));
      await avancar(tester);

      expect(auth.signInCalls, 1);
      expect(find.byType(Homepage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(podeVoltar(tester), isFalse);

      await encerrarApp(tester);
    });

    testWidgets('"CADASTRAR" volta ao Login existente sem empilhar outro', (tester) async {
      await abrirApp(tester, FakeAuthService());

      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();
      expect(find.byType(CadastroPage), findsOneWidget);

      await tester.ensureVisible(find.text('CADASTRAR'));
      await tester.tap(find.text('CADASTRAR'));
      await tester.pumpAndSettle();

      expect(find.byType(CadastroPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(podeVoltar(tester), isFalse);
    });
  });

  group('Logout', () {
    testWidgets('logout encerra a sessão e o AuthGate volta ao Login', (tester) async {
      final auth = FakeAuthService(usuarioInicial: FakeUser('uid-1'));
      await abrirApp(tester, auth);

      await sairPeloMenu(tester);

      expect(auth.signOutCalls, 1);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(Homepage), findsNothing);
    });

    testWidgets('botão Voltar após o logout não retorna à Home', (tester) async {
      final auth = FakeAuthService(usuarioInicial: FakeUser('uid-1'));
      await abrirApp(tester, auth);
      await sairPeloMenu(tester);

      expect(podeVoltar(tester), isFalse);
      await tester.binding.handlePopRoute();
      await avancar(tester);

      expect(find.byType(Homepage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('cancelar a confirmação mantém a sessão', (tester) async {
      final auth = FakeAuthService(usuarioInicial: FakeUser('uid-1'));
      await abrirApp(tester, auth);

      await sairPeloMenu(tester, confirmar: false);

      expect(auth.signOutCalls, 0);
      expect(find.byType(Homepage), findsOneWidget);

      await encerrarApp(tester);
    });

    testWidgets('falha no logout mantém a Home e informa o erro, sem simular sucesso',
        (tester) async {
      final auth = FakeAuthService(usuarioInicial: FakeUser('uid-1'))
        ..signOutError = Exception('falha simulada');
      await abrirApp(tester, auth);

      await sairPeloMenu(tester);

      expect(auth.signOutCalls, 1);
      expect(find.text('Não foi possível sair da conta. Tente novamente.'), findsOneWidget);
      expect(find.byType(Homepage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);

      await encerrarApp(tester);
    });

    testWidgets('durante o logout o menu fica bloqueado contra novas tentativas',
        (tester) async {
      final auth = FakeAuthService(usuarioInicial: FakeUser('uid-1'))
        ..signOutEmAndamento = Completer<void>();
      await abrirApp(tester, auth);

      await sairPeloMenu(tester);
      expect(auth.signOutCalls, 1);

      // Nova tentativa enquanto o primeiro logout não terminou
      await tester.tap(find.byKey(const Key('menu_conta')));
      await avancar(tester);
      expect(find.text('Sair da conta'), findsNothing);

      auth.signOutEmAndamento!.complete();
      await avancar(tester);

      expect(auth.signOutCalls, 1);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('logout descarta a Home e interrompe o polling de partidas',
        (tester) async {
      final auth = FakeAuthService(usuarioInicial: FakeUser('uid-1'));
      final partidas = CountingPartidasService();
      await abrirApp(tester, auth, partidas: partidas);

      // O polling está ativo antes do logout
      final iniciais = partidas.chamadas;
      await tester.pump(const Duration(seconds: 31));
      expect(partidas.chamadas, greaterThan(iniciais));

      await sairPeloMenu(tester);
      final aposLogout = partidas.chamadas;

      await tester.pump(const Duration(seconds: 95));
      expect(partidas.chamadas, aposLogout);
      expect(find.byType(Homepage), findsNothing);
    });

    testWidgets('sessão encerrada fora do app remove telas protegidas empilhadas',
        (tester) async {
      final auth = FakeAuthService(usuarioInicial: FakeUser('uid-1'));
      await abrirApp(tester, auth);

      await tester.tap(find.text('Desafiar'));
      await avancar(tester, 10);
      expect(find.byType(CriarDesafioScreen), findsOneWidget);

      auth.encerrarSessaoExternamente();
      await avancar(tester, 10);

      expect(find.byType(CriarDesafioScreen), findsNothing);
      expect(find.byType(Homepage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(podeVoltar(tester), isFalse);
    });
  });
}
