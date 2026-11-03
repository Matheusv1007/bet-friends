import 'package:flutter_test/flutter_test.dart';

import 'package:betfriends/models/usuario_publico.dart';

void main() {
  group('UsuarioPublico - Modelo de Dados Públicos (RF-004, RN-PROF-002, RN-AUTH-006)', () {
    test('identifica usuário pelo userId e expõe apenas nome e username', () {
      const usuario = UsuarioPublico(
        userId: 'uid-carlos-123',
        displayName: 'Carlos Eduardo',
        username: 'carlosedu',
      );

      expect(usuario.userId, 'uid-carlos-123');
      expect(usuario.displayName, 'Carlos Eduardo');
      expect(usuario.username, 'carlosedu');
      expect(usuario.usernameComArroba, '@carlosedu');
    });

    test('fromMap ignora e não expõe campos privados como email, saldos e transações (RN-PROF-002)', () {
      final dadosBrutosDoFirestore = {
        'userId': 'uid-ana-456',
        'displayName': 'Ana Beatriz',
        'username': '@anabeatriz',
        // Campos privados que NÃO podem ser expostos:
        'email': 'ana.privado@example.com',
        'saldoTotal': 5000,
        'saldoReservado': 1200,
        'betCoinTransactions': ['tx-1', 'tx-2'],
        'internalRole': 'admin',
      };

      final publico = UsuarioPublico.fromMap(dadosBrutosDoFirestore);

      expect(publico.userId, 'uid-ana-456');
      expect(publico.displayName, 'Ana Beatriz');
      expect(publico.username, 'anabeatriz');

      final mapaPublico = publico.toMap();
      expect(mapaPublico.containsKey('email'), isFalse);
      expect(mapaPublico.containsKey('saldoTotal'), isFalse);
      expect(mapaPublico.containsKey('saldoReservado'), isFalse);
      expect(mapaPublico.containsKey('betCoinTransactions'), isFalse);
      expect(mapaPublico.containsKey('internalRole'), isFalse);
      expect(mapaPublico.keys.toSet(), {'userId', 'displayName', 'username'});
    });

    test('fromMap valida obrigatoriedade do userId como identidade estável (RN-AUTH-006)', () {
      expect(
        () => UsuarioPublico.fromMap({'displayName': 'Sem UID', 'username': 'sem_uid'}),
        throwsFormatException,
      );
    });

    test('igualdade e hashCode são baseados estritamente na identidade estável por userId', () {
      const u1 = UsuarioPublico(userId: 'uid-1', displayName: 'Nome 1', username: 'user1');
      const u2 = UsuarioPublico(userId: 'uid-1', displayName: 'Nome Alterado', username: 'user1_alt');
      const u3 = UsuarioPublico(userId: 'uid-2', displayName: 'Nome 1', username: 'user1');

      expect(u1, equals(u2));
      expect(u1.hashCode, equals(u2.hashCode));
      expect(u1, isNot(equals(u3)));
    });
  });
}
