// Edição do nome de exibição (KAN-29) contra os emuladores de Auth e
// Firestore e as Security Rules reais. Mesmo ambiente dos outros testes de
// integration_test/ (projeto demo-betfriends; seed com Admin SDK). Usa a conta
// uidCaio, que nenhum outro teste altera. Ver integration_test/README.md.

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

const _hostEmuladores = '10.0.2.2';
const _senha = 'senha-emulador-123';

const _opcoesDemo = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-betfriends',
);

/// Bombeia frames até [finder] aparecer (há animações contínuas na tela).
Future<void> aguardar(WidgetTester tester, Finder finder, {int segundos = 60}) async {
  final limite = DateTime.now().add(Duration(seconds: segundos));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(limite)) {
      final textos = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join(' | ');
      fail('Tempo esgotado aguardando $finder. Tela: [$textos]');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore db;

  setUpAll(() async {
    final app = await Firebase.initializeApp(name: 'kan29-emulador', options: _opcoesDemo);
    expect(app.options.projectId, startsWith('demo-'));

    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(_hostEmuladores, 9099);

    db = FirebaseFirestore.instanceFor(app: app)
      ..settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator(_hostEmuladores, 8080);

    await auth.signInWithEmailAndPassword(email: 'caio@example.com', password: _senha);
    expect(auth.currentUser!.uid, 'uidCaio');
  });

  tearDownAll(() => auth.signOut());

  Future<void> abrirPerfil(WidgetTester tester, FirebaseFirestore firestore) async {
    await tester.pumpWidget(
      Provider<UserProfileService>.value(
        value: UserProfileService(
          authService: AuthService(firebaseAuth: auth),
          repository: FirestoreUserProfileRepository(firestore: firestore),
        ),
        child: const MaterialApp(home: PerfilScreen()),
      ),
    );
  }

  testWidgets('edição pela tela persiste só displayName e atualiza a exibição', (tester) async {
    final antes = (await db.doc('users/uidCaio').get()).data()!;

    await abrirPerfil(tester, db);
    await aguardar(tester, find.byKey(const Key('perfil_editar_nome')));
    await tester.tap(find.byKey(const Key('perfil_editar_nome')));
    await tester.pump(const Duration(milliseconds: 500));

    final campo = tester.widget<TextFormField>(find.byKey(const Key('editar_nome_campo')));
    expect(campo.controller!.text, 'Caio Melo');

    await tester.enterText(find.byKey(const Key('editar_nome_campo')), '  Caio Mendes  ');
    await tester.tap(find.byKey(const Key('editar_nome_salvar')));
    await aguardar(tester, find.text('Nome de exibição atualizado.'));
    await aguardar(tester, find.text('Caio Mendes'));
    expect(tester.widget<Text>(find.byKey(const Key('perfil_display_name'))).data, 'Caio Mendes');
    expect(find.text('@CaioM'), findsOneWidget);

    final depois = (await db.doc('users/uidCaio').get()).data()!;
    expect(depois['displayName'], 'Caio Mendes');
    for (final campo in ['username', 'usernameNormalized', 'email', 'saldoTotal', 'saldoReservado', 'createdAt']) {
      expect(depois[campo], antes[campo], reason: campo);
    }
    expect(
      (depois['updatedAt'] as Timestamp).toDate().isAfter((antes['updatedAt'] as Timestamp).toDate()),
      isTrue,
    );
  });

  testWidgets('sem conexão, salvar informa a falha em tempo finito e não grava', (tester) async {
    // Perfil carregado com conexão; a gravação sai por uma instância sem servidor
    final offline = await Firebase.initializeApp(name: 'kan29-offline', options: _opcoesDemo);
    final dbOffline = FirebaseFirestore.instanceFor(app: offline)
      ..settings = const Settings(persistenceEnabled: false);
    dbOffline.useFirestoreEmulator(_hostEmuladores, 1);

    final repositorioOffline = FirestoreUserProfileRepository(firestore: dbOffline);
    await expectLater(
      repositorioOffline.atualizarDisplayName('uidCaio', 'Nome Offline').timeout(const Duration(seconds: 45)),
      throwsA(isA<UserProfileException>().having((e) => e.code, 'code', UserProfileErrorCode.unavailable)),
    );

    expect((await db.doc('users/uidCaio').get()).data()!['displayName'], isNot('Nome Offline'));
  }, timeout: const Timeout(Duration(seconds: 90)));

  testWidgets('a edição não alcança o perfil de outro UID', (tester) async {
    await expectLater(
      FirestoreUserProfileRepository(firestore: db).atualizarDisplayName('uidBia', 'Invasão'),
      throwsA(isA<UserProfileException>().having((e) => e.code, 'code', UserProfileErrorCode.permissionDenied)),
    );
    // O perfil da Bia não é legível pela sessão do Caio; o conteúdo é conferido no seed/rules
  });
}
