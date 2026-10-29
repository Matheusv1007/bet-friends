import 'dart:async';

import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;

  FakeUser(this.uid, {this.email});
}

/// Simula o Firebase Auth sem rede: `authStateChanges` emite o estado atual
/// ao ser assinado (como o SDK real) e depois cada mudança de sessão.
class FakeAuthService extends AuthService {
  User? _usuario;
  final bool sessaoPendente;
  final _mudancas = StreamController<User?>.broadcast();

  Object? signInError;
  Object? signOutError;

  /// Quando definido, o signOut só termina ao completar este Completer.
  Completer<void>? signOutEmAndamento;

  int signInCalls = 0;
  int signOutCalls = 0;

  Object? signUpError;
  int signUpCalls = 0;

  FakeAuthService({User? usuarioInicial, this.sessaoPendente = false})
      : _usuario = usuarioInicial;

  @override
  User? get currentUser => _usuario;

  @override
  Stream<User?> get authStateChanges async* {
    if (!sessaoPendente) yield _usuario;
    yield* _mudancas.stream;
  }

  /// Conclui a verificação inicial da sessão quando [sessaoPendente] é true.
  void resolverSessao(User? usuario) {
    _usuario = usuario;
    _mudancas.add(usuario);
  }

  /// Simula o fim da sessão por fora do app (ex.: token revogado).
  void encerrarSessaoExternamente() {
    _usuario = null;
    _mudancas.add(null);
  }

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (signInError != null) throw signInError!;
    _usuario = FakeUser('uid-$email');
    _mudancas.add(_usuario);
    return _FakeUserCredential(_usuario!);
  }

  /// Como o Firebase: cria a conta e já entra com ela.
  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    if (signUpError != null) throw signUpError!;
    _usuario = FakeUser('uid-$email', email: email);
    _mudancas.add(_usuario);
    return _FakeUserCredential(_usuario!);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutEmAndamento != null) await signOutEmAndamento!.future;
    if (signOutError != null) throw signOutError!;
    _usuario = null;
    _mudancas.add(null);
  }
}

class _FakeUserCredential extends Fake implements UserCredential {
  @override
  final User user;

  _FakeUserCredential(this.user);
}

/// Serviço de partidas sem rede que conta quantas buscas foram feitas.
class CountingPartidasService extends PartidasService {
  int chamadas = 0;

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    chamadas++;
    return [
      PartidaModel(
        id: '1',
        timeMandante: 'Time A',
        timeVisitante: 'Time B',
        status: 'PRÓXIMO JOGO',
        horario: 'Hoje 20:00',
      ),
    ];
  }
}
