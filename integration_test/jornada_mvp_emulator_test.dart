// Autenticação, perfil, privacidade e amigos públicos nos emuladores (KAN-107).
//
// Exercita o fluxo com as duas contas de demonstração controladas:
// - Ana Lima (uidAnaJornada, ana.jornada@example.com, @AnaJornada)
// - Bia Rocha (uidBiaJornada, bia.jornada@example.com, @BiaJornada)
//
// Como executar:
//   flock /tmp/betfriends-emulator.lock npx firebase-tools@15.32.1 \
//     emulators:exec --only auth,firestore,functions --project demo-betfriends \
//     'node integration_test/support/seed_emulators.mjs && flutter test integration_test/jornada_mvp_emulator_test.dart -d <device-id>'

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/data/firestore/challenge_repository.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  apiKey: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-betfriends',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  late UserProfileService profileService;
  late FunctionsChallengeRepository challenges;

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

    final functions = FirebaseFunctions.instanceFor(app: app, region: kFunctionsRegion);
    functions.useFunctionsEmulator(_hostEmuladores, 5001);
    challenges = FunctionsChallengeRepository(
      firestore: firestore, functions: FunctionsService(functions: functions),
    );
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
        email: 'ana.jornada@example.com',
        password: _senha,
      );
      expect(cred.user?.uid, 'uidAnaJornada');

      // 2. Leitura do perfil e carteira via Security Rules
      final perfilObservado = await profileService.observarPerfilAtual().first;
      expect(perfilObservado.perfil?.displayName, 'Ana Lima');
      expect(perfilObservado.perfil?.username, 'AnaJornada');
      expect(perfilObservado.perfil?.email, 'ana.jornada@example.com');
      expect(perfilObservado.carteira?.saldoTotal, 1000);
      expect(perfilObservado.carteira?.saldoReservado, 0);
      expect(perfilObservado.carteira?.saldoDisponivel, 1000);

      // N-02: o repositório real usa getFriends, sem ler users do amigo.
      final amigos = await challenges.listarAmigosAceitos('uidAnaJornada');
      expect(amigos.single.uid, 'uidBiaJornada');
      expect(amigos.single.displayName, 'Bia Rocha');
      expect(amigos.single.username, 'BiaJornada');

      // 3. Regra de segurança: Ana não pode ler a carteira privada de Bia diretamente
      final docBia = firestore.collection('users').doc('uidBiaJornada');
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
        email: 'bia.jornada@example.com',
        password: _senha,
      );
      expect(cred.user?.uid, 'uidBiaJornada');

      // 2. Leitura do perfil e carteira de Bia
      final perfilObservado = await profileService.observarPerfilAtual().first;
      expect(perfilObservado.perfil?.displayName, 'Bia Rocha');
      expect(perfilObservado.perfil?.username, 'BiaJornada');
      expect(perfilObservado.carteira?.saldoTotal, 1000);
      expect(perfilObservado.carteira?.saldoReservado, 0);
      expect(perfilObservado.carteira?.saldoDisponivel, 1000);

      // 3. Regra de segurança: Bia não pode ler os dados privados de Ana
      final docAna = firestore.collection('users').doc('uidAnaJornada');
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
