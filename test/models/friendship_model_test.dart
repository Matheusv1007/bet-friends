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
