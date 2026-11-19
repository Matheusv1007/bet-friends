// Validação da jornada completa do MVP contra emuladores de Auth e Firestore (KAN-107).
//
// Exercita o fluxo com as duas contas de demonstração controladas:
// - Ana Lima (uidAna, ana@example.com, @AnaL)
// - Bia Rocha (uidBia, bia@example.com, @BiaR)
//
// Como executar:
//   npm --prefix functions run emulators:exec -- \
//     flutter test integration_test/jornada_mvp_emulator_test.dart -d <device-id>

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _hostEmuladores = '10.0.2.2';
const _senha = 'senha-emulador-123';

const _opcoesDemo = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-betfriends',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  late UserProfileService profileService;

  setUpAll(() async {
    final app = await Firebase.initializeApp(
      name: 'kan107-jornada-emulador',
      options: _opcoesDemo,
    );
    expect(app.options.projectId, startsWith('demo-'));

    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(_hostEmuladores, 9099);

    firestore = FirebaseFirestore.instanceFor(app: app)
      ..settings = const Settings(persistenceEnabled: false);
    firestore.useFirestoreEmulator(_hostEmuladores, 8080);

    final authService = AuthService(firebaseAuth: auth);
    final repo = FirestoreUserProfileRepository(firestore: firestore);
    profileService = UserProfileService(authService: authService, repository: repo);
  });

  tearDown(() async {
    await auth.signOut();
  });

  group('Jornada MVP contra Emuladores (KAN-107)', () {
    test('Conta 1 (Ana Lima) - Autenticação, perfil e carteira com isolamento de dados', () async {
      // 1. Login no Auth Emulator
      final cred = await auth.signInWithEmailAndPassword(
        email: 'ana@example.com',
        password: _senha,
      );
      expect(cred.user?.uid, 'uidAna');

      // 2. Leitura do perfil e carteira via Security Rules
      final perfilObservado = await profileService.observarPerfilAtual().first;
      expect(perfilObservado.perfil?.displayName, 'Ana Lima');
      expect(perfilObservado.perfil?.username, 'AnaL');
      expect(perfilObservado.perfil?.email, 'ana@example.com');
      expect(perfilObservado.carteira?.saldoTotal, 1000);
      expect(perfilObservado.carteira?.saldoReservado, 0);
      expect(perfilObservado.carteira?.saldoDisponivel, 1000);

      // 3. Regra de segurança: Ana não pode ler a carteira privada de Bia diretamente
      final docBia = firestore.collection('users').doc('uidBia');
      expect(
        () => docBia.get(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );

      // 4. Logout seguro
      await auth.signOut();
      expect(auth.currentUser, isNull);
    });

    test('Conta 2 (Bia Rocha) - Autenticação, perfil e integridade de saldo após logout de Ana', () async {
      // 1. Login de Bia no Auth Emulator
      final cred = await auth.signInWithEmailAndPassword(
        email: 'bia@example.com',
        password: _senha,
      );
      expect(cred.user?.uid, 'uidBia');

      // 2. Leitura do perfil e carteira de Bia
      final perfilObservado = await profileService.observarPerfilAtual().first;
      expect(perfilObservado.perfil?.displayName, 'Bia Rocha');
      expect(perfilObservado.perfil?.username, 'BiaR');
      expect(perfilObservado.carteira?.saldoTotal, 1000);
      expect(perfilObservado.carteira?.saldoReservado, 0);
      expect(perfilObservado.carteira?.saldoDisponivel, 1000);

      // 3. Regra de segurança: Bia não pode ler os dados privados de Ana
      final docAna = firestore.collection('users').doc('uidAna');
      expect(
        () => docAna.get(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );

      // 4. Logout
      await auth.signOut();
      expect(auth.currentUser, isNull);
    });

    test('Sessão encerrada bloqueia acesso a qualquer perfil sem autenticação', () async {
      expect(auth.currentUser, isNull);

      expect(
        () => profileService.observarPerfilAtual(),
        throwsA(isA<UserProfileException>().having(
          (e) => e.code,
          'code',
          UserProfileErrorCode.unauthenticated,
        )),
      );
    });
  });
}
