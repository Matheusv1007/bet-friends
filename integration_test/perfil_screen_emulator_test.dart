// Tela de perfil (KAN-28) contra os emuladores de Auth e Firestore e as
// Security Rules reais. Mesmo ambiente de user_profile_emulator_test.dart:
// FirebaseApp separado no projeto demo-betfriends e dados criados por
// integration_test/support/seed_emulators.mjs. Ver integration_test/README.md.

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

/// Bombeia frames até [finder] aparecer: a tela tem animação contínua de
/// carregamento, então pumpAndSettle não serve. Se [nuncaExibir] for
/// informado, falha caso ele apareça em qualquer frame intermediário.
Future<void> aguardar(WidgetTester tester, Finder finder, {Finder? nuncaExibir}) async {
  final limite = DateTime.now().add(const Duration(seconds: 60));
  while (finder.evaluate().isEmpty) {
    if (nuncaExibir != null && nuncaExibir.evaluate().isNotEmpty) {
      fail('Exibiu $nuncaExibir antes de $finder');
    }
    if (DateTime.now().isAfter(limite)) {
      final textos = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join(' | ');
      final carregando = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      fail('Tempo esgotado aguardando $finder. Tela: [$textos] carregando=$carregando');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late UserProfileService service;

  setUpAll(() async {
    final app = await Firebase.initializeApp(name: 'kan28-emulador', options: _opcoesDemo);
    expect(app.options.projectId, startsWith('demo-'));

    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(_hostEmuladores, 9099);

    final db = FirebaseFirestore.instanceFor(app: app)
      ..settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator(_hostEmuladores, 8080);

    service = UserProfileService(
      authService: AuthService(firebaseAuth: auth),
      repository: FirestoreUserProfileRepository(firestore: db),
    );
  });

  tearDownAll(() => auth.signOut());

  Future<void> abrirPerfil(WidgetTester tester, UserProfileService service) async {
    await tester.pumpWidget(
      Provider<UserProfileService>.value(
        value: service,
        child: const MaterialApp(home: PerfilScreen()),
      ),
    );
  }

  testWidgets('exibe nome e username reais de users/{uid} do usuário logado, sem e-mail nem saldos',
      (tester) async {
    await auth.signInWithEmailAndPassword(email: 'bia@example.com', password: _senha);
    expect(auth.currentUser!.uid, 'uidBia');

    await abrirPerfil(tester, service);
    await aguardar(tester, find.byKey(const Key('perfil_display_name')));

    expect(tester.widget<Text>(find.byKey(const Key('perfil_display_name'))).data, 'Bia Rocha');
    expect(tester.widget<Text>(find.byKey(const Key('perfil_username'))).data, '@BiaR');
    for (final texto in ['bia@example.com', 'uidBia', '1000', 'saldo', 'fichas']) {
      expect(find.textContaining(texto), findsNothing, reason: texto);
    }
  });

  testWidgets('usuário sem documento de perfil vê o aviso de perfil não criado', (tester) async {
    await auth.signOut();
    await auth.signInWithEmailAndPassword(email: 'semperfil@example.com', password: _senha);

    await abrirPerfil(tester, service);
    // Com conexão, a ausência confirmada pelo servidor não pode passar por erro de conexão
    await aguardar(
      tester,
      find.text('Perfil ainda não criado'),
      nuncaExibir: find.text('Não foi possível carregar o perfil'),
    );
  });

  testWidgets('documento fora do schema mostra mensagem de dados incompletos', (tester) async {
    await auth.signOut();
    await auth.signInWithEmailAndPassword(email: 'invalido@example.com', password: _senha);

    await abrirPerfil(tester, service);
    await aguardar(tester, find.textContaining('incompletos'));
  });

  testWidgets('sem sessão mostra aviso de sessão expirada', (tester) async {
    await auth.signOut();

    await abrirPerfil(tester, service);
    await aguardar(tester, find.textContaining('sessão expirou'));
  });

  testWidgets('Firestore inacessível mostra erro de conexão com opção de tentar novamente',
      (tester) async {
    await auth.signInWithEmailAndPassword(email: 'bia@example.com', password: _senha);

    final offline = await Firebase.initializeApp(name: 'kan28-offline', options: _opcoesDemo);
    final dbOffline = FirebaseFirestore.instanceFor(app: offline)
      ..settings = const Settings(persistenceEnabled: false);
    dbOffline.useFirestoreEmulator(_hostEmuladores, 1); // porta sem serviço

    final serviceOffline = UserProfileService(
      authService: AuthService(firebaseAuth: auth),
      repository: FirestoreUserProfileRepository(firestore: dbOffline),
    );

    await abrirPerfil(tester, serviceOffline);
    await aguardar(tester, find.textContaining('Sem conexão'));
    expect(find.text('TENTAR NOVAMENTE'), findsOneWidget);
  });
}
