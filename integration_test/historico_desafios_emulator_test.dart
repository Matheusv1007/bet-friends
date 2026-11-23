// Consulta de histórico de desafios (KAN-89) no Android, com Auth e Firestore
// Emulator e as Security Rules reais. Dados de support/seed_emulators.mjs.
// O emulador não exige índices compostos: o índice é conferido à parte.
// Como executar: integration_test/README.md.

import 'dart:convert';
import 'dart:io';

import 'package:betfriends/data/firestore/historico_de_desafios_repository.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/historico_de_desafios_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _projeto = 'demo-betfriends';
const _host = '10.0.2.2';
const _senha = 'senha-emulador-123';

const _opcoes = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: _projeto,
);

const _ordemDaHana = ['hist-rej', 'hist-can', 'hist-fim', 'hist-exp', 'hist-emp-b', 'hist-emp-a'];

/// Simula o backend: grava no emulador com acesso administrativo.
Future<void> _encerrarComoBackend(String id, DateTime finishedAt) async {
  final cliente = HttpClient();
  try {
    final uri = Uri.parse(
      'http://$_host:8080/v1/projects/$_projeto/databases/(default)/documents/challenges/$id'
      '?updateMask.fieldPaths=status&updateMask.fieldPaths=finishedAt&updateMask.fieldPaths=winnerId&updateMask.fieldPaths=settledResult',
    );
    final pedido = await cliente.patchUrl(uri);
    pedido.headers.set('Authorization', 'Bearer owner');
    pedido.headers.contentType = ContentType.json;
    pedido.write(jsonEncode({
      'fields': {
        'status': {'stringValue': 'FINISHED'},
        'finishedAt': {'timestampValue': finishedAt.toUtc().toIso8601String()},
        'winnerId': {'nullValue': null},
        'settledResult': {'stringValue': 'DRAW'},
      },
    }));
    final resposta = await pedido.close();
    await resposta.drain<void>();
    expect(resposta.statusCode, 200);
  } finally {
    cliente.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirestoreHistoricoDeDesafiosRepository repository;
  late HistoricoDeDesafiosService service;

  Future<void> entrar(String email) async {
    await auth.signOut();
    await auth.signInWithEmailAndPassword(email: email, password: _senha);
  }

  List<String> ids(PaginaDoHistorico p) => [for (final d in p.itens) d.id];

  Future<List<String>> tudo() async {
    final todos = <String>[];
    CursorDoHistorico? cursor;
    do {
      final p = await service.buscarDoUsuarioAtual(limite: 2, cursor: cursor);
      todos.addAll(ids(p));
      cursor = p.proximoCursor;
    } while (cursor != null);
    return todos;
  }

  setUpAll(() async {
    final app = await Firebase.initializeApp(name: 'kan89-emulador', options: _opcoes);
    expect(app.options.projectId, startsWith('demo-'));
    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(_host, 9099);
    final db = FirebaseFirestore.instanceFor(app: app);
    db.settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator(_host, 8080);
    repository = FirestoreHistoricoDeDesafiosRepository(firestore: db);
    service = HistoricoDeDesafiosService(authService: AuthService(firebaseAuth: auth), repository: repository);
  });

  tearDownAll(() => auth.signOut());

  test('criador ou desafiado: só estados encerrados, do mais recente ao mais antigo', () async {
    await entrar('hana@example.com');
    final p = await service.buscarDoUsuarioAtual();
    expect(ids(p), _ordemDaHana);
    expect(p.temMais, isFalse);
    expect(p.doCache, isFalse);
    final ordem = [for (final d in p.itens) d.finishedAt];
    for (var i = 1; i < ordem.length; i++) {
      expect(ordem[i].isAfter(ordem[i - 1]), isFalse);
    }
    expect(p.itens.first.challengedId, 'uidHana', reason: 'como desafiada');
    expect(p.itens[2].challengerId, 'uidHana', reason: 'como criadora');
  });

  test('usa os dados persistidos, inclusive empate sem vencedor', () async {
    await entrar('hana@example.com');
    final p = await service.buscarDoUsuarioAtual();
    final fim = p.itens.firstWhere((d) => d.id == 'hist-fim');
    expect(fim.winnerId, 'uidHana');
    expect(fim.settledResult, 'HOME_WIN');
    final empate = p.itens.firstWhere((d) => d.id == 'hist-emp-a');
    expect(empate.winnerId, isNull);
    expect(empate.settledResult, 'DRAW');
    expect(p.itens.firstWhere((d) => d.id == 'hist-can').cancelReason, 'MATCH_CANCELLED');
  });

  test('documento fora do contrato é ignorado e contado, sem interromper', () async {
    await entrar('hana@example.com');
    final p = await service.buscarDoUsuarioAtual();
    expect(p.ignorados, 1);
    expect(ids(p), isNot(contains('hist-invalido')));
  });

  test('paginação estável, com empate de finishedAt, sem repetir nem pular', () async {
    await entrar('hana@example.com');
    expect(await tudo(), _ordemDaHana);
  });

  test('terceiros: não aparecem e consultar o UID de outro usuário é negado', () async {
    await entrar('joao@example.com');
    expect(ids(await service.buscarDoUsuarioAtual()), ['hist-terc']);
    await expectLater(
      repository.buscar('uidHana'),
      throwsA(isA<HistoricoException>().having((e) => e.code, 'code', HistoricoErrorCode.permissionDenied)),
    );
    await entrar('hana@example.com');
    expect(ids(await service.buscarDoUsuarioAtual()), isNot(contains('hist-terc')));
  });

  test('sem desafios: página vazia confirmada pelo servidor', () async {
    await entrar('vazio@example.com');
    final p = await service.buscarDoUsuarioAtual();
    expect(p.itens, isEmpty);
    expect(p.ignorados, 0);
    expect(p.doCache, isFalse);
    expect(p.temMais, isFalse);
  });

  test('sem sessão: unauthenticated', () async {
    await auth.signOut();
    expect(
      () => service.buscarDoUsuarioAtual(),
      throwsA(isA<HistoricoException>().having((e) => e.code, 'code', HistoricoErrorCode.unauthenticated)),
    );
  });

  test('consultas simultâneas devolvem o mesmo resultado', () async {
    await entrar('hana@example.com');
    final r = await Future.wait(List.generate(5, (_) => service.buscarDoUsuarioAtual()));
    for (final p in r) {
      expect(ids(p), _ordemDaHana);
    }
  });

  // Último teste: muda hist-at-progresso
  test('desafio encerrado durante a paginação não duplica nem desorganiza', () async {
    await entrar('hana@example.com');
    final primeira = await service.buscarDoUsuarioAtual(limite: 2);
    expect(ids(primeira), _ordemDaHana.sublist(0, 2));

    await _encerrarComoBackend('hist-at-progresso', DateTime.utc(2026, 10, 30, 23));

    final resto = <String>[];
    var cursor = primeira.proximoCursor;
    while (cursor != null) {
      final p = await service.buscarDoUsuarioAtual(limite: 2, cursor: cursor);
      resto.addAll(ids(p));
      cursor = p.proximoCursor;
    }
    expect(resto, _ordemDaHana.sublist(2), reason: 'o novo é mais recente que o cursor, então fica para a próxima consulta');
    expect(ids(await service.buscarDoUsuarioAtual()).first, 'hist-at-progresso');
  });
}
