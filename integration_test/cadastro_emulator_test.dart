// Cadastro pela tela (KAN-25) com o app inteiro (AuthGate, Login, Cadastro,
// Home e Perfil) nos emuladores de Auth, Firestore e Functions, com as
// Security Rules reais e a Callable createUserProfile (KAN-31).
//
// Roda num dispositivo Android (emulador) com um FirebaseApp separado,
// configurado para o projeto fictício demo-betfriends e apontado para os
// emuladores do host (10.0.2.2). O app padrão, ligado ao projeto real, nem é
// inicializado, e as partidas vêm de um serviço local (sem a Football-Data).
// As contas são criadas pela própria tela, com e-mails e usernames próprios
// (prefixo "cad"), para não colidir com os outros arquivos na mesma sessão dos
// emuladores. Como executar: integration_test/README.md.

import 'package:betfriends/app.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:betfriends/telas_autenticacao/cadastro_page.dart';
import 'package:betfriends/telas_autenticacao/login_page.dart';
import 'package:betfriends/telas_principais/homePage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _projeto = 'demo-betfriends';
const _hostEmuladores = '10.0.2.2'; // localhost do host visto pelo emulador Android
const _portaAuth = 9099;
const _portaFirestore = 8080;
const _portaFunctions = 5001;

// Senha de contas que existem só no Auth Emulator, criadas pela tela
const _senha = 'senha-emulador-123';

const _opcoesDemo = FirebaseOptions(
  // Chave fictícia no formato do Firebase (ver criar_perfil_emulator_test.dart).
  // Não é credencial.
  apiKey: 'Ademo-betfriends-emulador-0000000000000',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: _projeto,
);

/// Partidas locais: a Home não chama a API real durante o teste.
class _PartidasLocais extends PartidasService {
  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async => [
        PartidaModel(
          id: '1',
          timeMandante: 'Time A',
          timeVisitante: 'Time B',
          status: 'PRÓXIMO JOGO',
          horario: 'Hoje 20:00',
        ),
      ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseApp app;
  late FirebaseAuth auth;
  late FirebaseFirestore db;
  late AuthService authService;
  late FunctionsService functions;

  UserProfileService servicoDePerfil(FunctionsService f) => UserProfileService(
        authService: authService,
        repository: FirestoreUserProfileRepository(firestore: db),
        functionsService: f,
      );

  Future<void> avancar(WidgetTester tester, [int quadros = 10]) async {
    for (var i = 0; i < quadros; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Espera até [condicao] valer, bombeando quadros (rede real do emulador).
  Future<void> esperar(WidgetTester tester, bool Function() condicao, {String? motivo}) async {
    for (var i = 0; i < 150; i++) {
      if (condicao()) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Tempo esgotado: ${motivo ?? 'condição'}');
  }

  Future<void> abrirApp(WidgetTester tester, {FunctionsService? f}) async {
    await tester.pumpWidget(App(
      authService: authService,
      partidasService: _PartidasLocais(),
      userProfileService: servicoDePerfil(f ?? functions),
    ));
    await avancar(tester);
  }

  Future<void> encerrarApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  Future<void> enviar(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('cadastro_enviar')));
    await tester.tap(find.byKey(const Key('cadastro_enviar')));
    await avancar(tester, 3);
    // O envio termina quando o botão volta a ficar habilitado ou a tela sai
    await esperar(
      tester,
      () =>
          find.byType(CadastroPage).evaluate().isEmpty ||
          tester.widget<ElevatedButton>(find.byKey(const Key('cadastro_enviar'))).onPressed != null,
      motivo: 'fim do envio do cadastro',
    );
    await avancar(tester);
  }

  Future<void> cadastrar(
    WidgetTester tester, {
    required String nome,
    required String username,
    required String email,
  }) async {
    await tester.tap(find.text('Criar conta'));
    await avancar(tester);
    await tester.enterText(find.byKey(const Key('cadastro_nome')), nome);
    await tester.enterText(find.byKey(const Key('cadastro_username')), username);
    await tester.enterText(find.byKey(const Key('cadastro_email')), email);
    await tester.enterText(find.byKey(const Key('cadastro_senha')), _senha);
    await tester.enterText(find.byKey(const Key('cadastro_confirmar_senha')), _senha);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await enviar(tester);
  }

  String? erroNaTela(WidgetTester tester) {
    final f = find.byKey(const Key('cadastro_erro'));
    return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
  }

  Future<void> sair(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('menu_conta')));
    await avancar(tester);
    await tester.tap(find.text('Sair da conta'));
    await avancar(tester);
    await tester.tap(find.text('Sair'));
    await esperar(tester, () => find.byType(LoginPage).evaluate().isNotEmpty, motivo: 'Login após sair');
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> ledgerDe(String uid) async {
    final r = await db.collection('betCoinTransactions').where('userId', isEqualTo: uid).get();
    return r.docs;
  }

  setUpAll(() async {
    app = await Firebase.initializeApp(name: 'kan25-cadastro', options: _opcoesDemo);
    // Falha segura: nunca usar o projeto real
    expect(app.options.projectId, startsWith('demo-'));

    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(_hostEmuladores, _portaAuth);
    await auth.signOut();
    authService = AuthService(firebaseAuth: auth);

    db = FirebaseFirestore.instanceFor(app: app);
    db.settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator(_hostEmuladores, _portaFirestore);

    functions = FunctionsService(
      functions: FirebaseFunctions.instanceFor(app: app, region: kFunctionsRegion)
        ..useFunctionsEmulator(_hostEmuladores, _portaFunctions),
    );
  });

  tearDownAll(() => auth.signOut());

  testWidgets('A - cadastro válido cria conta, perfil e carteira e abre a Home', (tester) async {
    await abrirApp(tester);
    expect(find.byType(LoginPage), findsOneWidget);

    await cadastrar(tester, nome: 'Lucas Prado', username: 'CadLucas', email: 'cad.lucas@example.com');

    expect(erroNaTela(tester), isNull);
    expect(find.byType(CadastroPage), findsNothing);
    await esperar(tester, () => find.text('Olá, Lucas Prado').evaluate().isNotEmpty, motivo: 'saudação');
    expect(find.byType(Homepage), findsOneWidget);

    final uid = auth.currentUser!.uid;
    final dados = (await db.doc('users/$uid').get()).data()!;
    expect(dados['username'], 'CadLucas');
    expect(dados['usernameNormalized'], 'cadlucas');
    expect(dados['email'], 'cad.lucas@example.com');
    expect(dados['saldoTotal'], 1000);
    expect(dados['saldoReservado'], 0);
    final ledger = await ledgerDe(uid);
    expect(ledger.map((d) => d.id), ['${uid}_INITIAL_BALANCE']);
    expect(ledger.single.data()['amount'], 1000);

    await encerrarApp(tester);
  });

  testWidgets('B - logout, login com a conta criada e restauração da sessão', (tester) async {
    await abrirApp(tester);
    await esperar(tester, () => find.byType(Homepage).evaluate().isNotEmpty, motivo: 'sessão de A');
    final uid = auth.currentUser!.uid;

    await sair(tester);
    expect(auth.currentUser, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'cad.lucas@example.com');
    await tester.enterText(find.byType(TextField).at(1), _senha);
    await tester.tap(find.text('ENTRAR'));
    await esperar(tester, () => find.text('Olá, Lucas Prado').evaluate().isNotEmpty, motivo: 'login');
    expect(auth.currentUser!.uid, uid);

    // App reaberto com a sessão salva: vai direto para a Home
    await encerrarApp(tester);
    await abrirApp(tester);
    await esperar(tester, () => find.text('Olá, Lucas Prado').evaluate().isNotEmpty, motivo: 'sessão restaurada');
    expect(find.byType(LoginPage), findsNothing);
    expect(await ledgerDe(uid), hasLength(1));

    await sair(tester);
    await encerrarApp(tester);
  });

  testWidgets('C - e-mail já cadastrado: mensagem, nenhuma conta nova', (tester) async {
    await abrirApp(tester);

    await cadastrar(tester, nome: 'Outro', username: 'cad_outro', email: 'cad.lucas@example.com');

    expect(erroNaTela(tester), startsWith('Este e-mail já está cadastrado.'));
    expect(auth.currentUser, isNull);
    expect(find.text('CADASTRAR'), findsOneWidget);

    await encerrarApp(tester);
  });

  testWidgets('D - username já usado: a conta fica criada e só o perfil é repetido', (tester) async {
    await abrirApp(tester);

    await cadastrar(tester, nome: 'Outro Lucas', username: 'CADLUCAS', email: 'cad.outro@example.com');

    expect(erroNaTela(tester), contains('Este username já está em uso'));
    expect(find.byKey(const Key('cadastro_conta_criada')), findsOneWidget);
    final uid = auth.currentUser!.uid;
    expect((await db.doc('users/$uid').get()).exists, isFalse);
    expect(await ledgerDe(uid), isEmpty);

    await tester.enterText(find.byKey(const Key('cadastro_username')), 'CadLucas_2');
    await enviar(tester);

    expect(find.byType(CadastroPage), findsNothing);
    await esperar(tester, () => find.text('Olá, Outro Lucas').evaluate().isNotEmpty, motivo: 'saudação');
    expect(auth.currentUser!.uid, uid, reason: 'a mesma conta, sem criar outra');
    expect((await db.doc('users/$uid').get()).data()!['saldoTotal'], 1000);
    expect(await ledgerDe(uid), hasLength(1));

    await sair(tester);
    await encerrarApp(tester);
  });

  testWidgets('E - Callable falha após criar a conta; perfil concluído depois pelo Perfil', (tester) async {
    // Functions fora do ar: porta sem nenhum serviço
    final semFunctions = FunctionsService(
      functions: FirebaseFunctions.instanceFor(app: app, region: 'us-central1')
        ..useFunctionsEmulator(_hostEmuladores, 1),
    );
    await abrirApp(tester, f: semFunctions);

    await cadastrar(tester, nome: 'Rita Costa', username: 'cad_rita', email: 'cad.rita@example.com');

    expect(erroNaTela(tester), contains('Sem confirmação do servidor'));
    final uid = auth.currentUser!.uid;
    expect((await db.doc('users/$uid').get()).exists, isFalse);

    // Usuário desiste; o app é reaberto já com o backend disponível
    await encerrarApp(tester);
    await abrirApp(tester);
    await esperar(tester, () => find.byType(Homepage).evaluate().isNotEmpty, motivo: 'Home sem perfil');
    expect(find.text('Olá!'), findsOneWidget);

    await tester.tap(find.text('Perfil'));
    await esperar(tester, () => find.text('Perfil ainda não criado').evaluate().isNotEmpty, motivo: 'aviso no Perfil');
    await tester.tap(find.text('CONCLUIR CADASTRO'));
    await avancar(tester);
    await tester.enterText(find.byKey(const Key('cadastro_nome')), 'Rita Costa');
    await tester.enterText(find.byKey(const Key('cadastro_username')), 'cad_rita');
    await enviar(tester);

    expect(find.byType(CadastroPage), findsNothing);
    expect(find.byType(PerfilScreen), findsOneWidget);
    await esperar(tester, () => find.text('@cad_rita').evaluate().isNotEmpty, motivo: 'perfil exibido');
    expect(auth.currentUser!.uid, uid);
    expect((await db.doc('users/$uid').get()).data()!['saldoTotal'], 1000);
    expect(await ledgerDe(uid), hasLength(1));

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await avancar(tester);
    await sair(tester);
    await encerrarApp(tester);
  });
}
