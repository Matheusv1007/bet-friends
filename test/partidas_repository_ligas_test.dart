// Os tipos do Firestore são `sealed` para quem os estende; o fake abaixo
// implementa só o que o repositório de partidas chama (ver firestore_erros_test.dart).
// ignore_for_file: subtype_of_sealed_class

import 'package:betfriends/data/firestore/partidas_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coleção `matches` em memória que respeita `where`, `orderBy` e `limit`.
class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.documentos, {this.ligaComErro});

  final Map<String, Map<String, dynamic>> documentos;
  final String? ligaComErro;
  final consultas = <({String liga, int? limite})>[];

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Consulta(this);
}

class _Consulta extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Consulta(this.db, {this.liga, this.minimo, this.maximo, this.decrescente = false, this.limite});

  final _Firestore db;
  final String? liga;
  final DateTime? minimo;
  final DateTime? maximo;
  final bool decrescente;
  final int? limite;

  _Consulta copia({String? liga, DateTime? minimo, DateTime? maximo, bool? decrescente, int? limite}) =>
      _Consulta(
        db,
        liga: liga ?? this.liga,
        minimo: minimo ?? this.minimo,
        maximo: maximo ?? this.maximo,
        decrescente: decrescente ?? this.decrescente,
        limite: limite ?? this.limite,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final nomes = invocation.namedArguments;
    switch (invocation.memberName) {
      case #where:
        final campo = invocation.positionalArguments.first;
        if (campo == 'competitionCode') {
          return copia(liga: nomes[#isEqualTo] as String);
        }
        expect(campo, 'startsAtUtc');
        return copia(
          minimo: (nomes[#isGreaterThanOrEqualTo] as Timestamp?)?.toDate(),
          maximo: (nomes[#isLessThan] as Timestamp?)?.toDate(),
        );
      case #orderBy:
        expect(invocation.positionalArguments.first, 'startsAtUtc');
        return copia(decrescente: nomes[#descending] == true);
      case #limit:
        return copia(limite: invocation.positionalArguments.first as int);
      case #get:
        db.consultas.add((liga: liga!, limite: limite));
        if (liga == db.ligaComErro) {
          return Future<QuerySnapshot<Map<String, dynamic>>>.error(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          );
        }
        final docs = [
          for (final e in db.documentos.entries)
            if (e.value['competitionCode'] == liga &&
                _dentro((e.value['startsAtUtc'] as Timestamp).toDate()))
              _Doc(e.key, e.value),
        ]..sort((a, b) => a.inicio.compareTo(b.inicio));
        final ordenados = decrescente ? docs.reversed.toList() : docs;
        return Future<QuerySnapshot<Map<String, dynamic>>>.value(
          _Snapshot(ordenados.take(limite ?? ordenados.length).toList()),
        );
      default:
        return super.noSuchMethod(invocation);
    }
  }

  bool _dentro(DateTime t) =>
      (minimo == null || !t.isBefore(minimo!)) &&
      (maximo == null || t.isBefore(maximo!));
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this.dados);
  @override
  final String id;
  final Map<String, dynamic> dados;
  DateTime get inicio => (dados['startsAtUtc'] as Timestamp).toDate();
  @override
  Map<String, dynamic> data() => dados;
}

Map<String, dynamic> _partida(String? liga, DateTime inicio, {String status = 'SCHEDULED'}) => {
      'competitionCode': ?liga,
      'status': status,
      'homeTeam': {'name': 'Casa'},
      'awayTeam': {'name': 'Fora'},
      'startsAtUtc': Timestamp.fromDate(inicio),
    };

void main() {
  final agora = DateTime.now().toUtc();
  DateTime emHoras(int h) => agora.add(Duration(hours: h));

  test('as quatro ligas aparecem juntas e ordenadas por horário', () async {
    final db = _Firestore({
      'footballdata_1': _partida('PD', emHoras(5)),
      'footballdata_2': _partida('BSA', emHoras(2)),
      'footballdata_3': _partida('SA', emHoras(8)),
      'footballdata_4': _partida('PL', emHoras(1)),
    });

    final partidas = await FirestorePartidasRepository(firestore: db).getPartidas();

    expect(partidas.map((p) => p.id), [
      'footballdata_4', 'footballdata_2', 'footballdata_1', 'footballdata_3',
    ]);
    expect(partidas.map((p) => p.competitionCode), ['PL', 'BSA', 'PD', 'SA']);
    expect(db.consultas.map((c) => c.liga).toSet(), {'BSA', 'PL', 'SA', 'PD'});
  });

  test('liga sem partidas não esconde as outras', () async {
    final db = _Firestore({
      'footballdata_1': _partida('PL', emHoras(1)),
      'footballdata_2': _partida('PD', emHoras(2)),
    });

    final partidas = await FirestorePartidasRepository(firestore: db).getPartidas();

    expect(partidas.map((p) => p.competitionCode), ['PL', 'PD']);
  });

  test('sem nenhuma partida devolve lista vazia, não erro', () async {
    final partidas = await FirestorePartidasRepository(firestore: _Firestore({}))
        .getPartidas();
    expect(partidas, isEmpty);
  });

  test('documento antigo sem competitionCode nem season não é encontrado nem quebra a lista', () async {
    final db = _Firestore({
      'antigo': _partida(null, emHoras(3)),
      'footballdata_1': _partida('BSA', emHoras(1)),
    });

    final partidas = await FirestorePartidasRepository(firestore: db).getPartidas();

    expect(partidas.map((p) => p.id), ['footballdata_1']);
  });

  test('cada liga tem limite próprio e uma liga não sufoca as outras', () async {
    final docs = <String, Map<String, dynamic>>{
      for (var i = 0; i < 40; i++) 'bsa_$i': _partida('BSA', emHoras(i + 1)),
      'pl_0': _partida('PL', emHoras(100)),
    };
    final db = _Firestore(docs);

    final partidas = await FirestorePartidasRepository(firestore: db).getPartidas();

    final porLiga = <String?, int>{};
    for (final p in partidas) {
      porLiga[p.competitionCode] = (porLiga[p.competitionCode] ?? 0) + 1;
    }
    expect(porLiga['BSA'], FirestorePartidasRepository.limiteDaJanelaPorLiga);
    expect(porLiga['PL'], 1);
    expect(partidas.length, greaterThan(15), reason: 'o repositório não corta o conjunto');
  });

  test('inclui as partidas recentes de cada liga além da janela', () async {
    final db = _Firestore({
      for (var i = 0; i < 5; i++)
        'antiga_$i': _partida('SA', agora.subtract(Duration(days: 10 + i)), status: 'FINISHED'),
      'futura': _partida('SA', emHoras(4)),
    });

    final partidas = await FirestorePartidasRepository(firestore: db).getPartidas();

    expect(
      partidas.where((p) => p.isFinalizado).length,
      FirestorePartidasRepository.partidasRecentesPorLiga,
    );
    expect(partidas.last.id, 'futura');
  });

  test('falha em uma liga vira erro, sem lista parcial', () async {
    final db = _Firestore({
      'footballdata_1': _partida('BSA', emHoras(1)),
      'footballdata_2': _partida('PL', emHoras(2)),
    }, ligaComErro: 'PD');

    await expectLater(
      FirestorePartidasRepository(firestore: db).getPartidas(),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
    );
  });
}
