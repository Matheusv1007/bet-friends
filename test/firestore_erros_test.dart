// Os tipos do Firestore são `sealed` para quem os estende, mas não há outro
// jeito de simular leituras sem Firebase inicializado e sem uma dependência
// nova (fake_cloud_firestore); os fakes abaixo só implementam o que os
// repositórios chamam.
// ignore_for_file: subtype_of_sealed_class

import 'package:betfriends/data/firestore/challenge_repository.dart';
import 'package:betfriends/data/firestore/partidas_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// Simula apenas as leituras usadas pelos repositórios, sem Firebase inicializado.
class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.colecao);

  final _Colecao colecao;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      colecao;
}

class _Colecao extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Colecao({required this.erroServidor, this.cache = const [], this.erroCache});

  final Object erroServidor;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> cache;
  final Object? erroCache;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #where:
      case #orderBy:
      case #limit:
        return this;
      case #doc:
        return _Documento(erroServidor);
      case #get:
        final options = invocation.positionalArguments.isEmpty
            ? null
            : invocation.positionalArguments.first as GetOptions?;
        if (options?.source != Source.cache) {
          return Future<QuerySnapshot<Map<String, dynamic>>>.error(erroServidor);
        }
        if (erroCache != null) {
          return Future<QuerySnapshot<Map<String, dynamic>>>.error(erroCache!);
        }
        return Future<QuerySnapshot<Map<String, dynamic>>>.value(_Snapshot(cache));
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

class _Documento extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Documento(this.erro);
  final Object erro;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      Future.error(erro);
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Partida extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  String get id => 'partida-cache';

  @override
  Map<String, dynamic> data() => {
        'competitionCode': 'BSA',
        'status': 'SCHEDULED',
        'homeTeam': {'name': 'Mandante'},
        'awayTeam': {'name': 'Visitante'},
        'startsAtUtc': '2026-12-01T18:00:00Z',
      };
}

void main() {
  test('partidas preservam os dados locais quando o servidor falha', () async {
    final db = _Firestore(_Colecao(
      erroServidor: FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      cache: [_Partida()],
    ));

    final partidas = await FirestorePartidasRepository(firestore: db).getPartidas();

    expect(partidas.single.id, 'partida-cache');
  });

  for (final cacheFalha in [false, true]) {
    test('partidas relançam o erro original com cache ${cacheFalha ? 'indisponível' : 'vazio'}', () async {
      final original = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
      final db = _Firestore(_Colecao(
        erroServidor: original,
        erroCache: cacheFalha ? StateError('cache indisponível') : null,
      ));

      await expectLater(
        FirestorePartidasRepository(firestore: db).getPartidas(),
        throwsA(same(original)),
      );
    });
  }

  for (final codigo in ['permission-denied', 'unavailable', 'failed-precondition']) {
    final dominio = switch (codigo) {
      'permission-denied' => ChallengeErrorCode.permissionDenied,
      'unavailable' => ChallengeErrorCode.unavailable,
      _ => ChallengeErrorCode.unknown,
    };
    test('leituras de desafio não confundem $codigo com dados ausentes', () async {
      final db = _Firestore(_Colecao(
        erroServidor: FirebaseException(plugin: 'cloud_firestore', code: codigo),
      ));
      final repository = FunctionsChallengeRepository(firestore: db);
      final erro = isA<ChallengeException>().having((e) => e.code, 'code', dominio);

      await expectLater(repository.buscarSaldoDisponivel('uid'), throwsA(erro));
      await expectLater(repository.listarAmigosAceitos('uid'), throwsA(erro));
    });
  }
}
