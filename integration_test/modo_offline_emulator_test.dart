// Modo offline seguro (KAN-24) contra os emuladores de Auth e Firestore e as
// Security Rules reais. Mesmo ambiente dos outros testes de integration_test/
// (projeto demo-betfriends; seed com Admin SDK). Usa a conta uidDani, que
// nenhum outro teste altera.
//
// O Firestore do app passa por support/proxy_conexao.mjs, que derruba e
// restabelece a conexão de verdade, com o cache persistente ligado como no
// app. Ver integration_test/README.md.

import 'dart:io';

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
const _portaProxy = 8180;
const _portaControle = 8181;
const _senha = 'senha-emulador-123';
const _nomeOriginal = 'Dani Souza';

const _opcoesDemo = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-betfriends',
);

final _semConexao = throwsA(
  isA<UserProfileException>().having((e) => e.code, 'code', UserProfileErrorCode.unavailable),
);

/// Liga ou derruba a conexão entre o app e o Firestore Emulator.
Future<void> conexao({required bool online}) async {
  final cliente = HttpClient();
  try {
    final req = await cliente.get(_hostEmuladores, _portaControle, online ? '/online' : '/offline');
    final res = await req.close();
    expect(res.statusCode, 200);
    await res.drain<void>();
  } finally {
    cliente.close();
  }
}

/// Bombeia frames até [finder] atingir [esperado] (há animações contínuas).
Future<void> aguardar(
  WidgetTester tester,
  Finder finder, {
  Matcher esperado = findsWidgets,
  int segundos = 60,
}) async {
  final limite = DateTime.now().add(Duration(seconds: segundos));
  while (!esperado.matches(finder, {})) {
    if (DateTime.now().isAfter(limite)) {
      final textos = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join(' | ');
      fail('Tempo esgotado aguardando $finder ($esperado). Tela: [$textos]');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<FirebaseAuth> _entrar(FirebaseApp app) async {
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(_hostEmuladores, 9099);
  await auth.signInWithEmailAndPassword(email: 'dani@example.com', password: _senha);
  expect(auth.currentUser!.uid, 'uidDani');
  return auth;
}

/// Firestore do app atrás do proxy, com cache persistente vazio.
Future<FirebaseFirestore> _firestorePeloProxy(FirebaseApp app) async {
  final db = FirebaseFirestore.instanceFor(app: app)
    ..useFirestoreEmulator(_hostEmuladores, _portaProxy);
  await db.clearPersistence();
  return db;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore db;
  late FirestoreUserProfileRepository repository;
  late UserProfileService service;

  /// Instância sem proxy, sempre online, só para conferir o servidor.
  late FirebaseFirestore servidor;

  Future<String> nomeNoServidor() async =>
      (await servidor.doc('users/uidDani').get(const GetOptions(source: Source.server)))
          .data()!['displayName'] as String;

  /// Espera o perfil chegar confirmado pelo servidor (ou vindo do cache).
  Future<PerfilObservado> perfilObservado({required bool doCache}) => repository
      .observarPorUid('uidDani')
      .firstWhere((p) => p.doCache == doCache)
      .timeout(const Duration(seconds: 90));

  setUpAll(() async {
    final app = await Firebase.initializeApp(name: 'kan24-app', options: _opcoesDemo);
    expect(app.options.projectId, startsWith('demo-'));
    auth = await _entrar(app);
    db = await _firestorePeloProxy(app);

    final appServidor = await Firebase.initializeApp(name: 'kan24-servidor', options: _opcoesDemo);
    await _entrar(appServidor);
    servidor = FirebaseFirestore.instanceFor(app: appServidor)
      ..settings = const Settings(persistenceEnabled: false);
    servidor.useFirestoreEmulator(_hostEmuladores, 8080);

    repository = FirestoreUserProfileRepository(firestore: db);
    service = UserProfileService(authService: AuthService(firebaseAuth: auth), repository: repository);
    await conexao(online: true);
  });

  tearDown(() => conexao(online: true));

  tearDownAll(() => auth.signOut());

  group('repositório', () {
    test('offline sem cache: leitura informa unavailable, sem "perfil inexistente"', () async {
      final app = await Firebase.initializeApp(name: 'kan24-sem-cache', options: _opcoesDemo);
      await _entrar(app);
      final vazio = FirestoreUserProfileRepository(firestore: await _firestorePeloProxy(app));
      await conexao(online: false);

      await expectLater(vazio.buscarPorUid('uidDani').timeout(const Duration(seconds: 60)), _semConexao);
      await expectLater(vazio.observarPorUid('uidDani').first.timeout(const Duration(seconds: 60)), _semConexao);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('online: o perfil vem confirmado pelo servidor', () async {
      final observado = await perfilObservado(doCache: false);
      expect(observado.perfil!.displayName, _nomeOriginal);
    });

    test('offline com cache: consulta o último perfil conhecido, marcado como do cache', () async {
      await perfilObservado(doCache: false);
      await conexao(online: false);

      final observado = await perfilObservado(doCache: true);
      expect(observado.perfil!.displayName, _nomeOriginal);
      expect(observado.perfil!.username, 'DaniS');
      final perfil = await service.carregarPerfilAtual().timeout(const Duration(seconds: 60));
      expect(perfil!.displayName, _nomeOriginal);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('alterar o perfil offline falha, preserva os dados e nada é gravado depois', () async {
      final emissoes = <PerfilObservado>[];
      final sub = repository.observarPorUid('uidDani').listen(emissoes.add);
      await perfilObservado(doCache: false);
      await conexao(online: false);

      final inicio = DateTime.now();
      await expectLater(service.atualizarDisplayNameAtual('Nome Offline'), _semConexao);
      final duracao = DateTime.now().difference(inicio);
      debugPrint('[KAN-24] gravação offline falhou em ${duracao.inMilliseconds} ms');
      expect(duracao, lessThan(const Duration(seconds: 30)));

      // O cache local não recebeu a alteração e não há nada na fila
      final noCache = await db.doc('users/uidDani').get(const GetOptions(source: Source.cache));
      expect(noCache.data()!['displayName'], _nomeOriginal);
      expect(noCache.metadata.hasPendingWrites, isFalse);

      // A conexão volta: nada é enviado sozinho
      await conexao(online: true);
      await perfilObservado(doCache: false);
      await db.waitForPendingWrites().timeout(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(await nomeNoServidor(), _nomeOriginal);
      expect(emissoes.map((e) => e.perfil?.displayName), everyElement(_nomeOriginal));
      await sub.cancel();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('retorno da conexão: o dado volta a ser do servidor e uma nova ação grava', () async {
      await perfilObservado(doCache: false);
      await conexao(online: false);
      await perfilObservado(doCache: true);

      await conexao(online: true);
      final observado = await perfilObservado(doCache: false);
      expect(observado.perfil!.displayName, _nomeOriginal);

      await service.atualizarDisplayNameAtual('Dani Reconectada');
      expect(await nomeNoServidor(), 'Dani Reconectada');
      await service.atualizarDisplayNameAtual(_nomeOriginal);
      expect(await nomeNoServidor(), _nomeOriginal);
    }, timeout: const Timeout(Duration(minutes: 3)));

    // Mostra o comportamento do SDK que motivou gravarNoServidor: um update
    // direto offline vira escrita pendente e é enviado sozinho ao reconectar.
    test('controle: update direto offline seria gravado depois, sem nova ação', () async {
      await perfilObservado(doCache: false);
      await conexao(online: false);
      await perfilObservado(doCache: true);

      addTearDown(() async {
        await conexao(online: true);
        await service.atualizarDisplayNameAtual(_nomeOriginal);
      });

      final ref = db.doc('users/uidDani');
      final pendente = ref.update({'displayName': 'Gravado Depois', 'updatedAt': FieldValue.serverTimestamp()});
      // A tela já veria a alteração como feita, embora o servidor não a tenha
      final local = await ref
          .snapshots(includeMetadataChanges: true)
          .firstWhere((s) => s.data()?['displayName'] == 'Gravado Depois')
          .timeout(const Duration(seconds: 15));
      expect(local.metadata.hasPendingWrites, isTrue);
      expect(await nomeNoServidor(), _nomeOriginal);

      await conexao(online: true);
      await pendente.timeout(const Duration(seconds: 90));
      expect(await nomeNoServidor(), 'Gravado Depois');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('tela de Perfil', () {
    final banner = find.byKey(const Key('perfil_sem_conexao'));

    Future<void> abrirPerfil(WidgetTester tester) async {
      await tester.pumpWidget(
        Provider<UserProfileService>.value(
          value: service,
          child: const MaterialApp(home: PerfilScreen()),
        ),
      );
      await aguardar(tester, find.text(_nomeOriginal));
      await aguardar(tester, banner, esperado: findsNothing);
    }

    testWidgets('perda e retorno da conexão com o perfil aberto', (tester) async {
      await abrirPerfil(tester);

      await conexao(online: false);
      await aguardar(tester, banner, esperado: findsOneWidget);
      expect(find.textContaining('Sem conexão. Exibindo os últimos dados salvos'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('perfil_display_name'))).data, _nomeOriginal);

      await tester.tap(find.byKey(const Key('perfil_editar_nome')));
      await aguardar(tester, find.text('Sem conexão. Conecte-se à internet para alterar o nome.'));
      expect(find.byKey(const Key('editar_nome_campo')), findsNothing);

      await conexao(online: true);
      await aguardar(tester, banner, esperado: findsNothing, segundos: 90);
      expect(await nomeNoServidor(), _nomeOriginal);
    }, timeout: const Timeout(Duration(minutes: 4)));

    testWidgets('conexão perdida com o diálogo aberto: erro claro e nada gravado depois', (tester) async {
      await abrirPerfil(tester);

      await tester.tap(find.byKey(const Key('perfil_editar_nome')));
      await aguardar(tester, find.byKey(const Key('editar_nome_campo')));
      await tester.enterText(find.byKey(const Key('editar_nome_campo')), 'Dani Offline');

      await conexao(online: false);
      await tester.tap(find.byKey(const Key('editar_nome_salvar')));
      await aguardar(tester, find.text('Sem conexão com o servidor. O nome não foi alterado.'));
      expect(find.text('Nome de exibição atualizado.'), findsNothing);

      await tester.tap(find.text('Cancelar'));
      await aguardar(tester, find.byKey(const Key('editar_nome_campo')), esperado: findsNothing);

      await conexao(online: true);
      await aguardar(tester, banner, esperado: findsNothing, segundos: 90);
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      await tester.pump();
      expect(await nomeNoServidor(), _nomeOriginal);
      expect(tester.widget<Text>(find.byKey(const Key('perfil_display_name'))).data, _nomeOriginal);
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
