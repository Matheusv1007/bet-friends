import 'dart:async';

import 'package:betfriends/provider/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

void main() {
  group('AuthProvider - signOut', () {
    test('sinaliza isSigningOut durante o logout e limpa ao terminar', () async {
      final auth = FakeAuthService(usuarioInicial: FakeUser('uid-1'))
        ..signOutEmAndamento = Completer<void>();
      final provider = AuthProvider(authService: auth);
      var notificacoes = 0;
      provider.addListener(() => notificacoes++);

      final logout = provider.signOut();
      expect(provider.isSigningOut, isTrue);

      auth.signOutEmAndamento!.complete();
      await logout;

      expect(provider.isSigningOut, isFalse);
      expect(auth.currentUser, isNull);
      expect(notificacoes, 2);
    });

    test('chamadas simultâneas executam um único signOut', () async {
      final auth = FakeAuthService(usuarioInicial: FakeUser('uid-1'))
        ..signOutEmAndamento = Completer<void>();
      final provider = AuthProvider(authService: auth);

      final primeira = provider.signOut();
      final segunda = provider.signOut();
      auth.signOutEmAndamento!.complete();
      await Future.wait([primeira, segunda]);

      expect(auth.signOutCalls, 1);
    });

    test('falha é repassada à tela e o estado de carregamento é liberado', () async {
      final auth = FakeAuthService(usuarioInicial: FakeUser('uid-1'))
        ..signOutError = Exception('falha simulada');
      final provider = AuthProvider(authService: auth);

      await expectLater(provider.signOut(), throwsA(isA<Exception>()));

      expect(provider.isSigningOut, isFalse);
      expect(auth.currentUser, isNotNull);
    });
  });
}
