import 'dart:async';

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

class _UsuarioComEmail extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;

  _UsuarioComEmail(this.uid, this.email);
}

/// Repositório em memória com o mesmo contrato do Firestore:
/// documento ausente → null; criar sobre documento existente → alreadyExists.
class _RepositorioEmMemoria implements UserProfileRepository {
  final perfis = <String, UserProfile>{};
  final uidsConsultados = <String>[];
  final _mudancas = StreamController<String>.broadcast();
  UserProfileException? erro;

  @override
  Future<UserProfile?> buscarPorUid(String uid) async {
    uidsConsultados.add(uid);
    if (erro != null) throw erro!;
    return perfis[uid];
  }

  @override
  Stream<UserProfile?> observarPorUid(String uid) async* {
    uidsConsultados.add(uid);
    yield perfis[uid];
    yield* _mudancas.stream.where((u) => u == uid).map((u) => perfis[u]);
  }

  @override
  Future<void> criar(UserProfile perfil) async {
    if (erro != null) throw erro!;
    if (perfis.containsKey(perfil.uid)) {
      throw const UserProfileException(
        UserProfileErrorCode.alreadyExists,
        'O perfil deste usuário já existe.',
      );
    }
    perfis[perfil.uid] = perfil;
    _mudancas.add(perfil.uid);
  }
}

Matcher _erro(UserProfileErrorCode code) =>
    throwsA(isA<UserProfileException>().having((e) => e.code, 'code', code));

void main() {
  late _RepositorioEmMemoria repositorio;

  UserProfileService servicoCom(User? usuario) => UserProfileService(
        authService: FakeAuthService(usuarioInicial: usuario),
        repository: repositorio,
      );

  setUp(() => repositorio = _RepositorioEmMemoria());

  group('Sem sessão', () {
    test('carregar, observar e criar exigem usuário autenticado', () {
      final servico = servicoCom(null);

      expect(servico.carregarPerfilAtual, _erro(UserProfileErrorCode.unauthenticated));
      expect(servico.observarPerfilAtual, _erro(UserProfileErrorCode.unauthenticated));
      expect(
        () => servico.criarPerfilDoUsuarioAtual(
          displayName: 'Pedro',
          username: 'pedro',
          usernameNormalized: 'pedro',
        ),
        _erro(UserProfileErrorCode.unauthenticated),
      );
      expect(repositorio.uidsConsultados, isEmpty);
    });
  });

  group('Com sessão', () {
    test('carrega o perfil pelo UID do Firebase Auth', () async {
      repositorio.perfis['uid-a'] = const UserProfile(
        uid: 'uid-a',
        displayName: 'Ana',
        username: 'ana',
        usernameNormalized: 'ana',
        email: 'ana@example.com',
      );

      final perfil = await servicoCom(_UsuarioComEmail('uid-a', 'ana@example.com'))
          .carregarPerfilAtual();

      expect(perfil?.uid, 'uid-a');
      expect(repositorio.uidsConsultados, ['uid-a']);
    });

    test('perfil inexistente retorna null, sem erro', () async {
      final perfil = await servicoCom(_UsuarioComEmail('uid-sem-perfil', 'x@example.com'))
          .carregarPerfilAtual();

      expect(perfil, isNull);
    });

    test('cria o perfil com UID e e-mail da sessão, não da tela', () async {
      final servico = servicoCom(_UsuarioComEmail('uid-b', 'bia@example.com'));

      final criado = await servico.criarPerfilDoUsuarioAtual(
        displayName: '  Bia Souza ',
        username: ' BiaS ',
        usernameNormalized: 'bias',
      );

      expect(criado.uid, 'uid-b');
      expect(criado.email, 'bia@example.com');
      expect(criado.displayName, 'Bia Souza');
      expect(criado.username, 'BiaS');
      expect(repositorio.perfis.keys, ['uid-b']);
    });

    test('não sobrescreve um perfil existente', () async {
      final servico = servicoCom(_UsuarioComEmail('uid-c', 'c@example.com'));
      await servico.criarPerfilDoUsuarioAtual(
        displayName: 'Carlos',
        username: 'carlos',
        usernameNormalized: 'carlos',
      );

      await expectLater(
        servico.criarPerfilDoUsuarioAtual(
          displayName: 'Outro Nome',
          username: 'outro',
          usernameNormalized: 'outro',
        ),
        _erro(UserProfileErrorCode.alreadyExists),
      );
      expect(repositorio.perfis['uid-c']!.displayName, 'Carlos');
    });

    test('rejeita nome ou username vazios sem gravar', () async {
      final servico = servicoCom(_UsuarioComEmail('uid-d', 'd@example.com'));

      await expectLater(
        servico.criarPerfilDoUsuarioAtual(
          displayName: '   ',
          username: 'd',
          usernameNormalized: 'd',
        ),
        _erro(UserProfileErrorCode.invalidData),
      );
      expect(repositorio.perfis, isEmpty);
    });

    test('rejeita usuário autenticado sem e-mail', () async {
      final servico = servicoCom(_UsuarioComEmail('uid-e', null));

      await expectLater(
        servico.criarPerfilDoUsuarioAtual(
          displayName: 'E',
          username: 'e',
          usernameNormalized: 'e',
        ),
        _erro(UserProfileErrorCode.invalidData),
      );
    });

    test('repassa erros do repositório (ex.: Rules negando acesso)', () async {
      repositorio.erro = const UserProfileException(
        UserProfileErrorCode.permissionDenied,
        'Sem permissão para acessar o perfil.',
      );

      await expectLater(
        servicoCom(_UsuarioComEmail('uid-f', 'f@example.com')).carregarPerfilAtual(),
        _erro(UserProfileErrorCode.permissionDenied),
      );
    });

    test('observa o perfil do UID atual e recebe a criação', () async {
      final servico = servicoCom(_UsuarioComEmail('uid-g', 'g@example.com'));
      final emissoes = <String?>[];
      final sub = servico.observarPerfilAtual().listen((p) => emissoes.add(p?.uid));

      await Future<void>.delayed(Duration.zero);
      await servico.criarPerfilDoUsuarioAtual(
        displayName: 'G',
        username: 'g',
        usernameNormalized: 'g',
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emissoes, [null, 'uid-g']);
      expect(repositorio.uidsConsultados, ['uid-g']);
    });
  });
}
