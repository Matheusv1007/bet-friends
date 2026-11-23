import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthQueRegistra extends Fake implements FirebaseAuth {
  final emailsUsados = <String>[];

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    emailsUsados.add(email);
    throw FirebaseAuthException(code: 'invalid-credential');
  }
}

class _Backend implements FunctionsService {
  final chamadas = <Map<String, dynamic>?>[];
  Object? resultado;

  _Backend({this.resultado});

  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
    expect(name, CallableNames.resolveLoginEmail);
    chamadas.add(data);
    final r = resultado;
    if (r is Exception) throw r;
    return {'email': r};
  }

  @override
  Future<PingResult> ping() => throw UnimplementedError();
}

void main() {
  late _AuthQueRegistra auth;

  AuthService servico(_Backend backend) =>
      AuthService(firebaseAuth: auth, functionsService: backend);

  setUp(() => auth = _AuthQueRegistra());

  group('AuthService.signIn - e-mail ou username', () {
    test('e-mail entra direto, sem consultar o backend', () async {
      final backend = _Backend();

      await expectLater(
        servico(backend).signIn(identifier: ' ana@example.com ', password: 'x'),
        throwsA(isA<FirebaseAuthException>()),
      );

      expect(backend.chamadas, isEmpty);
      expect(auth.emailsUsados, ['ana@example.com']);
    });

    test('username é convertido no e-mail da conta, com ou sem @ inicial', () async {
      for (final digitado in ['Ana_A', '@Ana_A']) {
        final backend = _Backend(resultado: 'ana@example.com');
        auth.emailsUsados.clear();

        await expectLater(
          servico(backend).signIn(identifier: digitado, password: 'x'),
          throwsA(isA<FirebaseAuthException>()),
        );

        expect(backend.chamadas, [
          {'username': digitado}
        ]);
        expect(auth.emailsUsados, ['ana@example.com'], reason: digitado);
      }
    });

    test('username inexistente falha como credencial inválida, sem tentar o Auth', () async {
      final backend = _Backend(resultado: null);

      await expectLater(
        servico(backend).signIn(identifier: 'ninguem', password: 'x'),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'invalid-credential')),
      );

      expect(auth.emailsUsados, isEmpty);
    });

    test('falha de rede e limite de uso viram erros que a tela já trata', () async {
      final casos = {
        'unavailable': 'network-request-failed',
        'deadline-exceeded': 'network-request-failed',
        'resource-exhausted': 'too-many-requests',
      };
      for (final MapEntry(key: codigoDoBackend, value: codigoDoAuth) in casos.entries) {
        final backend = _Backend(
          resultado: FunctionsException(code: codigoDoBackend, message: 'x'),
        );

        await expectLater(
          servico(backend).signIn(identifier: 'ana_a', password: 'x'),
          throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', codigoDoAuth)),
          reason: codigoDoBackend,
        );
      }
      expect(auth.emailsUsados, isEmpty);
    });
  });
}
