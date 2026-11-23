// ignore_for_file: subtype_of_sealed_class
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _Credential extends Fake implements UserCredential {}

class _User extends Fake implements User {
  _User(this.passos);
  final List<String> passos;
  Object? erro;
  Object? erroToken;
  EmailAuthCredential? credencial;

  @override
  String? get email => 'sessao@example.com';

  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async {
    passos.add('reauth');
    credencial = credential as EmailAuthCredential;
    if (erro != null) throw erro!;
    return _Credential();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    passos.add('token:$forceRefresh');
    if (erroToken != null) throw erroToken!;
    return 'token-renovado';
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.passos, this.user);
  final List<String> passos;
  User? user;
  Object? erroSaida;

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut() async {
    passos.add('signOut');
    if (erroSaida != null) throw erroSaida!;
    user = null;
  }
}

class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.passos);
  final List<String> passos;

  @override
  Future<void> terminate() async => passos.add('terminate');

  @override
  Future<void> clearPersistence() async => passos.add('clearPersistence');
}

class _Functions extends Fake implements FunctionsService {
  _Functions(this.passos);
  final List<String> passos;
  Object? erro;
  Map<String, dynamic> resposta = {'deleted': true};

  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
    passos.add(name);
    expect(name, CallableNames.deleteAccount);
    expect(data, isNotNull);
    expect(data, isEmpty);
    if (erro != null) throw erro!;
    return resposta;
  }
}

void main() {
  late List<String> passos;
  late _User user;
  late _Auth auth;
  late _Functions functions;
  late AuthService service;

  setUp(() {
    passos = [];
    user = _User(passos);
    auth = _Auth(passos, user);
    functions = _Functions(passos);
    service = AuthService(
      firebaseAuth: auth,
      firestore: _Firestore(passos),
      functionsService: functions,
    );
  });

  Matcher erroDe(String code) => throwsA(
    isA<DeleteAccountException>().having((e) => e.code, 'code', code),
  );

  test('reautentica com e-mail da sessão, renova token, chama {} e limpa sessão/cache', () async {
    await service.deleteAccount(password: 'senha-secreta');
    expect(user.credencial!.email, 'sessao@example.com');
    expect(user.credencial!.password, 'senha-secreta');
    expect(passos, [
      'reauth', 'token:true', 'deleteAccount',
      'signOut', 'terminate', 'clearPersistence',
    ]);
    expect(auth.currentUser, isNull);
  });

  for (final code in ['wrong-password', 'invalid-credential', 'network-request-failed', 'requires-recent-login']) {
    test('$code na reautenticação não chama backend nem sai da sessão', () async {
      user.erro = FirebaseAuthException(code: code);
      await expectLater(service.deleteAccount(password: 'senha'), erroDe(code));
      expect(passos, ['reauth']);
      expect(auth.currentUser, same(user));
    });
  }

  test('falha na renovação do token não chama backend nem confirma exclusão', () async {
    user.erroToken = FirebaseAuthException(code: 'network-request-failed');
    await expectLater(service.deleteAccount(password: 'senha'), erroDe('network-request-failed'));
    expect(passos, ['reauth', 'token:true']);
  });

  for (final motivo in ['desafio-ativo', 'saldo-reservado', 'login-recente-necessario']) {
    test('traduz motivo $motivo e preserva sessão', () async {
      functions.erro = FunctionsException(
        code: 'failed-precondition', message: 'interno', motivo: motivo,
      );
      await expectLater(service.deleteAccount(password: 'senha'), erroDe(motivo));
      expect(passos, ['reauth', 'token:true', 'deleteAccount']);
      expect(auth.currentUser, same(user));
    });
  }

  for (final code in ['unavailable', 'deadline-exceeded', 'internal']) {
    test('$code na callable não confirma nem encerra sessão', () async {
      functions.erro = FunctionsException(code: code, message: 'interno');
      await expectLater(service.deleteAccount(password: 'senha'), erroDe(code));
      expect(passos, ['reauth', 'token:true', 'deleteAccount']);
    });
  }

  test('resposta sem deleted true não é sucesso', () async {
    functions.resposta = {};
    await expectLater(service.deleteAccount(password: 'senha'), erroDe('unknown'));
    expect(auth.currentUser, same(user));
  });

  for (final code in ['user-not-found', 'unauthenticated']) {
    test('$code na reautenticação encerra sessão e limpa cache', () async {
      user.erro = FirebaseAuthException(code: code);
      await expectLater(service.deleteAccount(password: 'senha'), erroDe(code));
      expect(passos, ['reauth', 'signOut', 'terminate', 'clearPersistence']);
    });

    test('$code no logout após exclusão não impede limpeza de cache', () async {
      auth.erroSaida = FirebaseAuthException(code: code);
      await service.deleteAccount(password: 'senha');
      expect(passos, [
        'reauth', 'token:true', 'deleteAccount',
        'signOut', 'terminate', 'clearPersistence',
      ]);
    });
  }

  test('callable unauthenticated limpa sessão/cache sem anunciar sucesso', () async {
    functions.erro = FunctionsException(code: 'unauthenticated', message: 'interno');
    await expectLater(service.deleteAccount(password: 'senha'), erroDe('unauthenticated'));
    expect(passos, [
      'reauth', 'token:true', 'deleteAccount',
      'signOut', 'terminate', 'clearPersistence',
    ]);
  });

  test('sessão ausente limpa cache e não chama backend', () async {
    auth.user = null;
    await expectLater(service.deleteAccount(password: 'senha'), erroDe('unauthenticated'));
    expect(passos, ['signOut', 'terminate', 'clearPersistence']);
  });
}
