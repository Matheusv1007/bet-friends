import 'package:flutter_test/flutter_test.dart';

import 'package:betfriends/models/friendship_model.dart';

void main() {
  group('FriendshipStatus', () {
    test('mapeia strings válidas e padrão PENDING', () {
      expect(FriendshipStatus.fromString('PENDING'), FriendshipStatus.pending);
      expect(FriendshipStatus.fromString('pending'), FriendshipStatus.pending);
      expect(FriendshipStatus.fromString('ACCEPTED'), FriendshipStatus.accepted);
      expect(FriendshipStatus.fromString('accepted'), FriendshipStatus.accepted);
      expect(FriendshipStatus.fromString('REJECTED'), FriendshipStatus.rejected);
      expect(FriendshipStatus.fromString('rejected'), FriendshipStatus.rejected);
      expect(FriendshipStatus.fromString('outro'), FriendshipStatus.pending);
    });
  });

  group('ResultadoEnvioAmizade', () {
    test('serializa e desserializa corretamente', () {
      final mapa = {
        'friendshipId': 'userA_userB',
        'status': 'PENDING',
        'autoAccepted': false,
      };

      final res = ResultadoEnvioAmizade.fromMap(mapa);
      expect(res.friendshipId, 'userA_userB');
      expect(res.status, FriendshipStatus.pending);
      expect(res.autoAccepted, false);

      final toMap = res.toMap();
      expect(toMap['friendshipId'], 'userA_userB');
      expect(toMap['status'], 'PENDING');
      expect(toMap['autoAccepted'], false);
    });

    test('desserializa caso de aceitação cruzada (RN-FRD-005)', () {
      final mapa = {
        'friendshipId': 'userA_userB',
        'status': 'ACCEPTED',
        'autoAccepted': true,
      };

      final res = ResultadoEnvioAmizade.fromMap(mapa);
      expect(res.friendshipId, 'userA_userB');
      expect(res.status, FriendshipStatus.accepted);
      expect(res.autoAccepted, true);
    });
  });

  group('ResultadoAceiteAmizade', () {
    test('serializa e desserializa corretamente', () {
      final mapa = {
        'friendshipId': 'userA_userB',
        'status': 'ACCEPTED',
        'userAId': 'userA',
        'userBId': 'userB',
      };

      final res = ResultadoAceiteAmizade.fromMap(mapa);
      expect(res.friendshipId, 'userA_userB');
      expect(res.status, FriendshipStatus.accepted);
      expect(res.userAId, 'userA');
      expect(res.userBId, 'userB');

      final toMap = res.toMap();
      expect(toMap['friendshipId'], 'userA_userB');
      expect(toMap['status'], 'ACCEPTED');
      expect(toMap['userAId'], 'userA');
      expect(toMap['userBId'], 'userB');
    });
  });

  group('ResultadoRecusaAmizade', () {
    test('serializa e desserializa corretamente', () {
      final mapa = {
        'friendshipId': 'userA_userB',
        'status': 'REJECTED',
        'userAId': 'userA',
        'userBId': 'userB',
      };

      final res = ResultadoRecusaAmizade.fromMap(mapa);
      expect(res.friendshipId, 'userA_userB');
      expect(res.status, FriendshipStatus.rejected);
      expect(res.userAId, 'userA');
      expect(res.userBId, 'userB');

      final toMap = res.toMap();
      expect(toMap['friendshipId'], 'userA_userB');
      expect(toMap['status'], 'REJECTED');
      expect(toMap['userAId'], 'userA');
      expect(toMap['userBId'], 'userB');
    });
  });

  group('SolicitacaoAmizade', () {
    test('serializa e desserializa garantindo privacidade (RN-PROF-002)', () {
      final mapa = {
        'friendshipId': 'userA_userB',
        'status': 'PENDING',
        'createdAt': '2026-11-16T12:00:00.000Z',
        'remetente': {
          'userId': 'userA',
          'displayName': 'Alice Silva',
          'username': 'alicesilva',
          // Campos privados hipotéticos no payload bruto NÃO devem vazar
          'email': 'alice@example.com',
          'saldoTotal': 5000,
        },
      };

      final solicitacao = SolicitacaoAmizade.fromMap(mapa);
      expect(solicitacao.friendshipId, 'userA_userB');
      expect(solicitacao.status, FriendshipStatus.pending);
      expect(solicitacao.remetente.userId, 'userA');
      expect(solicitacao.remetente.displayName, 'Alice Silva');
      expect(solicitacao.remetente.username, 'alicesilva');
      expect(solicitacao.remetente.usernameComArroba, '@alicesilva');

      final exportado = solicitacao.toMap();
      expect(exportado['friendshipId'], 'userA_userB');
      expect(exportado['status'], 'PENDING');
      expect(exportado['remetente']['displayName'], 'Alice Silva');
      expect(exportado['remetente']['username'], 'alicesilva');
      expect(exportado['remetente'].containsKey('email'), isFalse);
      expect(exportado['remetente'].containsKey('saldoTotal'), isFalse);
    });
  });

  group('FriendshipModel', () {
    test('converte documento Firestore para FriendshipModel e de volta', () {
      final agora = DateTime.now();
      final docMap = {
        'userAId': 'userA',
        'userBId': 'userB',
        'participants': ['userA', 'userB'],
        'requesterId': 'userA',
        'status': 'PENDING',
        'createdAt': agora.toIso8601String(),
        'respondedAt': null,
        'updatedAt': agora.toIso8601String(),
      };

      final amizade = FriendshipModel.fromMap('userA_userB', docMap);
      expect(amizade.id, 'userA_userB');
      expect(amizade.userAId, 'userA');
      expect(amizade.userBId, 'userB');
      expect(amizade.participants, ['userA', 'userB']);
      expect(amizade.requesterId, 'userA');
      expect(amizade.status, FriendshipStatus.pending);
      expect(amizade.createdAt, isNotNull);
      expect(amizade.respondedAt, isNull);

      final toMap = amizade.toMap();
      expect(toMap['userAId'], 'userA');
      expect(toMap['userBId'], 'userB');
      expect(toMap['participants'], ['userA', 'userB']);
      expect(toMap['status'], 'PENDING');
    });
  });
}
