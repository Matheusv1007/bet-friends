import 'dart:async';

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/services/functions/functions_service.dart';
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

/// Repositório em memória com o mesmo contrato do Firestore: documento
/// ausente → null. Não tem criação: o perfil é criado só pelo backend.
class _RepositorioEmMemoria implements UserProfileRepository {
  final perfis = <String, UserProfile>{};
  final uidsConsultados = <String>[];
  UserProfileException? erro;

  @override
  Future<UserProfile?> buscarPorUid(String uid) async {
    uidsConsultados.add(uid);
    if (erro != null) throw erro!;
    return perfis[uid];
  }

  @override
  Stream<PerfilObservado> observarPorUid(String uid) async* {
    uidsConsultados.add(uid);
    yield PerfilObservado(perfis[uid]);
  }

  final nomesGravados = <String, String>{};

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {
    if (erro != null) throw erro!;
    nomesGravados[uid] = displayName;
  }
}

/// Registra as chamadas às Callables e devolve a resposta (ou o erro) definida
/// pelo teste. Não simula o backend: o comportamento real de createUserProfile
/// é testado no emulador (integration_test/criar_perfil_emulator_test.dart).
class _FunctionsFalso implements FunctionsService {
  final chamadas = <(String, Map<String, dynamic>?)>[];
  Object? erro;
  Map<String, dynamic> resposta = const {};

  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
    chamadas.add((name, data));
    if (erro != null) throw erro!;
    return resposta;
  }

  @override
  Future<PingResult> ping() => throw UnimplementedError();
}

Matcher _erro(UserProfileErrorCode code) =>
    throwsA(isA<UserProfileException>().having((e) => e.code, 'code', code));

void main() {
  late _RepositorioEmMemoria repositorio;
  late _FunctionsFalso functions;

  UserProfileService servicoCom(User? usuario) => UserProfileService(
        authService: FakeAuthService(usuarioInicial: usuario),
        repository: repositorio,
        functionsService: functions,
      );

  setUp(() {
    repositorio = _RepositorioEmMemoria();
    functions = _FunctionsFalso();
  });

  group('Sem sessão', () {
    test('carregar, observar e criar exigem usuário autenticado', () {
      final servico = servicoCom(null);

      expect(servico.carregarPerfilAtual, _erro(UserProfileErrorCode.unauthenticated));
      expect(servico.observarPerfilAtual, _erro(UserProfileErrorCode.unauthenticated));
      expect(
        () => servico.criarPerfilDoUsuarioAtual(displayName: 'Pedro', username: 'pedro'),
        _erro(UserProfileErrorCode.unauthenticated),
      );
      expect(repositorio.uidsConsultados, isEmpty);
      expect(functions.chamadas, isEmpty);
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

    test('observa o perfil do UID atual', () async {
      repositorio.perfis['uid-g'] = const UserProfile(
        uid: 'uid-g',
        displayName: 'G',
        username: 'g_g',
        usernameNormalized: 'g_g',
        email: 'g@example.com',
      );

      final observado = await servicoCom(_UsuarioComEmail('uid-g', 'g@example.com'))
          .observarPerfilAtual()
          .first;

      expect(observado.perfil?.uid, 'uid-g');
      expect(repositorio.uidsConsultados, ['uid-g']);
    });
  });

  group('atualizarDisplayNameAtual', () {
    test('grava o nome sem espaços nas pontas no UID da sessão', () async {
      await servicoCom(_UsuarioComEmail('uid-h', 'h@example.com'))
          .atualizarDisplayNameAtual('  Helena Dias ');

      expect(repositorio.nomesGravados, {'uid-h': 'Helena Dias'});
    });

    test('aceita 60 caracteres', () async {
      await servicoCom(_UsuarioComEmail('uid-h', 'h@example.com'))
          .atualizarDisplayNameAtual('a' * 60);

      expect(repositorio.nomesGravados['uid-h'], hasLength(60));
    });

    for (final invalido in ['', '   ', 'a' * 61]) {
      test('rejeita "${invalido.length > 10 ? '${invalido.length} caracteres' : invalido}" sem gravar', () async {
        await expectLater(
          servicoCom(_UsuarioComEmail('uid-h', 'h@example.com'))
              .atualizarDisplayNameAtual(invalido),
          _erro(UserProfileErrorCode.invalidData),
        );
        expect(repositorio.nomesGravados, isEmpty);
      });
    }

    test('exige usuário autenticado', () async {
      await expectLater(
        servicoCom(null).atualizarDisplayNameAtual('Nome'),
        _erro(UserProfileErrorCode.unauthenticated),
      );
      expect(repositorio.nomesGravados, isEmpty);
    });

    test('repassa erro do repositório (ex.: Rules negando acesso)', () async {
      repositorio.erro = const UserProfileException(
        UserProfileErrorCode.permissionDenied,
        'Sem permissão para acessar o perfil.',
      );

      await expectLater(
        servicoCom(_UsuarioComEmail('uid-h', 'h@example.com'))
            .atualizarDisplayNameAtual('Nome'),
        _erro(UserProfileErrorCode.permissionDenied),
      );
    });
  });

  group('criarPerfilDoUsuarioAtual (Callable createUserProfile)', () {
    const respostaDaBia = {
      'criado': true,
      'displayName': 'Bia Souza',
      'username': 'BiaS',
      'usernameNormalized': 'bias',
    };

    test('chama createUserProfile só com nome e username, sem UID nem e-mail', () async {
      functions.resposta = respostaDaBia;

      await servicoCom(_UsuarioComEmail('uid-b', 'bia@example.com'))
          .criarPerfilDoUsuarioAtual(displayName: '  Bia Souza ', username: ' BiaS ');

      expect(functions.chamadas, hasLength(1));
      final (nome, dados) = functions.chamadas.single;
      expect(nome, CallableNames.createUserProfile);
      // O backend faz trim, valida e normaliza; UID e e-mail vêm do token
      expect(dados, {'displayName': '  Bia Souza ', 'username': ' BiaS '});
    });

    test('não grava nada pelo repositório (nenhuma escrita direta em users/{uid})', () async {
      functions.resposta = respostaDaBia;

      await servicoCom(_UsuarioComEmail('uid-b', 'bia@example.com'))
          .criarPerfilDoUsuarioAtual(displayName: 'Bia Souza', username: 'BiaS');

      expect(repositorio.perfis, isEmpty);
      expect(repositorio.nomesGravados, isEmpty);
      expect(repositorio.uidsConsultados, isEmpty);
    });

    test('devolve UserProfile do UID da sessão com os dados confirmados pelo backend', () async {
      functions.resposta = respostaDaBia;

      final r = await servicoCom(_UsuarioComEmail('uid-b', 'bia@example.com'))
          .criarPerfilDoUsuarioAtual(displayName: '  Bia Souza ', username: ' BiaS ');

      expect(r.criado, isTrue);
      expect(r.perfil.uid, 'uid-b');
      expect(r.perfil.email, 'bia@example.com');
      expect(r.perfil.displayName, 'Bia Souza');
      expect(r.perfil.username, 'BiaS');
      expect(r.perfil.usernameNormalized, 'bias');
    });

    test('repetição com o perfil já criado devolve criado == false, sem erro', () async {
      functions.resposta = {...respostaDaBia, 'criado': false};

      final r = await servicoCom(_UsuarioComEmail('uid-b', 'bia@example.com'))
          .criarPerfilDoUsuarioAtual(displayName: 'Bia Souza', username: 'BiaS');

      expect(r.criado, isFalse);
      expect(r.perfil.username, 'BiaS');
    });

    test('conta sem e-mail é recusada sem chamar o backend', () async {
      await expectLater(
        servicoCom(_UsuarioComEmail('uid-e', null))
            .criarPerfilDoUsuarioAtual(displayName: 'E', username: 'eee'),
        _erro(UserProfileErrorCode.invalidData),
      );
      expect(functions.chamadas, isEmpty);
    });

    final casos = <(String, String?, UserProfileErrorCode)>[
      ('unauthenticated', null, UserProfileErrorCode.unauthenticated),
      ('invalid-argument', 'username-invalido', UserProfileErrorCode.invalidData),
      ('invalid-argument', 'nome-invalido', UserProfileErrorCode.invalidData),
      ('invalid-argument', null, UserProfileErrorCode.invalidData),
      ('already-exists', 'username-indisponivel', UserProfileErrorCode.usernameUnavailable),
      ('failed-precondition', 'perfil-existente', UserProfileErrorCode.alreadyExists),
      ('failed-precondition', 'email-ausente', UserProfileErrorCode.invalidData),
      ('failed-precondition', null, UserProfileErrorCode.unknown),
      ('unavailable', null, UserProfileErrorCode.unavailable),
      ('deadline-exceeded', null, UserProfileErrorCode.unavailable),
      ('not-found', null, UserProfileErrorCode.unknown),
      ('internal', null, UserProfileErrorCode.unknown),
      ('resource-exhausted', null, UserProfileErrorCode.unknown),
    ];
    for (final (code, motivo, esperado) in casos) {
      test('$code${motivo == null ? '' : ' ($motivo)'} → ${esperado.name}, sem a mensagem técnica', () async {
        const tecnica = 'stack: Error at criarPerfilTransacao.ts:42';
        functions.erro = FunctionsException(code: code, message: tecnica, motivo: motivo);

        await expectLater(
          servicoCom(_UsuarioComEmail('uid-x', 'x@example.com'))
              .criarPerfilDoUsuarioAtual(displayName: 'X', username: 'xxx'),
          throwsA(isA<UserProfileException>()
              .having((e) => e.code, 'code', esperado)
              .having((e) => e.message, 'message', isNot(contains('stack')))),
        );
        expect(functions.chamadas, hasLength(1), reason: 'sem repetição automática');
      });
    }

    final respostasInesperadas = <String, Map<String, dynamic>>{
      'vazia': {},
      'sem criado': {...respostaDaBia}..remove('criado'),
      'criado não booleano': {...respostaDaBia, 'criado': 'sim'},
      'sem username': {...respostaDaBia}..remove('username'),
      'nome vazio': {...respostaDaBia, 'displayName': ' '},
    };
    respostasInesperadas.forEach((caso, resposta) {
      test('resposta inesperada ($caso) → unknown', () async {
        functions.resposta = resposta;

        await expectLater(
          servicoCom(_UsuarioComEmail('uid-y', 'y@example.com'))
              .criarPerfilDoUsuarioAtual(displayName: 'Y', username: 'yyy'),
          _erro(UserProfileErrorCode.unknown),
        );
      });
    });

    test('nova tentativa depois de uma falha chama o backend de novo', () async {
      final servico = servicoCom(_UsuarioComEmail('uid-b', 'bia@example.com'));
      functions.erro = FunctionsException(code: 'unavailable', message: 'x');
      await expectLater(
        servico.criarPerfilDoUsuarioAtual(displayName: 'Bia Souza', username: 'BiaS'),
        _erro(UserProfileErrorCode.unavailable),
      );

      functions
        ..erro = null
        ..resposta = {...respostaDaBia, 'criado': false};
      final r = await servico.criarPerfilDoUsuarioAtual(displayName: 'Bia Souza', username: 'BiaS');

      expect(r.criado, isFalse);
      expect(functions.chamadas, hasLength(2));
    });
  });
}
