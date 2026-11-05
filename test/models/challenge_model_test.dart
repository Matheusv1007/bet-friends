import 'package:flutter_test/flutter_test.dart';
import 'package:betfriends/models/challenge_model.dart';

void main() {
  group('ChallengeModel & Enums', () {
    test('Palpite enum conversão de valor e labels', () {
      expect(Palpite.deValor('HOME_WIN'), Palpite.homeWin);
      expect(Palpite.deValor('DRAW'), Palpite.draw);
      expect(Palpite.deValor('AWAY_WIN'), Palpite.awayWin);
      expect(Palpite.deValor('INVALID'), isNull);
      expect(Palpite.deValor(null), isNull);

      expect(Palpite.homeWin.valor, 'HOME_WIN');
      expect(Palpite.draw.valor, 'DRAW');
      expect(Palpite.awayWin.valor, 'AWAY_WIN');
    });

    test('StatusDesafio enum identificação de estados e terminais', () {
      expect(StatusDesafio.deValor('PENDING'), StatusDesafio.pending);
      expect(StatusDesafio.deValor('ACCEPTED'), StatusDesafio.accepted);
      expect(StatusDesafio.deValor('IN_PROGRESS'), StatusDesafio.inProgress);
      expect(StatusDesafio.deValor('WAITING_RESULT'), StatusDesafio.waitingResult);
      expect(StatusDesafio.deValor('FINISHED'), StatusDesafio.finished);
      expect(StatusDesafio.deValor('REJECTED'), StatusDesafio.rejected);
      expect(StatusDesafio.deValor('EXPIRED'), StatusDesafio.expired);
      expect(StatusDesafio.deValor('CANCELLED'), StatusDesafio.cancelled);
      expect(StatusDesafio.deValor('OUTRO'), isNull);

      expect(StatusDesafio.pending.isTerminal, isFalse);
      expect(StatusDesafio.accepted.isTerminal, isFalse);
      expect(StatusDesafio.inProgress.isTerminal, isFalse);
      expect(StatusDesafio.waitingResult.isTerminal, isFalse);
      expect(StatusDesafio.finished.isTerminal, isTrue);
      expect(StatusDesafio.rejected.isTerminal, isTrue);
      expect(StatusDesafio.expired.isTerminal, isTrue);
      expect(StatusDesafio.cancelled.isTerminal, isTrue);
    });

    test('ChallengeModel fromMap e toMap completos', () {
      final now = DateTime.now();
      final map = {
        'challengerId': 'uid_alice',
        'challengedId': 'uid_bob',
        'participants': ['uid_alice', 'uid_bob'],
        'matchId': 'footballdata_100',
        'challengerPrediction': 'HOME_WIN',
        'challengedPrediction': 'AWAY_WIN',
        'amount': 100,
        'status': 'ACCEPTED',
        'winnerId': null,
        'settledResult': null,
        'cancelReason': null,
        'createdAt': now.toIso8601String(),
        'acceptedAt': now.toIso8601String(),
        'startedAt': null,
        'finishedAt': null,
        'updatedAt': now.toIso8601String(),
      };

      final model = ChallengeModel.fromMap('chl_123', map);

      expect(model.id, 'chl_123');
      expect(model.challengerId, 'uid_alice');
      expect(model.challengedId, 'uid_bob');
      expect(model.amount, 100);
      expect(model.status, StatusDesafio.accepted);
      expect(model.isAccepted, isTrue);
      expect(model.isPending, isFalse);
      expect(model.isTerminal, isFalse);
      expect(model.challengerPrediction, Palpite.homeWin);
      expect(model.challengedPrediction, Palpite.awayWin);

      final toMap = model.toMap();
      expect(toMap['id'], 'chl_123');
      expect(toMap['amount'], 100);
      expect(toMap['challengerPrediction'], 'HOME_WIN');
      expect(toMap['challengedPrediction'], 'AWAY_WIN');
      expect(toMap['status'], 'ACCEPTED');
    });

    test('CriarDesafioRequest e CriarDesafioResponse', () {
      const req = CriarDesafioRequest(
        challengedId: 'uid_bob',
        matchId: 'match_1',
        challengerPrediction: Palpite.homeWin,
        amount: 50,
      );

      final map = req.toMap();
      expect(map['challengedId'], 'uid_bob');
      expect(map['matchId'], 'match_1');
      expect(map['challengerPrediction'], 'HOME_WIN');
      expect(map['amount'], 50);

      final resp = CriarDesafioResponse.fromMap({
        'challengeId': 'chl_456',
        'status': 'PENDING',
        'challengerId': 'uid_alice',
        'challengedId': 'uid_bob',
        'matchId': 'match_1',
        'challengerPrediction': 'HOME_WIN',
        'amount': 50,
      });

      expect(resp.challengeId, 'chl_456');
      expect(resp.status, StatusDesafio.pending);
      expect(resp.amount, 50);
    });

    test('AceitarDesafioRequest e AceitarDesafioResponse', () {
      const req = AceitarDesafioRequest(
        challengeId: 'chl_456',
        challengedPrediction: Palpite.awayWin,
      );

      expect(req.toMap()['challengeId'], 'chl_456');
      expect(req.toMap()['challengedPrediction'], 'AWAY_WIN');

      final resp = AceitarDesafioResponse.fromMap({
        'challengeId': 'chl_456',
        'status': 'ACCEPTED',
        'challengerId': 'uid_alice',
        'challengedId': 'uid_bob',
        'matchId': 'match_1',
        'challengerPrediction': 'HOME_WIN',
        'challengedPrediction': 'AWAY_WIN',
        'amount': 50,
        'acceptedAt': DateTime.now().toIso8601String(),
      });

      expect(resp.challengeId, 'chl_456');
      expect(resp.status, StatusDesafio.accepted);
      expect(resp.challengedPrediction, Palpite.awayWin);
    });
  });
}
