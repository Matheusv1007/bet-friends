import 'dart:async';

import 'package:betfriends/app.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/provider/auth_provider.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tela_perfil/excluir_conta_dialog.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

const _ana = UserProfile(
  uid: 'uid-ana',
  displayName: 'Ana Lima',
  username: 'AnaL',
  usernameNormalized: 'anal',
  email: 'ana@example.com',
);

class _Repositorio extends Fake implements UserProfileRepository {
  bool doCache = false;

  @override
  Stream<PerfilObservado> observarPorUid(String uid) async* {
    expect(uid, _ana.uid);
    yield PerfilObservado(_ana, doCache: doCache);
  }
}

class _Auth extends FakeAuthService {
  _Auth() : super(usuarioInicial: FakeUser(_ana.uid, email: _ana.email));

  int exclusoes = 0;
  Object? erro;
  Completer<void>? emAndamento;

  @override
  Future<void> deleteAccount({required String password}) async {
    exclusoes++;
    expect(password, 'senha-secreta');
    if (emAndamento != null) await emAndamento!.future;
    if (erro != null) throw erro!;
    await signOut();
  }
}

final _abrir = find.byKey(const Key('perfil_excluir_conta'));
final _username = find.byKey(const Key('excluir_conta_username'));
final _senha = find.byKey(const Key('excluir_conta_senha'));
final _confirmar = find.byKey(const Key('excluir_conta_confirmar'));
final _cancelar = find.byKey(const Key('excluir_conta_cancelar'));

void main() {
  late _Auth auth;
  late _Repositorio repositorio;

  setUp(() {
    auth = _Auth();
    repositorio = _Repositorio();
  });

  Future<void> abrirPerfil(WidgetTester tester, {bool appCompleto = false}) async {
    final service = UserProfileService(authService: auth, repository: repositorio);
    if (appCompleto) {
      await tester.pumpWidget(App(
        authService: auth,
        partidasService: CountingPartidasService(),
        userProfileService: service,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
    } else {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(authService: auth)),
          Provider<UserProfileService>.value(value: service),
        ],
        child: const MaterialApp(home: PerfilScreen()),
      ));
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _abrir,
      200,
      scrollable: find.descendant(
        of: find.byType(PerfilScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirDialogo(WidgetTester tester, {bool appCompleto = false}) async {
    await abrirPerfil(tester, appCompleto: appCompleto);
    await tester.tap(_abrir);
    await tester.pumpAndSettle();
  }

  Future<void> preencher(WidgetTester tester, {String username = 'AnaL'}) async {
    await tester.enterText(_username, username);
    await tester.enterText(_senha, 'senha-secreta');
  }

  Future<void> confirmar(WidgetTester tester) async {
    await tester.ensureVisible(_confirmar);
    await tester.tap(_confirmar);
    await tester.pumpAndSettle();
  }

  TextFormField campoDa(WidgetTester tester, Finder campo) =>
      tester.widget<TextFormField>(find.descendant(of: campo, matching: find.byType(TextFormField)));

  String senhaNoCampo(WidgetTester tester) => campoDa(tester, _senha).controller!.text;

  bool bloqueado(WidgetTester tester, Finder botao) => tester
      .widget<AbsorbPointer>(find.descendant(of: botao, matching: find.byType(AbsorbPointer)).first)
      .absorbing;

  testWidgets('explica consequências e usa senha protegida e alvos de 48px', (tester) async {
    await abrirPerfil(tester);
    expect(tester.getSize(_abrir).height, greaterThanOrEqualTo(48));
    await tester.tap(_abrir);
    await tester.pumpAndSettle();
    expect(find.textContaining('perfil, amizades e pedidos de amizade serão apagados'), findsOneWidget);
    expect(find.textContaining('username ficará livre'), findsOneWidget);
    expect(find.textContaining('extrato e os desafios encerrados permanecerão sem dados pessoais'), findsOneWidget);
    final campo = tester.widget<TextField>(
      find.descendant(of: _senha, matching: find.byType(TextField)),
    );
    expect(campo.obscureText, isTrue);
    expect(campo.autocorrect, isFalse);
    expect(campo.enableSuggestions, isFalse);
    for (final finder in [_cancelar, _confirmar]) {
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
    }
    expect(auth.exclusoes, 0);
  });

  testWidgets('campos com rótulo; username como ajuda sem truncar; ação destrutiva e ações numa linha só',
      (tester) async {
    await abrirDialogo(tester);

    expect(find.descendant(of: _username, matching: find.text('Digite seu username para confirmar')), findsOneWidget);
    expect(find.descendant(of: _username, matching: find.text('Seu username: AnaL')), findsOneWidget);
    expect(find.descendant(of: _senha, matching: find.text('Senha atual')), findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.byIcon(Icons.warning_amber_rounded)), findsOneWidget);
    expect(find.descendant(of: _confirmar, matching: find.byType(OutlinedButton)), findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Excluir conta')), findsNWidgets(2)); // título e ação

    final cancelar = tester.getRect(_cancelar);
    final excluir = tester.getRect(_confirmar);
    expect(cancelar.center.dy, closeTo(excluir.center.dy, 0.5));
    expect(cancelar.right, lessThan(excluir.left));
    expect(tester.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first).right - excluir.right, lessThanOrEqualTo(24));
  });

  testWidgets('erros sob os campos somem ao editar', (tester) async {
    await abrirDialogo(tester);
    await preencher(tester, username: 'Outro');
    await confirmar(tester);
    expect(find.text('Digite seu username exatamente como exibido.'), findsOneWidget);

    await tester.enterText(_username, 'AnaL');
    await tester.pumpAndSettle();
    expect(find.text('Digite seu username exatamente como exibido.'), findsNothing);
  });

  for (final (largura, escala) in [(320.0, 1.0), (320.0, 2.0), (360.0, 1.5), (360.0, 2.0)]) {
    testWidgets('sem estouro em ${largura.toInt()} dp com fonte ${escala}x, com e sem erros', (tester) async {
      tester.view.physicalSize = Size(largura, 568) * tester.view.devicePixelRatio;
      tester.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      auth.erro = DeleteAccountException.fromCode('desafio-ativo');

      await abrirDialogo(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(_confirmar, warnIfMissed: false);
      await tester.pumpAndSettle();
      await preencher(tester);
      await confirmar(tester);
      expect(find.byKey(const Key('excluir_conta_erro')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('exclusão confirmada retorna ao login somente pelo AuthGate', (tester) async {
    await abrirDialogo(tester, appCompleto: true);
    await preencher(tester);
    await confirmar(tester);
    expect(auth.exclusoes, 1);
    expect(auth.signOutCalls, 1);
    expect(auth.currentUser, isNull);
    expect(find.byType(ExcluirContaDialog), findsNothing);
    expect(find.byType(PerfilScreen), findsNothing);
    expect(find.byKey(const Key('login_entrar')), findsOneWidget);
  });

  for (final username in ['', 'Outro', 'anal', '@AnaL', 'AnaL ']) {
    testWidgets('username "$username" não confirma a própria conta', (tester) async {
      await abrirDialogo(tester);
      await preencher(tester, username: username);
      await confirmar(tester);
      expect(find.descendant(of: _username, matching: find.text('Digite seu username exatamente como exibido.')), findsOneWidget);
      expect(auth.exclusoes, 0);
      expect(senhaNoCampo(tester), isEmpty);
    });
  }

  testWidgets('senha é obrigatória e cancelar não chama exclusão', (tester) async {
    await abrirDialogo(tester);
    await tester.enterText(_username, 'AnaL');
    await confirmar(tester);
    expect(find.text('Informe sua senha atual.'), findsOneWidget);
    expect(auth.exclusoes, 0);
    await tester.tap(_cancelar);
    await tester.pumpAndSettle();
    expect(find.byType(ExcluirContaDialog), findsNothing);
    expect(auth.signOutCalls, 0);
  });

  testWidgets('cancelar limpa senha no dispose', (tester) async {
    await abrirDialogo(tester);
    await preencher(tester);
    final controller = campoDa(tester, _senha).controller!;
    var senhaApagada = false;
    controller.addListener(() {
      if (controller.text.isEmpty) senhaApagada = true;
    });
    await tester.tap(_cancelar);
    await tester.pumpAndSettle();
    expect(senhaApagada, isTrue);
    expect(auth.exclusoes, 0);
  });

  for (final (code, mensagem) in [
    ('desafio-ativo', 'Conclua ou cancele seus desafios em andamento antes de excluir a conta.'),
    ('saldo-reservado', 'Você possui saldo reservado. Aguarde a liberação antes de excluir a conta.'),
    ('wrong-password', 'Senha incorreta. Confira sua senha e tente novamente.'),
    ('login-recente-necessario', 'Por segurança, entre novamente e confirme sua senha para excluir a conta.'),
    ('unauthenticated', 'Sua sessão expirou. Entre novamente para excluir a conta.'),
    ('unavailable', 'Sem conexão com o servidor. A exclusão não foi confirmada. Tente novamente online.'),
    ('deadline-exceeded', 'Sem conexão com o servidor. A exclusão não foi confirmada. Tente novamente online.'),
    ('resource-exhausted', 'Muitas tentativas. Aguarde um pouco antes de tentar excluir a conta novamente.'),
    ('unknown', 'Não foi possível excluir a conta. Tente novamente.'),
  ]) {
    testWidgets('$code informa erro sem sucesso e limpa senha após uso', (tester) async {
      auth.erro = DeleteAccountException.fromCode(code);
      await abrirDialogo(tester);
      await preencher(tester);
      await confirmar(tester);
      expect(find.text(mensagem), findsOneWidget);
      // Senha incorreta fica sob o campo da senha; o resto, num aviso do diálogo
      expect(
        find.descendant(of: _senha, matching: find.text(mensagem)),
        code == 'wrong-password' ? findsOneWidget : findsNothing,
      );
      expect(
        find.descendant(of: find.byKey(const Key('excluir_conta_erro')), matching: find.text(mensagem)),
        code == 'wrong-password' ? findsNothing : findsOneWidget,
      );
      expect(auth.exclusoes, 1);
      expect(auth.signOutCalls, 0);
      expect(auth.currentUser, isNotNull);
      expect(senhaNoCampo(tester), isEmpty);
      expect(bloqueado(tester, _confirmar), isFalse);
      await confirmar(tester);
      expect(auth.exclusoes, 1); // Uma nova senha é exigida em cada uso.
    });
  }

  testWidgets('erro inesperado não mostra detalhes internos ou credenciais', (tester) async {
    auth.erro = StateError('detalhe interno');
    await abrirDialogo(tester);
    await preencher(tester);
    await confirmar(tester);
    expect(find.text('Não foi possível excluir a conta. Tente novamente.'), findsOneWidget);
    expect(find.textContaining('detalhe interno'), findsNothing);
    expect(senhaNoCampo(tester), isEmpty);
  });

  testWidgets('duplo toque faz uma chamada, bloqueia saída e limpa senha durante uso', (tester) async {
    auth.emAndamento = Completer<void>();
    auth.erro = DeleteAccountException.fromCode('unavailable');
    await abrirDialogo(tester);
    await preencher(tester);
    await tester.ensureVisible(_confirmar);
    await tester.tap(_confirmar);
    await tester.tap(_confirmar);
    await tester.pump();
    expect(auth.exclusoes, 1);
    expect(senhaNoCampo(tester), isEmpty);
    expect(bloqueado(tester, _confirmar), isTrue);
    expect(find.descendant(of: _confirmar, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(tester.widget<TextButton>(find.descendant(of: _cancelar, matching: find.byType(TextButton))).onPressed, isNull);
    expect(campoDa(tester, _senha).enabled, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(ExcluirContaDialog), findsOneWidget);
    auth.emAndamento!.complete();
    await tester.pumpAndSettle();
    expect(auth.exclusoes, 1);
    expect(senhaNoCampo(tester), isEmpty);
  });

  testWidgets('offline não abre confirmação, não exclui nem sai da sessão', (tester) async {
    repositorio.doCache = true;
    await abrirPerfil(tester);
    await tester.tap(_abrir);
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão. Conecte-se à internet para excluir a conta.'), findsOneWidget);
    expect(find.byType(ExcluirContaDialog), findsNothing);
    expect(auth.exclusoes, 0);
    expect(auth.signOutCalls, 0);
  });
}
