// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:betfriends/data/firestore/challenge_repository.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _Db extends Fake implements FirebaseFirestore {
  final consultas = <_Query>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => _Query(consultas);
}

class _Configuracao {
  String? ordem;
  bool descendente = false;
  int? limite;
}

class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Query(this.consultas, [this.status]);
  final List<_Query> consultas;
  final List<Object?>? status;
  final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();
  final configuracao = _Configuracao();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #where:
        final valores = invocation.namedArguments[#whereIn] as Iterable<Object?>?;
        if (valores == null) return this;
        return _Query(consultas, valores.toList());
      case #orderBy:
        configuracao.ordem = invocation.positionalArguments.first as String;
        configuracao.descendente = invocation.namedArguments[#descending] == true;
        return this;
      case #limit:
        configuracao.limite = invocation.positionalArguments.first as int;
        return this;
      case #snapshots:
        consultas.add(this);
        return controller.stream;
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this.status);
  @override
  final String id;
  final String status;
  @override
  Map<String, dynamic> data() => {
    'status': status, 'challengerId': 'q7x', 'challengedId': 'p9z',
    'participants': ['q7x', 'p9z'], 'matchId': 'm1',
    'challengerPrediction': 'HOME_WIN', 'amount': 50,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026)),
  };
}

void main() {
  test('N-19: ativos completos e terminais limitados têm assinaturas canceláveis', () async {
    final db = _Db();
    final valores = <List<ChallengeModel>>[];
    final assinatura = FunctionsChallengeRepository(firestore: db)
        .observarDesafiosDoUsuario('q7x').listen(valores.add);
    expect(db.consultas.length, 2);
    final ativos = db.consultas[0];
    final terminais = db.consultas[1];
    expect(ativos.status, ['PENDING', 'ACCEPTED', 'IN_PROGRESS', 'WAITING_RESULT']);
    expect(ativos.configuracao.limite, isNull);
    expect(terminais.status, ['FINISHED', 'REJECTED', 'EXPIRED', 'CANCELLED']);
    expect(terminais.configuracao.ordem, 'updatedAt');
    expect(terminais.configuracao.descendente, isTrue);
    expect(terminais.configuracao.limite, 20);
    ativos.controller.add(_Snapshot([_Doc('c1', 'ACCEPTED')]));
    terminais.controller.add(_Snapshot([]));
    await Future<void>.delayed(Duration.zero);
    expect(valores.last.single.status, StatusDesafio.accepted);
    terminais.controller.add(_Snapshot([_Doc('c1', 'FINISHED')]));
    await Future<void>.delayed(Duration.zero);
    expect(valores.last.single.status, StatusDesafio.finished);
    await assinatura.cancel();
    expect(ativos.controller.hasListener, isFalse);
    expect(terminais.controller.hasListener, isFalse);
    await ativos.controller.close();
    await terminais.controller.close();
  });
}
