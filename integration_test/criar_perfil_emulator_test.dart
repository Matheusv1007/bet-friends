// Integração da criação de perfil (KAN-32) com a Callable createUserProfile
// (KAN-31) nos emuladores de Auth, Firestore e Functions, com as Security
// Rules reais (firestore.rules).
//
// Roda num dispositivo Android (emulador) com um FirebaseApp separado,
// configurado para o projeto fictício demo-betfriends e apontado para os
// emuladores do host (10.0.2.2). O app padrão, ligado ao projeto real, nem é
// inicializado. As contas são criadas pelo próprio teste no Auth Emulator.
// Como executar: integration_test/README.md.

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _projeto = 'demo-betfriends';
const _hostEmuladores = '10.0.2.2'; // localhost do host visto pelo emulador Android
const _portaAuth = 9099;
const _portaFirestore = 8080;
const _portaFunctions = 5001;

// Contas que existem só no Auth Emulator, criadas por este arquivo
const _senha = 'senha-emulador-123';

const _opcoesDemo = FirebaseOptions(
  // Chave fictícia: o SDK de Functions no Android recusa chaves fora do
  // formato do Firebase (39 caracteres começando com "A"). Não é credencial.
  apiKey: 'Ademo-betfriends-emulador-0000000000000',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: _projeto,
);

Matcher _erro(UserProfileErrorCode code) =>
    throwsA(isA<UserProfileException>().having((e) => e.code, 'code', code));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseApp app;
  late FirebaseAuth auth;
  late FirebaseFirestore db;
  late FunctionsService functions;
  late UserProfileService service;

  /// Cria a conta no Auth Emulator (como a KAN-25 fará) e entra com ela.
  Future<String> novaConta(String email) async {
    await auth.signOut();
    try {
      await auth.createUserWithEmailAndPassword(email: email, password: _senha);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      await auth.signInWithEmailAndPassword(email: email, password: _senha);
    }
    return auth.currentUser!.uid;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> ledgerDe(String uid) async {
    final r = await db.collection('betCoinTransactions').where('userId', isEqualTo: uid).get();
    return r.docs;
  }

  setUpAll(() async {
    app = await Firebase.initializeApp(name: 'kan32-callable', options: _opcoesDemo);
    // Falha segura: nunca usar o projeto real
    expect(app.options.projectId, startsWith('demo-'));

    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(_hostEmuladores, _portaAuth);

    db = FirebaseFirestore.instanceFor(app: app);
    // Sem cache local: toda leitura vai ao emulador e passa pelas rules
    db.settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator(_hostEmuladores, _portaFirestore);

    functions = FunctionsService(
      functions: FirebaseFunctions.instanceFor(app: app, region: kFunctionsRegion)
        ..useFunctionsEmulator(_hostEmuladores, _portaFunctions),
    );
    service = UserProfileService(
      authService: AuthService(firebaseAuth: auth),
      repository: FirestoreUserProfileRepository(firestore: db),
      functionsService: functions,
    );
  });

  tearDownAll(() => auth.signOut());

  group('A - Criação pela Callable', () {
    test('cria users/{uid} do UID autenticado, com username, e-mail e carteira inicial', () async {
      final uid = await novaConta('lucas@example.com');

      final r = await service.criarPerfilDoUsuarioAtual(displayName: '  Lucas Prado ', username: ' Lucas10 ');

      expect(r.criado, isTrue);
      expect(r.perfil.uid, uid);
      expect(r.perfil.email, 'lucas@example.com');
      expect(r.perfil.displayName, 'Lucas Prado');
      expect(r.perfil.username, 'Lucas10');
      expect(r.perfil.usernameNormalized, 'lucas10');

      // O documento gravado pelo backend é o mesmo que o app lê
      final lido = (await service.carregarPerfilAtual())!;
      expect(lido.uid, uid);
      expect(lido.displayName, r.perfil.displayName);
      expect(lido.username, r.perfil.username);
      expect(lido.usernameNormalized, r.perfil.usernameNormalized);
      expect(lido.email, r.perfil.email);
      expect(lido.createdAt, isNotNull);

      final dados = (await db.doc('users/$uid').get()).data()!;
      expect(dados['saldoTotal'], 1000);
      expect(dados['saldoReservado'], 0);
      expect(dados.containsKey('uid'), isFalse);

      final ledger = await ledgerDe(uid);
      expect(ledger.map((d) => d.id), ['${uid}_INITIAL_BALANCE']);
      expect(ledger.single.data()['amount'], 1000);
    });

    test('repetir a chamada não duplica perfil nem carteira (criado == false)', () async {
      final uid = await novaConta('lucas@example.com');
      final antes = (await db.doc('users/$uid').get()).data()!;

      final r = await service.criarPerfilDoUsuarioAtual(displayName: 'Lucas Prado', username: 'lucas10');

      expect(r.criado, isFalse);
      expect(r.perfil.username, 'Lucas10', reason: 'devolve o username já gravado');
      final depois = (await db.doc('users/$uid').get()).data()!;
      expect(depois['createdAt'], antes['createdAt']);
      expect(depois['saldoTotal'], 1000);
      expect(await ledgerDe(uid), hasLength(1));
    });

    test('duas chamadas simultâneas do mesmo usuário criam um só perfil e uma só carteira', () async {
      final uid = await novaConta('marina@example.com');

      final rs = await Future.wait([
        service.criarPerfilDoUsuarioAtual(displayName: 'Marina', username: 'marina_r'),
        service.criarPerfilDoUsuarioAtual(displayName: 'Marina', username: 'marina_r'),
      ]);

      expect(rs.where((r) => r.criado), hasLength(1));
      expect(rs.every((r) => r.perfil.uid == uid), isTrue);
      expect((await db.doc('users/$uid').get()).data()!['saldoTotal'], 1000);
      expect(await ledgerDe(uid), hasLength(1));
    });
  });

  group('B - Erros do backend', () {
    test('username de outro usuário, com outra caixa → usernameUnavailable, nada gravado', () async {
      final uid = await novaConta('outro.lucas@example.com');

      await expectLater(
        service.criarPerfilDoUsuarioAtual(displayName: 'Outro Lucas', username: 'LUCAS10'),
        _erro(UserProfileErrorCode.usernameUnavailable),
      );
      expect(await service.carregarPerfilAtual(), isNull);
      expect(await ledgerDe(uid), isEmpty);
    });

    test('usuário que já tem perfil, com outro username → alreadyExists, perfil intacto', () async {
      await novaConta('lucas@example.com');

      await expectLater(
        service.criarPerfilDoUsuarioAtual(displayName: 'Lucas', username: 'outro_nome'),
        _erro(UserProfileErrorCode.alreadyExists),
      );
      expect((await service.carregarPerfilAtual())!.username, 'Lucas10');
    });

    test('nome ou username fora do formato → invalidData', () async {
      await novaConta('formato@example.com');

      for (final (nome, username) in [('Nome', 'ab'), ('Nome', 'com espaço'), ('Nome', 'joão'), ('  ', 'valido_1'), ('a' * 61, 'valido_1')]) {
        await expectLater(
          service.criarPerfilDoUsuarioAtual(displayName: nome, username: username),
          _erro(UserProfileErrorCode.invalidData),
          reason: '$nome / $username',
        );
      }
      expect(await service.carregarPerfilAtual(), isNull);
    });

    test('conta criada no Auth sem perfil (falha na 1ª tentativa) é recuperada ao repetir', () async {
      final uid = await novaConta('recupera@example.com');

      await expectLater(
        service.criarPerfilDoUsuarioAtual(displayName: 'Rita', username: 'r'),
        _erro(UserProfileErrorCode.invalidData),
      );
      expect(await service.carregarPerfilAtual(), isNull, reason: 'conta existe no Auth, sem perfil');

      final r = await service.criarPerfilDoUsuarioAtual(displayName: 'Rita', username: 'rita_c');
      expect(r.criado, isTrue);
      expect((await service.carregarPerfilAtual())!.uid, uid);
      expect(await ledgerDe(uid), hasLength(1));
    });

    test('sem sessão: o serviço recusa sem chamar e o backend responde unauthenticated', () async {
      await auth.signOut();

      await expectLater(
        service.criarPerfilDoUsuarioAtual(displayName: 'Anônimo', username: 'anonimo'),
        _erro(UserProfileErrorCode.unauthenticated),
      );
      // Chamada direta, sem passar pelo serviço: o backend também exige o token
      await expectLater(
        functions.call(CallableNames.createUserProfile, {'displayName': 'Anônimo', 'username': 'anonimo'}),
        throwsA(isA<FunctionsException>().having((e) => e.code, 'code', 'unauthenticated')),
      );
    });

    test('o perfil criado não pode ser alterado nem criado para outro UID pelo cliente', () async {
      final uid = await novaConta('lucas@example.com');

      for (final escrita in [
        () => db.doc('users/$uid').update({'saldoTotal': 5000, 'updatedAt': FieldValue.serverTimestamp()}),
        () => db.doc('users/outroUid').set({'displayName': 'Invasor'}),
        () => db.doc('usernames/invasor').set({'uid': uid}),
        () => db.doc('betCoinTransactions/${uid}_INITIAL_BALANCE').delete(),
      ]) {
        await expectLater(
          escrita(),
          throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
        );
      }
    });
  });

  group('C - Falhas de conexão e de função', () {
    test('Functions inacessível → unavailable, sem exceção não tratada', () async {
      await novaConta('semfunctions@example.com');
      final semFunctions = UserProfileService(
        authService: AuthService(firebaseAuth: auth),
        repository: FirestoreUserProfileRepository(firestore: db),
        functionsService: FunctionsService(
          functions: FirebaseFunctions.instanceFor(app: app, region: 'us-central1')
            // Porta sem nenhum serviço: simula o backend fora do ar
            ..useFunctionsEmulator(_hostEmuladores, 1),
        ),
      );

      await expectLater(
        semFunctions.criarPerfilDoUsuarioAtual(displayName: 'Sem Functions', username: 'sem_functions'),
        _erro(UserProfileErrorCode.unavailable),
      );
      expect(await service.carregarPerfilAtual(), isNull);
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('função inexistente (não implantada) → erro controlado', () async {
      await novaConta('lucas@example.com');

      await expectLater(
        functions.call('funcaoQueNaoExiste'),
        throwsA(isA<FunctionsException>().having((e) => e.code, 'code', 'not-found')),
      );
    });
  });

  group('D - Sem regressão na leitura e na edição', () {
    test('observar e editar o nome do perfil criado pela Callable', () async {
      final uid = await novaConta('lucas@example.com');

      final observado = await service.observarPerfilAtual().first.timeout(const Duration(seconds: 15));
      expect(observado.perfil?.uid, uid);

      await service.atualizarDisplayNameAtual('  Lucas P. ');
      final dados = (await db.doc('users/$uid').get()).data()!;
      expect(dados['displayName'], 'Lucas P.');
      expect(dados['username'], 'Lucas10');
      expect(dados['saldoTotal'], 1000);
      expect(await ledgerDe(uid), hasLength(1));
    });
  });
}
