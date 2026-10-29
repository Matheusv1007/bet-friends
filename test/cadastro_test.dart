import 'dart:async';

import 'package:betfriends/app.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:betfriends/telas_autenticacao/cadastro_page.dart';
import 'package:betfriends/telas_autenticacao/login_page.dart';
import 'package:betfriends/telas_autenticacao/validacao_cadastro.dart';
import 'package:betfriends/telas_principais/homePage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

/// Perfis em memória, observáveis como `users/{uid}`. Só o falso backend
/// abaixo os cria: o app não tem como gravar um perfil.
class _Perfis implements UserProfileRepository {
  final perfis = <String, UserProfile>{};
  final _mudancas = StreamController<String>.broadcast();

  void criar(UserProfile p) {
    perfis[p.uid] = p;
    _mudancas.add(p.uid);
  }

  @override
  Future<UserProfile?> buscarPorUid(String uid) async => perfis[uid];

  @override
  Stream<PerfilObservado> observarPorUid(String uid) async* {
    yield PerfilObservado(perfis[uid]);
    yield* _mudancas.stream.where((u) => u == uid).map((u) => PerfilObservado(perfis[u]));
  }

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {}
}

/// Registra as chamadas à Callable. Por padrão responde como o backend em
/// caso de sucesso e cria o perfil em [_Perfis]; o teste pode definir um erro
/// por chamada ou segurar a resposta.
class _Backend implements FunctionsService {
  final FakeAuthService auth;
  final _Perfis perfis;
  final chamadas = <Map<String, dynamic>?>[];
  final erros = <FunctionsException>[];
  Completer<void>? segurar;

  _Backend(this.auth, this.perfis);

  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
    expect(name, CallableNames.createUserProfile);
    chamadas.add(data);
    if (segurar != null) await segurar!.future;
    if (erros.isNotEmpty) throw erros.removeAt(0);
    final uid = auth.currentUser!.uid;
    final username = (data!['username'] as String).trim();
    final ja = perfis.perfis.containsKey(uid);
    perfis.criar(UserProfile(
      uid: uid,
      displayName: (data['displayName'] as String).trim(),
      username: username,
      usernameNormalized: username.toLowerCase(),
      email: auth.currentUser!.email!,
    ));
    return {
      'criado': !ja,
      'displayName': (data['displayName'] as String).trim(),
      'username': username,
      'usernameNormalized': username.toLowerCase(),
    };
  }

  @override
  Future<PingResult> ping() => throw UnimplementedError();
}

Future<void> avancar(WidgetTester tester, [int quadros = 5]) async {
  for (var i = 0; i < quadros; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

bool podeVoltar(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first).canPop();

Future<void> encerrarApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

String? erroNaTela(WidgetTester tester) {
  final f = find.byKey(const Key('cadastro_erro'));
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
}

bool habilitado(WidgetTester tester, String chave) =>
    tester.widget<TextField>(find.byKey(Key(chave))).enabled ?? true;

void main() {
  late FakeAuthService auth;
  late _Perfis perfis;
  late _Backend backend;

  setUp(() {
    auth = FakeAuthService();
    perfis = _Perfis();
    backend = _Backend(auth, perfis);
  });

  Future<void> abrirCadastro(WidgetTester tester) async {
    await tester.pumpWidget(App(
      authService: auth,
      partidasService: CountingPartidasService(),
      userProfileService: UserProfileService(
        authService: auth,
        repository: perfis,
        functionsService: backend,
      ),
    ));
    await avancar(tester);
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    expect(find.byType(CadastroPage), findsOneWidget);
  }

  Future<void> preencher(
    WidgetTester tester, {
    String nome = 'Lucas Prado',
    String username = 'Lucas10',
    String email = 'lucas@example.com',
    String senha = 'segredo1',
    String? confirmacao,
  }) async {
    await tester.enterText(find.byKey(const Key('cadastro_nome')), nome);
    await tester.enterText(find.byKey(const Key('cadastro_username')), username);
    await tester.enterText(find.byKey(const Key('cadastro_email')), email);
    await tester.enterText(find.byKey(const Key('cadastro_senha')), senha);
    await tester.enterText(find.byKey(const Key('cadastro_confirmar_senha')), confirmacao ?? senha);
  }

  Future<void> enviar(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('cadastro_enviar')));
    await tester.tap(find.byKey(const Key('cadastro_enviar')));
    // Inclui a animação de saída da rota, quando o cadastro termina
    await avancar(tester, 10);
  }

  group('Validação antes de enviar (nada é criado)', () {
    final casos = <(String, Map<String, String>)>[
      ('Preencha todos os campos.', {'email': ''}),
      ('Preencha todos os campos.', {'nome': '   '}),
      ('Preencha todos os campos.', {'confirmacao': ''}),
      ('O nome deve ter no máximo 60 caracteres.', {'nome': 'a' * 61}),
      ('O username deve ter de 3 a 20 caracteres: letras sem acento, números ou "_".', {'username': 'ab'}),
      ('O username deve ter de 3 a 20 caracteres: letras sem acento, números ou "_".', {'username': 'joão'}),
      ('E-mail inválido.', {'email': 'lucas@'}),
      ('A senha deve ter pelo menos 6 caracteres.', {'senha': '12345'}),
      ('As senhas não conferem.', {'confirmacao': 'outra-senha'}),
    ];
    for (final (mensagem, campos) in casos) {
      testWidgets('${campos.keys.single} = "${campos.values.single}" → "$mensagem"', (tester) async {
        await abrirCadastro(tester);
        await preencher(
          tester,
          nome: campos['nome'] ?? 'Lucas Prado',
          username: campos['username'] ?? 'Lucas10',
          email: campos['email'] ?? 'lucas@example.com',
          senha: campos['senha'] ?? 'segredo1',
          confirmacao: campos['confirmacao'],
        );
        await enviar(tester);

        expect(erroNaTela(tester), mensagem);
        expect(auth.signUpCalls, 0);
        expect(backend.chamadas, isEmpty);
        expect(find.byType(CadastroPage), findsOneWidget);
      });
    }

    test('validarPerfil aceita os limites do backend e recusa o resto', () {
      for (final u in ['abc', 'a' * 20, 'Lucas_10', '  lucas  ']) {
        expect(validarPerfil(nome: 'N', username: u), isNull, reason: u);
      }
      for (final u in ['ab', 'a' * 21, 'joão', 'com espaço', 'a-b', 'a.b']) {
        expect(validarPerfil(nome: 'N', username: u), isNotNull, reason: u);
      }
      expect(validarPerfil(nome: 'a' * 60, username: 'abc'), isNull);
    });
  });

  group('Cadastro válido', () {
    testWidgets('cria a conta, chama createUserProfile e abre a Home', (tester) async {
      await abrirCadastro(tester);
      await preencher(tester, nome: '  Lucas Prado ', username: ' Lucas10 ');
      await enviar(tester);

      expect(auth.signUpCalls, 1);
      expect(backend.chamadas, [
        {'displayName': '  Lucas Prado ', 'username': ' Lucas10 '},
      ]);
      expect(find.byType(CadastroPage), findsNothing);
      expect(find.byType(Homepage), findsOneWidget);
      expect(podeVoltar(tester), isFalse);
      expect(find.text('Olá, Lucas Prado'), findsOneWidget);

      await encerrarApp(tester);
    });

    testWidgets('mostra carregamento e ignora toques repetidos enquanto envia', (tester) async {
      backend.segurar = Completer<void>();
      await abrirCadastro(tester);
      await preencher(tester);
      await enviar(tester);

      // A conta já existe; a Home está por baixo, mas o Cadastro continua aberto
      expect(find.byType(CadastroPage), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('cadastro_enviar')), matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
      );
      expect(habilitado(tester, 'cadastro_nome'), isFalse);
      await tester.tap(find.byKey(const Key('cadastro_enviar')), warnIfMissed: false);
      await avancar(tester);

      backend.segurar!.complete();
      await avancar(tester, 10);

      expect(auth.signUpCalls, 1);
      expect(backend.chamadas, hasLength(1));
      expect(find.byType(Homepage), findsOneWidget);
      expect(find.byType(CadastroPage), findsNothing);

      await encerrarApp(tester);
    });
  });

  group('Erros do Firebase Auth (a conta não é criada)', () {
    final casos = <String, String>{
      'email-already-in-use': 'Este e-mail já está cadastrado. Entre com ele; se o cadastro não foi concluído, conclua-o pela aba Perfil.',
      'weak-password': 'Senha fraca. Use pelo menos 6 caracteres.',
      'invalid-email': 'E-mail inválido.',
      'network-request-failed': 'Erro de conexão. Verifique sua internet. A conta não foi criada.',
      'operation-not-allowed': 'Não foi possível criar a conta. Tente novamente.',
    };
    casos.forEach((code, mensagem) {
      testWidgets(code, (tester) async {
        auth.signUpError = FirebaseAuthException(code: code);
        await abrirCadastro(tester);
        await preencher(tester);
        await enviar(tester);

        expect(erroNaTela(tester), mensagem);
        expect(backend.chamadas, isEmpty);
        expect(auth.currentUser, isNull);
        expect(find.byType(LoginPage, skipOffstage: false), findsOneWidget);
        expect(find.text('CADASTRAR'), findsOneWidget);
        expect(habilitado(tester, 'cadastro_email'), isTrue);
      });
    });
  });

  group('Conta criada no Auth e perfil recusado ou sem confirmação', () {
    testWidgets('username em uso: mantém a sessão e repete só a criação do perfil', (tester) async {
      backend.erros.add(FunctionsException(code: 'already-exists', message: 'x', motivo: 'username-indisponivel'));
      await abrirCadastro(tester);
      await preencher(tester);
      await enviar(tester);

      expect(erroNaTela(tester), 'Sua conta foi criada, mas o perfil não. Este username já está em uso. Escolha outro.');
      expect(find.byKey(const Key('cadastro_conta_criada')), findsOneWidget);
      expect(find.text('CONCLUIR CADASTRO'), findsOneWidget);
      expect(habilitado(tester, 'cadastro_email'), isFalse);
      expect(habilitado(tester, 'cadastro_senha'), isFalse);
      expect(auth.currentUser?.uid, 'uid-lucas@example.com');
      expect(perfis.perfis, isEmpty);

      await tester.enterText(find.byKey(const Key('cadastro_username')), 'Lucas_11');
      await enviar(tester);

      expect(auth.signUpCalls, 1, reason: 'a conta não é criada de novo');
      expect(backend.chamadas, hasLength(2));
      expect(backend.chamadas.last!['username'], 'Lucas_11');
      expect(find.byType(Homepage), findsOneWidget);
      expect(find.byType(CadastroPage), findsNothing);

      await encerrarApp(tester);
    });

    final casos = <String, (FunctionsException, String)>{
      'sem conexão': (
        FunctionsException(code: 'unavailable', message: 'x'),
        'Sua conta foi criada, mas o perfil não. Sem confirmação do servidor. Verifique sua conexão e toque em CONCLUIR CADASTRO.',
      ),
      'função não implantada': (
        FunctionsException(code: 'not-found', message: 'NOT_FOUND'),
        'Sua conta foi criada, mas o perfil não. O serviço de cadastro está indisponível agora. Tente novamente mais tarde.',
      ),
      'erro interno': (
        FunctionsException(code: 'internal', message: 'stack trace'),
        'Sua conta foi criada, mas o perfil não. O serviço de cadastro está indisponível agora. Tente novamente mais tarde.',
      ),
      'nome recusado pelo backend': (
        FunctionsException(code: 'invalid-argument', message: 'x', motivo: 'nome-invalido'),
        'Sua conta foi criada, mas o perfil não. O nome deve ter entre 1 e 60 caracteres.',
      ),
    };
    casos.forEach((caso, dados) {
      testWidgets('$caso: mensagem clara e nova tentativa conclui sem duplicar', (tester) async {
        backend.erros.add(dados.$1);
        await abrirCadastro(tester);
        await preencher(tester);
        await enviar(tester);

        expect(erroNaTela(tester), dados.$2);
        expect(find.byType(CadastroPage), findsOneWidget);
        expect(auth.signOutCalls, 0, reason: 'a sessão é mantida');

        await enviar(tester);

        expect(auth.signUpCalls, 1);
        expect(backend.chamadas, hasLength(2));
        expect(perfis.perfis.keys, ['uid-lucas@example.com']);
        expect(find.byType(Homepage), findsOneWidget);

        await encerrarApp(tester);
      });
    });

    testWidgets('sair do Cadastro após a falha leva à Home logado, sem apagar a conta', (tester) async {
      backend.erros.add(FunctionsException(code: 'unavailable', message: 'x'));
      await abrirCadastro(tester);
      await preencher(tester);
      await enviar(tester);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await avancar(tester, 10);

      expect(find.byType(CadastroPage), findsNothing);
      expect(find.byType(Homepage), findsOneWidget);
      expect(find.text('Olá!'), findsOneWidget);
      expect(auth.currentUser, isNotNull);
      expect(auth.signOutCalls, 0);

      await encerrarApp(tester);
    });
  });

  group('Recuperação pela aba Perfil (conta sem perfil)', () {
    testWidgets('Perfil sem documento oferece CONCLUIR CADASTRO, que cria o perfil e volta', (tester) async {
      auth = FakeAuthService(usuarioInicial: FakeUser('uid-rita', email: 'rita@example.com'));
      backend = _Backend(auth, perfis);
      await tester.pumpWidget(App(
        authService: auth,
        partidasService: CountingPartidasService(),
        userProfileService: UserProfileService(authService: auth, repository: perfis, functionsService: backend),
      ));
      await avancar(tester);
      expect(find.text('Olá!'), findsOneWidget);

      await tester.tap(find.text('Perfil'));
      await avancar(tester);
      expect(find.text('Perfil ainda não criado'), findsOneWidget);

      await tester.tap(find.text('CONCLUIR CADASTRO'));
      await avancar(tester);
      expect(find.text('Concluir Cadastro'), findsOneWidget);
      expect(find.byKey(const Key('cadastro_email')), findsNothing);
      expect(find.byKey(const Key('cadastro_senha')), findsNothing);

      await tester.enterText(find.byKey(const Key('cadastro_nome')), 'Rita Costa');
      await tester.enterText(find.byKey(const Key('cadastro_username')), 'rita_c');
      await enviar(tester);

      expect(auth.signUpCalls, 0);
      expect(backend.chamadas, hasLength(1));
      expect(find.byType(CadastroPage), findsNothing);
      expect(find.byType(PerfilScreen), findsOneWidget);
      expect(find.text('Rita Costa'), findsWidgets);
      expect(find.text('@rita_c'), findsOneWidget);

      await encerrarApp(tester);
    });

    testWidgets('perfil criado em outra tentativa: o backend devolve criado == false e a tela conclui', (tester) async {
      perfis.criar(const UserProfile(
        uid: 'uid-rita',
        displayName: 'Rita Costa',
        username: 'rita_c',
        usernameNormalized: 'rita_c',
        email: 'rita@example.com',
      ));
      auth = FakeAuthService(usuarioInicial: FakeUser('uid-rita', email: 'rita@example.com'));
      final servico = UserProfileService(authService: auth, repository: perfis, functionsService: _Backend(auth, perfis));

      final r = await servico.criarPerfilDoUsuarioAtual(displayName: 'Rita Costa', username: 'rita_c');

      expect(r.criado, isFalse);
      expect(perfis.perfis, hasLength(1));
    });
  });
}
