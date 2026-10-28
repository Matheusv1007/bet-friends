import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _dadosValidos() => {
      'displayName': 'Pedro Simon',
      'username': 'PedroS',
      'usernameNormalized': 'pedros',
      'email': 'pedro@example.com',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 28, 12)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 28, 13)),
    };

void main() {
  group('UserProfile.fromMap', () {
    test('converte o documento usando o ID como UID', () {
      final perfil = UserProfile.fromMap('uid-123', _dadosValidos());

      expect(perfil.uid, 'uid-123');
      expect(perfil.displayName, 'Pedro Simon');
      expect(perfil.username, 'PedroS');
      expect(perfil.usernameNormalized, 'pedros');
      expect(perfil.email, 'pedro@example.com');
      expect(perfil.createdAt, DateTime.utc(2026, 10, 28, 12));
      expect(perfil.updatedAt, DateTime.utc(2026, 10, 28, 13));
      expect(perfil.createdAt!.isUtc, isTrue);
    });

    test('ignora um campo "uid" no conteúdo: a identidade é o ID do documento', () {
      final dados = _dadosValidos()..['uid'] = 'outro-uid';

      expect(UserProfile.fromMap('uid-123', dados).uid, 'uid-123');
    });

    test('aceita datas nulas (serverTimestamp ainda pendente)', () {
      final dados = _dadosValidos()
        ..['createdAt'] = null
        ..remove('updatedAt');

      final perfil = UserProfile.fromMap('uid-123', dados);

      expect(perfil.createdAt, isNull);
      expect(perfil.updatedAt, isNull);
    });

    test('rejeita UID vazio', () {
      expect(
        () => UserProfile.fromMap('  ', _dadosValidos()),
        throwsFormatException,
      );
    });

    for (final campo in ['displayName', 'username', 'usernameNormalized', 'email']) {
      test('rejeita "$campo" ausente, vazio ou com tipo errado', () {
        for (final invalido in [null, '', '   ', 42]) {
          final dados = _dadosValidos()..[campo] = invalido;
          expect(
            () => UserProfile.fromMap('uid-123', dados),
            throwsFormatException,
            reason: '$campo = $invalido',
          );
        }
      });
    }

    test('rejeita data em formato de texto', () {
      final dados = _dadosValidos()..['createdAt'] = '28/10/2026 12:00';

      expect(
        () => UserProfile.fromMap('uid-123', dados),
        throwsFormatException,
      );
    });
  });

  group('UserProfile.toMap', () {
    test('não grava o UID nem campos financeiros', () {
      final mapa = UserProfile.fromMap('uid-123', _dadosValidos()).toMap();

      expect(mapa.containsKey('uid'), isFalse);
      expect(
        mapa.keys.toSet(),
        {'displayName', 'username', 'usernameNormalized', 'email', 'createdAt', 'updatedAt'},
      );
    });

    test('grava datas como Timestamp em UTC', () {
      final local = DateTime(2026, 10, 28, 9, 30);
      final perfil = UserProfile(
        uid: 'uid-123',
        displayName: 'Pedro',
        username: 'pedro',
        usernameNormalized: 'pedro',
        email: 'pedro@example.com',
        createdAt: local,
      );

      final mapa = perfil.toMap();

      expect(mapa['createdAt'], isA<Timestamp>());
      expect((mapa['createdAt'] as Timestamp).toDate().toUtc(), local.toUtc());
      expect(mapa.containsKey('updatedAt'), isFalse);
    });

    test('ida e volta preserva os dados', () {
      final original = UserProfile.fromMap('uid-123', _dadosValidos());
      final copia = UserProfile.fromMap('uid-123', original.toMap());

      expect(copia.displayName, original.displayName);
      expect(copia.username, original.username);
      expect(copia.usernameNormalized, original.usernameNormalized);
      expect(copia.email, original.email);
      expect(copia.createdAt, original.createdAt);
      expect(copia.updatedAt, original.updatedAt);
    });
  });

  group('UserProfileException.fromFirebase', () {
    final casos = {
      'permission-denied': UserProfileErrorCode.permissionDenied,
      'unauthenticated': UserProfileErrorCode.unauthenticated,
      'already-exists': UserProfileErrorCode.alreadyExists,
      'unavailable': UserProfileErrorCode.unavailable,
      'deadline-exceeded': UserProfileErrorCode.unavailable,
      'internal': UserProfileErrorCode.unknown,
    };

    casos.forEach((codigoFirebase, esperado) {
      test('$codigoFirebase -> ${esperado.name}', () {
        final erro = UserProfileException.fromFirebase(
          FirebaseException(plugin: 'cloud_firestore', code: codigoFirebase),
        );
        expect(erro.code, esperado);
        expect(erro.message, isNotEmpty);
      });
    });
  });

  group('FirestoreUserProfileRepository', () {
    // UID vazio é rejeitado antes de qualquer acesso ao Firestore
    final repository = FirestoreUserProfileRepository();
    final invalidData = isA<UserProfileException>()
        .having((e) => e.code, 'code', UserProfileErrorCode.invalidData);

    test('buscarPorUid rejeita UID vazio', () {
      expect(repository.buscarPorUid(''), throwsA(invalidData));
    });

    test('observarPorUid rejeita UID vazio', () {
      expect(() => repository.observarPorUid(' '), throwsA(invalidData));
    });

    test('criar rejeita perfil sem UID', () {
      const perfil = UserProfile(
        uid: '',
        displayName: 'Pedro',
        username: 'pedro',
        usernameNormalized: 'pedro',
        email: 'pedro@example.com',
      );
      expect(repository.criar(perfil), throwsA(invalidData));
    });

    test('atualizarDisplayName rejeita UID vazio', () {
      expect(repository.atualizarDisplayName(' ', 'Nome'), throwsA(invalidData));
    });
  });
}
