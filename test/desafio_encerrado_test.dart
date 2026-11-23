import 'package:betfriends/models/desafio_encerrado.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _finalizado([Map<String, dynamic> extra = const {}]) => {
      'challengerId': 'a',
      'challengedId': 'b',
      'participants': ['a', 'b'],
      'matchId': 'BSA_1',
      'challengerPrediction': 'HOME_WIN',
      'challengedPrediction': 'DRAW',
      'amount': 100,
      'status': 'FINISHED',
      'winnerId': 'a',
      'settledResult': 'HOME_WIN',
      'cancelReason': null,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
      'acceptedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 1)),
      'startedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 2)),
      'finishedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 4)),
      ...extra,
    };

void main() {
  test('lê os dados persistidos, sem recalcular o resultado', () {
    // winnerId não confere com os palpites de propósito: o app não decide quem venceu
    final d = DesafioEncerrado.fromMap('d1', _finalizado({'winnerId': 'b'}));
    expect(d.id, 'd1');
    expect(d.status, StatusEncerrado.finished);
    expect(d.winnerId, 'b');
    expect(d.settledResult, 'HOME_WIN');
    expect(d.finishedAt.isAtSameMomentAs(DateTime.utc(2026, 11, 1, 4)), isTrue);
    expect(d.temParticipante('a'), isTrue);
    expect(d.temParticipante('c'), isFalse);
  });

  test('empate estrutural: FINISHED com winnerId nulo', () {
    expect(DesafioEncerrado.fromMap('d', _finalizado({'winnerId': null})).winnerId, isNull);
  });

  test('aceita os outros estados terminais', () {
    final base = {'winnerId': null, 'settledResult': null};
    expect(
      DesafioEncerrado.fromMap('d', _finalizado({...base, 'status': 'CANCELLED', 'cancelReason': 'MATCH_CANCELLED'})).status,
      StatusEncerrado.cancelled,
    );
    for (final (valor, esperado) in [
      ('REJECTED', StatusEncerrado.rejected),
      ('EXPIRED', StatusEncerrado.expired),
    ]) {
      final d = DesafioEncerrado.fromMap('d', _finalizado({
        ...base,
        'status': valor,
        'challengedPrediction': null,
        'acceptedAt': null,
        'startedAt': null,
      }));
      expect(d.status, esperado);
    }
  });

  test('recusa estados ativos e desconhecidos', () {
    for (final status in ['PENDING', 'ACCEPTED', 'IN_PROGRESS', 'WAITING_RESULT', 'OUTRO', null, 1]) {
      expect(() => DesafioEncerrado.fromMap('d', _finalizado({'status': status})), throwsFormatException, reason: '$status');
    }
  });

  test('recusa dados fora do contrato, sem corrigir', () {
    final invalidos = <String, Map<String, dynamic>>{
      'finishedAt nulo': {'finishedAt': null},
      'finishedAt texto': {'finishedAt': '2026-11-01'},
      'amount baixo': {'amount': 5},
      'amount alto': {'amount': 501},
      'amount decimal': {'amount': 10.5},
      'participants fora de ordem': {'participants': ['b', 'a']},
      'participants ausente': {'participants': null},
      'mesmo participante': {'challengedId': 'a', 'participants': ['a', 'a']},
      'vencedor de fora': {'winnerId': 'c'},
      'palpite inválido': {'challengerPrediction': 'X'},
      'FINISHED sem palpite do desafiado': {'challengedPrediction': null},
      'FINISHED sem resultado': {'settledResult': null},
      'motivo fora de CANCELLED': {'cancelReason': 'CREATOR'},
      'CANCELLED sem motivo': {'status': 'CANCELLED', 'winnerId': null, 'settledResult': null},
      'vencedor fora de FINISHED': {'status': 'EXPIRED', 'settledResult': null},
      'resultado fora de FINISHED': {'status': 'EXPIRED', 'winnerId': null},
      'matchId vazio': {'matchId': ''},
      'createdAt ausente': {'createdAt': null},
    };
    invalidos.forEach((nome, extra) {
      expect(() => DesafioEncerrado.fromMap('d', _finalizado(extra)), throwsFormatException, reason: nome);
    });
  });
}
