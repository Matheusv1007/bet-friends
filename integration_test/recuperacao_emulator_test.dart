// Recuperação de BetCoins (KAN-80) pela Callable claimRecoveryBonus, chamada
// do Android pelo FunctionsService (HTTP do Functions Emulator), com Auth e
// Firestore Emulator e as Security Rules reais. Não há tela: a interface é
// da KAN-71.
//
// Roda num dispositivo Android (emulador) com um FirebaseApp separado,
// configurado para o projeto fictício demo-betfriends. Conta `uidEva` criada
// por support/seed_emulators.mjs com 5 BetCoins e sem reserva.
// Como executar: integration_test/README.md.

import 'package:betfriends/services/functions/functions_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _projeto = 'demo-betfriends';
const _hostEmuladores = '10.0.2.2'; // localhost do host visto pelo emulador Android

// Senha de contas que existem só no emulador (seed_emulators.mjs)
const _senha = 'senha-emulador-123';

const _opcoesDemo = FirebaseOptions(
  // Chave fictícia no formato do Firebase (ver criar_perfil_emulator_test.dart).
  // Não é credencial.
  apiKey: 'Ademo-betfriends-emulador-0000000000000',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: _projeto,
);

Matcher _recusa(String code, [String? motivo]) => throwsA(isA<FunctionsException>()
    .having((e) => e.code, 'code', code)
    .having((e) => e.motivo, 'motivo', motivo));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore db;
  late FunctionsService functions;

  Future<void> entrar(String email) async {
    await auth.signOut();
    await auth.signInWithEmailAndPassword(email: email, password: _senha);
  }

  setUpAll(() async {
    final app = await Firebase.initializeApp(name: 'kan80-recuperacao', options: _opcoesDemo);
    // Falha segura: nunca usar o projeto real
    expect(app.options.projectId, startsWith('demo-'));

    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(_hostEmuladores, 9099);
    db = FirebaseFirestore.instanceFor(app: app)
      ..settings = const Settings(persistenceEnabled: false)
      ..useFirestoreEmulator(_hostEmuladores, 8080);
    functions = FunctionsService(
      functions: FirebaseFunctions.instanceFor(app: app, region: kFunctionsRegion)
        ..useFunctionsEmulator(_hostEmuladores, 5001),
    );
  });

  tearDownAll(() => auth.signOut());

  test('sem sessão → unauthenticated', () async {
    await auth.signOut();
    await expectLater(functions.call(CallableNames.claimRecoveryBonus), _recusa('unauthenticated'));
  });

  test('elegível: +100, transação no extrato e o app não consegue alterar o resultado', () async {
    await entrar('eva@example.com');

    // Payload com outro usuário e outro valor é ignorado pelo backend
    final r = await functions.call(CallableNames.claimRecoveryBonus, {'userId': 'uidAna', 'amount': 1000});

    expect(r['amount'], 100);
    expect(r['saldoTotal'], 105);
    expect(r['saldoReservado'], 0);
    expect(r['saldoDisponivel'], 105);
    final id = r['transacaoId'] as String;
    expect(id, startsWith('uidEva_RECOVERY_BONUS_'));

    final usuario = (await db.doc('users/uidEva').get()).data()!;
    expect(usuario['saldoTotal'], 105);
    expect(usuario['lastRecoveryBonusAt'], isA<Timestamp>());
    final t = (await db.doc('betCoinTransactions/$id').get()).data()!;
    expect(t['type'], 'RECOVERY_BONUS');
    expect(t['amount'], 100);
    expect((await db.doc('users/uidAna').get().then((_) => 'lido', onError: (_) => 'negado')), 'negado',
        reason: 'o app continua sem ler a carteira de terceiros');

    // O cliente não grava saldo, lastRecoveryBonusAt nem transações (rules)
    for (final escrita in [
      () => db.doc('users/uidEva').update({'lastRecoveryBonusAt': null, 'updatedAt': FieldValue.serverTimestamp()}),
      () => db.doc('users/uidEva').update({'saldoTotal': 5, 'updatedAt': FieldValue.serverTimestamp()}),
      () => db.doc('betCoinTransactions/uidEva_RECOVERY_BONUS_manual').set({'userId': 'uidEva', 'type': 'RECOVERY_BONUS', 'amount': 100}),
      () => db.doc('betCoinTransactions/$id').delete(),
    ]) {
      await expectLater(
        escrita(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
    }
  });

  test('repetir logo depois é negado, sem novo bônus', () async {
    await entrar('eva@example.com');

    await expectLater(functions.call(CallableNames.claimRecoveryBonus), _recusa('failed-precondition', 'saldo-suficiente'));

    final bonus = await db
        .collection('betCoinTransactions')
        .where('userId', isEqualTo: 'uidEva')
        .get();
    expect(bonus.docs.where((d) => d.data()['type'] == 'RECOVERY_BONUS'), hasLength(1));
    expect((await db.doc('users/uidEva').get()).data()!['saldoTotal'], 105);
  });

  test('usuário com saldo (1.000) e usuário sem perfil são negados com o motivo', () async {
    await entrar('bia@example.com');
    await expectLater(functions.call(CallableNames.claimRecoveryBonus), _recusa('failed-precondition', 'saldo-suficiente'));

    await entrar('semperfil@example.com');
    await expectLater(functions.call(CallableNames.claimRecoveryBonus), _recusa('failed-precondition', 'perfil-inexistente'));
  });
}
