// Integração da KAN-32 com os emuladores de Auth e Firestore e com as
// Security Rules reais (firestore.rules).
//
// Roda num dispositivo Android (emulador) com um FirebaseApp separado,
// configurado para o projeto fictício demo-betfriends e apontado para os
// emuladores do host (10.0.2.2). O app padrão, ligado ao projeto real, nem é
// inicializado. Os dados são criados por integration_test/support/seed_emulators.mjs.
// Como executar: integration_test/README.md.

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _projeto = 'demo-betfriends';
const _hostEmuladores = '10.0.2.2'; // localhost do host visto pelo emulador Android
const _portaAuth = 9099;
const _portaFirestore = 8080;

// Contas que existem só no Auth Emulator (seed_emulators.mjs)
const _senha = 'senha-emulador-123';
const _anaEmail = 'ana@example.com';
const _semPerfilEmail = 'semperfil@example.com';
const _invalidoEmail = 'invalido@example.com';

const _opcoesDemo = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: _projeto,
);

Matcher _erro(UserProfileErrorCode code) =>
    throwsA(isA<UserProfileException>().having((e) => e.code, 'code', code));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore db;
  late FirestoreUserProfileRepository repository;
  late UserProfileService service;

  Future<void> entrar(String email) async {
    await auth.signOut();
    await auth.signInWithEmailAndPassword(email: email, password: _senha);
  }

  setUpAll(() async {
    final app = await Firebase.initializeApp(name: 'kan32-emulador', options: _opcoesDemo);
    // Falha segura: nunca usar o projeto real
    expect(app.options.projectId, startsWith('demo-'));

    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(_hostEmuladores, _portaAuth);

    db = FirebaseFirestore.instanceFor(app: app);
    // Sem cache local: toda leitura vai ao emulador e passa pelas rules
    db.settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator(_hostEmuladores, _portaFirestore);

    repository = FirestoreUserProfileRepository(firestore: db);
    service = UserProfileService(
      authService: AuthService(firebaseAuth: auth),
      repository: repository,
    );
  });

  tearDownAll(() => auth.signOut());

  group('A - Identidade', () {
    test('o perfil é users/{uid} do usuário autenticado, não o username nem o e-mail', () async {
      await entrar(_anaEmail);
      final uid = auth.currentUser!.uid;

      final perfil = await service.carregarPerfilAtual();

      expect(uid, 'uidAna');
      expect(perfil!.uid, uid);
      expect(perfil.uid, isNot(perfil.username));
      expect(perfil.uid, isNot(perfil.email));

      final snapshot = await db.doc('users/$uid').get();
      expect(snapshot.reference.path, 'users/uidAna');
      expect(snapshot.data()!.containsKey('uid'), isFalse);
    });

    test('o modelo interpreta o documento completo do schema v2.0 (com carteira)', () async {
      await entrar(_anaEmail);
      final perfil = (await service.carregarPerfilAtual())!;

      expect(perfil.displayName, isNotEmpty);
      expect(perfil.username, 'AnaL');
      expect(perfil.usernameNormalized, 'anal');
      expect(perfil.email, _anaEmail);
      expect(perfil.createdAt, DateTime.utc(2026, 10, 28, 12));
      expect(perfil.createdAt!.isUtc, isTrue);

      // Campos financeiros existem no documento, mas não fazem parte do modelo
      final dados = (await db.doc('users/uidAna').get()).data()!;
      expect(dados['saldoTotal'], 1000);
      expect(dados['saldoReservado'], 0);
    });
  });

  group('B - Leitura', () {
    test('perfil inexistente retorna null, sem erro', () async {
      await entrar(_semPerfilEmail);
      expect(await service.carregarPerfilAtual(), isNull);
    });

    test('observarPerfilAtual emite o próprio perfil', () async {
      await entrar(_anaEmail);
      final perfil = await service.observarPerfilAtual().first.timeout(const Duration(seconds: 15));
      expect(perfil.perfil?.uid, 'uidAna');
    });

    test('ler o perfil de outro UID resulta em permissionDenied', () async {
      await entrar(_anaEmail);
      await expectLater(repository.buscarPorUid('uidBia'), _erro(UserProfileErrorCode.permissionDenied));
    });

    test('observar o perfil de outro UID emite permissionDenied', () async {
      await entrar(_anaEmail);
      await expectLater(
        repository.observarPorUid('uidBia').first.timeout(const Duration(seconds: 15)),
        _erro(UserProfileErrorCode.permissionDenied),
      );
    });
  });

  group('C - Atualização', () {
    test('displayName válido é persistido com updatedAt do servidor', () async {
      await entrar(_anaEmail);
      final antes = (await db.doc('users/uidAna').get()).data()!;

      await service.atualizarDisplayNameAtual('  Ana Souza  ');

      final depois = (await db.doc('users/uidAna').get()).data()!;
      expect(depois['displayName'], 'Ana Souza');
      final updatedAt = (depois['updatedAt'] as Timestamp).toDate();
      expect(updatedAt.isAfter((antes['updatedAt'] as Timestamp).toDate()), isTrue);
      expect(updatedAt.difference(DateTime.now()).inMinutes.abs(), lessThan(5));

      // UID, username, e-mail e saldos não mudam
      for (final campo in ['username', 'usernameNormalized', 'email', 'saldoTotal', 'saldoReservado', 'createdAt']) {
        expect(depois[campo], antes[campo], reason: campo);
      }
      expect((await service.carregarPerfilAtual())!.displayName, 'Ana Souza');
    });

    test('nome inválido é recusado pelo serviço antes de gravar', () async {
      await entrar(_anaEmail);
      final nomeAtual = (await db.doc('users/uidAna').get()).data()!['displayName'];

      for (final invalido in ['', '   ', 'a' * 61]) {
        await expectLater(service.atualizarDisplayNameAtual(invalido), _erro(UserProfileErrorCode.invalidData));
      }
      expect((await db.doc('users/uidAna').get()).data()!['displayName'], nomeAtual);
    });

    test('nome inválido gravado direto pelo repositório é bloqueado pelas rules', () async {
      await entrar(_anaEmail);
      await expectLater(repository.atualizarDisplayName('uidAna', ' Ana '), _erro(UserProfileErrorCode.permissionDenied));
      await expectLater(repository.atualizarDisplayName('uidAna', 'a' * 61), _erro(UserProfileErrorCode.permissionDenied));
    });

    test('não altera o displayName de outro UID', () async {
      await entrar(_anaEmail);
      await expectLater(repository.atualizarDisplayName('uidBia', 'Invasão'), _erro(UserProfileErrorCode.permissionDenied));
    });

    test('o cliente não altera username, e-mail, uid nem saldos (SDK direto)', () async {
      await entrar(_anaEmail);
      final ref = db.doc('users/uidAna');

      for (final alteracao in <Map<String, Object>>[
        {'username': 'Outra'},
        {'usernameNormalized': 'outra'},
        {'email': 'outra@example.com'},
        {'uid': 'uidBia'},
        {'saldoTotal': 999999},
        {'saldoReservado': 50},
        {'displayName': 'Ana', 'saldoTotal': 999999},
      ]) {
        await expectLater(
          ref.update({...alteracao, 'updatedAt': FieldValue.serverTimestamp()}),
          throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
          reason: '$alteracao',
        );
      }
      expect((await ref.get()).data()!['saldoTotal'], 1000);
    });
  });

  group('D - Criação', () {
    test('criarPerfilDoUsuarioAtual é bloqueado pelas rules e nada é gravado', () async {
      await entrar(_semPerfilEmail);

      await expectLater(
        service.criarPerfilDoUsuarioAtual(
          displayName: 'Sem Perfil',
          username: 'semperfil',
          usernameNormalized: 'semperfil',
        ),
        _erro(UserProfileErrorCode.permissionDenied),
      );
      expect(await service.carregarPerfilAtual(), isNull);
    });

    test('perfil criado pelo Admin SDK (seed) é lido normalmente pelo app', () async {
      await entrar(_anaEmail);
      expect(await service.carregarPerfilAtual(), isA<UserProfile>());
    });
  });

  group('E - Erros e conectividade', () {
    test('documento fora do schema resulta em invalidData', () async {
      await entrar(_invalidoEmail);
      await expectLater(service.carregarPerfilAtual(), _erro(UserProfileErrorCode.invalidData));
    });

    test('sem sessão, o serviço recusa sem acessar o Firestore', () async {
      await auth.signOut();
      expect(service.carregarPerfilAtual, _erro(UserProfileErrorCode.unauthenticated));
      await expectLater(service.atualizarDisplayNameAtual('Nome'), _erro(UserProfileErrorCode.unauthenticated));
    });

    test('sem sessão, o acesso direto pelo repositório é negado pelas rules', () async {
      await auth.signOut();
      await expectLater(repository.buscarPorUid('uidAna'), _erro(UserProfileErrorCode.permissionDenied));
    });

    test('Firestore inacessível resulta em unavailable, sem exceção não tratada', () async {
      final offline = await Firebase.initializeApp(name: 'kan32-offline', options: _opcoesDemo);
      final dbOffline = FirebaseFirestore.instanceFor(app: offline)
        ..settings = const Settings(persistenceEnabled: false);
      // Porta sem nenhum serviço: simula o backend fora do ar
      dbOffline.useFirestoreEmulator(_hostEmuladores, 1);

      final repositoryOffline = FirestoreUserProfileRepository(firestore: dbOffline);
      await expectLater(repositoryOffline.buscarPorUid('uidAna'), _erro(UserProfileErrorCode.unavailable));

      // O listener emite o cache vazio; isso não pode virar "perfil inexistente"
      await expectLater(
        repositoryOffline.observarPorUid('uidAna').first.timeout(const Duration(seconds: 60)),
        _erro(UserProfileErrorCode.unavailable),
      );
    }, timeout: const Timeout(Duration(seconds: 120)));
  });
}
