import 'package:flutter_test/flutter_test.dart';

import 'package:betfriends/data/firestore/friendship_repository.dart';
import 'package:betfriends/models/friendship_model.dart';
import 'package:betfriends/models/usuario_publico.dart';
import 'package:betfriends/services/friendship_service.dart';
import 'package:betfriends/services/functions/functions_service.dart';

import '../support/fake_auth.dart';

class _FakeFriendshipRepository implements FriendshipRepository {
  String? amizadeRemovida;

  @override
  Future<void> removerAmizade(String friendshipId) async {
    if (simularErroConexao) {
      throw const FriendshipException(
        FriendshipErrorCode.unavailable,
        'Serviço temporariamente indisponível. Verifique sua conexão.',
      );
    }
    amizadeRemovida = friendshipId;
    statusAmizades[friendshipId] = 'REMOVED';
  }

  final Map<String, String> statusAmizades = {}; // friendshipId -> status
  final Map<String, String> requesterIds = {}; // friendshipId -> requesterId
  bool simularErroConexao = false;

  String _calcFriendshipId(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  @override
  Future<ResultadoEnvioAmizade> enviarSolicitacaoAmizade(String toUserId) async {
    if (simularErroConexao) {
      throw const FriendshipException(
        FriendshipErrorCode.unavailable,
        'Serviço temporariamente indisponível. Verifique sua conexão.',
      );
    }

    // O repositório real chama a Function que usa o auth.uid do chamador
    final friendshipId = _calcFriendshipId(_currentCallingUid, toUserId);
    final statusAtual = statusAmizades[friendshipId];
    final reqAtual = requesterIds[friendshipId];

    if (statusAtual == 'ACCEPTED') {
      throw const FriendshipException(
        FriendshipErrorCode.alreadyFriends,
        'Vocês já são amigos.',
      );
    }

    if (statusAtual == 'PENDING') {
      if (reqAtual == _currentCallingUid) {
        throw const FriendshipException(
          FriendshipErrorCode.alreadyRequested,
          'Já existe uma solicitação de amizade pendente para este usuário.',
        );
      }
      if (reqAtual == toUserId) {
        // Solicitação cruzada: aceitação automática (RN-FRD-005)
        statusAmizades[friendshipId] = 'ACCEPTED';
        return ResultadoEnvioAmizade(
          friendshipId: friendshipId,
          status: FriendshipStatus.accepted,
          autoAccepted: true,
        );
      }
    }

    // Nova solicitação pendente válida
    statusAmizades[friendshipId] = 'PENDING';
    requesterIds[friendshipId] = _currentCallingUid;

    return ResultadoEnvioAmizade(
      friendshipId: friendshipId,
      status: FriendshipStatus.pending,
      autoAccepted: false,
    );
  }

  @override
  Future<ResultadoAceiteAmizade> aceitarSolicitacaoAmizade(String identificador) async {
    if (simularErroConexao) {
      throw const FriendshipException(
        FriendshipErrorCode.unavailable,
        'Serviço temporariamente indisponível. Verifique sua conexão.',
      );
    }

    final friendshipId = identificador.contains('_')
        ? identificador
        : _calcFriendshipId(_currentCallingUid, identificador);

    final statusAtual = statusAmizades[friendshipId];
    final reqAtual = requesterIds[friendshipId];

    if (statusAtual == null) {
      throw const FriendshipException(
        FriendshipErrorCode.requestNotFound,
        'Solicitação de amizade não encontrada.',
      );
    }

    if (statusAtual == 'ACCEPTED' || statusAtual == 'REJECTED') {
      throw const FriendshipException(
        FriendshipErrorCode.alreadyResolved,
        'Esta solicitação de amizade já foi resolvida.',
      );
    }

    if (reqAtual == _currentCallingUid) {
      throw const FriendshipException(
        FriendshipErrorCode.notTheRecipient,
        'Apenas o destinatário pode aceitar a solicitação.',
      );
    }

    // Aceite válido
    statusAmizades[friendshipId] = 'ACCEPTED';
    final parts = friendshipId.split('_');

    return ResultadoAceiteAmizade(
      friendshipId: friendshipId,
      status: FriendshipStatus.accepted,
      userAId: parts[0],
      userBId: parts[1],
    );
  }

  @override
  Future<ResultadoRecusaAmizade> recusarSolicitacaoAmizade(String identificador) async {
    if (simularErroConexao) {
      throw const FriendshipException(
        FriendshipErrorCode.unavailable,
        'Serviço temporariamente indisponível. Verifique sua conexão.',
      );
    }

    final friendshipId = identificador.contains('_')
        ? identificador
        : _calcFriendshipId(_currentCallingUid, identificador);

    final statusAtual = statusAmizades[friendshipId];
    final reqAtual = requesterIds[friendshipId];

    if (statusAtual == null) {
      throw const FriendshipException(
        FriendshipErrorCode.requestNotFound,
        'Solicitação de amizade não encontrada.',
      );
    }

    if (statusAtual == 'ACCEPTED' || statusAtual == 'REJECTED') {
      throw const FriendshipException(
        FriendshipErrorCode.alreadyResolved,
        'Esta solicitação de amizade já foi resolvida.',
      );
    }

    if (reqAtual == _currentCallingUid) {
      throw const FriendshipException(
        FriendshipErrorCode.notTheRecipient,
        'Apenas o destinatário pode recusar a solicitação.',
      );
    }

    // Recusa válida
    statusAmizades[friendshipId] = 'REJECTED';
    final parts = friendshipId.split('_');

    return ResultadoRecusaAmizade(
      friendshipId: friendshipId,
      status: FriendshipStatus.rejected,
      userAId: parts[0],
      userBId: parts[1],
    );
  }

  final List<SolicitacaoAmizade> solicitacoesFake = [];
  final List<UsuarioPublico> amigosFake = [];

  @override
  Future<PaginaSolicitacoesAmizade> listarSolicitacoesPendentes({
    Map<String, dynamic>? cursor,
  }) async {
    if (simularErroConexao) {
      throw const FriendshipException(
        FriendshipErrorCode.unavailable,
        'Serviço temporariamente indisponível. Verifique sua conexão.',
      );
    }
    return PaginaSolicitacoesAmizade(requests: List.from(solicitacoesFake));
  }

  @override
  Future<List<UsuarioPublico>> listarAmigosAceitos() async {
    if (simularErroConexao) {
      throw const FriendshipException(
        FriendshipErrorCode.unavailable,
        'Serviço temporariamente indisponível. Verifique sua conexão.',
      );
    }
    return List.from(amigosFake);
  }

  String _currentCallingUid = '';
  void setCaller(String uid) {
    _currentCallingUid = uid;
  }
}

void main() {
  group('FriendshipService & Validações de Regra de Negócio (RF-005, RN-FRD-001)', () {
    const meuUid = 'uid-usuario-logado';
    const outroUid = 'uid-outro-usuario';

    late FakeAuthService authService;
    late _FakeFriendshipRepository repository;
    late FriendshipService service;

    setUp(() {
      authService = FakeAuthService(usuarioInicial: FakeUser(meuUid));
      repository = _FakeFriendshipRepository();
      repository.setCaller(meuUid);
      service = FriendshipService(
        authService: authService,
        repository: repository,
      );
    });

    test('remove pelo ID ordenado mesmo quando os UIDs contêm underscores', () async {
      await service.removerAmizade('a_uid_com_underscore');
      expect(repository.amizadeRemovida, 'a_uid_com_underscore_$meuUid');
    });

    test('remoção exige autenticação e não chama o repositório', () async {
      final service = FriendshipService(
        authService: FakeAuthService(usuarioInicial: null),
        repository: repository,
      );
      await expectLater(
        service.removerAmizade(outroUid),
        throwsA(isA<FriendshipException>().having(
          (e) => e.code, 'code', FriendshipErrorCode.unauthenticated,
        )),
      );
      expect(repository.amizadeRemovida, isNull);
    });

    test('remoção offline não altera relação nem reenvia', () async {
      repository.simularErroConexao = true;
      await expectLater(
        service.removerAmizade(outroUid),
        throwsA(isA<FriendshipException>()),
      );
      repository.simularErroConexao = false;
      await Future<void>.delayed(Duration.zero);
      expect(repository.amizadeRemovida, isNull);
    });

    test('exige usuário autenticado para envio', () async {
      final unauthedAuth = FakeAuthService(usuarioInicial: null);
      final unauthedService = FriendshipService(
        authService: unauthedAuth,
        repository: repository,
      );

      expect(
        () => unauthedService.enviarSolicitacaoAmizade(outroUid),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.unauthenticated,
          ),
        ),
      );
    });

    test('auto-solicitação: usuário não pode enviar solicitação para si mesmo (RN-FRD-002)', () async {
      expect(
        () => service.enviarSolicitacaoAmizade(meuUid),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.selfRequest,
          ),
        ),
      );
    });

    test('identificação da relação utiliza userId (RN-AUTH-006)', () async {
      // Rejeita identificador vazio
      expect(
        () => service.enviarSolicitacaoAmizade('   '),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.invalidData,
          ),
        ),
      );
    });

    test('envio válido: persiste como pendente', () async {
      final resultado = await service.enviarSolicitacaoAmizade(outroUid);

      expect(resultado.status, FriendshipStatus.pending);
      expect(resultado.autoAccepted, false);
      expect(resultado.friendshipId, isNotEmpty);
    });

    test('solicitação duplicada: segunda solicitação ativa equivalente não é criada (RN-FRD-004)', () async {
      // Primeiro envio com sucesso
      await service.enviarSolicitacaoAmizade(outroUid);

      // Segundo envio equivalente deve falhar
      expect(
        () => service.enviarSolicitacaoAmizade(outroUid),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.alreadyRequested,
          ),
        ),
      );
    });

    test('usuários já amigos: usuário já amigo não pode criar nova solicitação (RN-FRD-003)', () async {
      // Simula amizade já aceita previamente
      final friendshipId = repository._calcFriendshipId(meuUid, outroUid);
      repository.statusAmizades[friendshipId] = 'ACCEPTED';

      expect(
        () => service.enviarSolicitacaoAmizade(outroUid),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.alreadyFriends,
          ),
        ),
      );
    });

    test('solicitação cruzada: aceitação automática se destino já solicitou (RN-FRD-005)', () async {
      // Simula que outroUid já solicitou amizade para meuUid
      final friendshipId = repository._calcFriendshipId(meuUid, outroUid);
      repository.statusAmizades[friendshipId] = 'PENDING';
      repository.requesterIds[friendshipId] = outroUid;

      // Agora meuUid envia solicitação para outroUid
      final resultado = await service.enviarSolicitacaoAmizade(outroUid);

      expect(resultado.status, FriendshipStatus.accepted);
      expect(resultado.autoAccepted, true);
    });

    test('aceite válido: destinatário aceita solicitação pendente', () async {
      // Outro usuário solicitou amizade para meuUid
      final friendshipId = repository._calcFriendshipId(meuUid, outroUid);
      repository.statusAmizades[friendshipId] = 'PENDING';
      repository.requesterIds[friendshipId] = outroUid;

      // meuUid (destinatário) aceita
      final resultado = await service.aceitarSolicitacaoAmizade(friendshipId);

      expect(resultado.status, FriendshipStatus.accepted);
      expect(resultado.friendshipId, friendshipId);
      // Solicitação deixa de permanecer pendente
      expect(repository.statusAmizades[friendshipId], 'ACCEPTED');
    });

    test('tentativa de aceitar solicitação já resolvida (ACCEPTED)', () async {
      final friendshipId = repository._calcFriendshipId(meuUid, outroUid);
      repository.statusAmizades[friendshipId] = 'ACCEPTED';
      repository.requesterIds[friendshipId] = outroUid;

      expect(
        () => service.aceitarSolicitacaoAmizade(friendshipId),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.alreadyResolved,
          ),
        ),
      );
    });

    test('tentativa de aceitar solicitação já resolvida (REJECTED)', () async {
      final friendshipId = repository._calcFriendshipId(meuUid, outroUid);
      repository.statusAmizades[friendshipId] = 'REJECTED';
      repository.requesterIds[friendshipId] = outroUid;

      expect(
        () => service.aceitarSolicitacaoAmizade(friendshipId),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.alreadyResolved,
          ),
        ),
      );
    });

    test('autor da solicitação não pode aceitá-la', () async {
      final friendshipId = repository._calcFriendshipId(meuUid, outroUid);
      repository.statusAmizades[friendshipId] = 'PENDING';
      repository.requesterIds[friendshipId] = meuUid; // meuUid é o autor

      expect(
        () => service.aceitarSolicitacaoAmizade(friendshipId),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.notTheRecipient,
          ),
        ),
      );
    });

    test('tentativa de aceitar solicitação inexistente', () async {
      expect(
        () => service.aceitarSolicitacaoAmizade('id_inexistente_123'),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.requestNotFound,
          ),
        ),
      );
    });

    test('validar amizade dos dois lados (ambos constam como amigos - RN-FRD-001)', () async {
      // Configura solicitação de outroUid para meuUid
      final friendshipId = repository._calcFriendshipId(meuUid, outroUid);
      repository.statusAmizades[friendshipId] = 'PENDING';
      repository.requesterIds[friendshipId] = outroUid;

      // Aceita
      await service.aceitarSolicitacaoAmizade(friendshipId);

      // Verificação pelo lado de meuUid
      repository.setCaller(meuUid);
      expect(repository.statusAmizades[friendshipId], 'ACCEPTED');

      // Verificação pelo lado de outroUid
      repository.setCaller(outroUid);
      expect(repository.statusAmizades[friendshipId], 'ACCEPTED');
    });

    test('recusa válida: destinatário recusa solicitação pendente', () async {
      final friendshipId = repository._calcFriendshipId(meuUid, outroUid);
      repository.statusAmizades[friendshipId] = 'PENDING';
      repository.requesterIds[friendshipId] = outroUid;

      final resultado = await service.recusarSolicitacaoAmizade(friendshipId);

      expect(resultado.status, FriendshipStatus.rejected);
      expect(resultado.friendshipId, friendshipId);
      expect(repository.statusAmizades[friendshipId], 'REJECTED');
    });

    test('recusa: autor da solicitação não pode recusá-la', () async {
      final friendshipId = repository._calcFriendshipId(meuUid, outroUid);
      repository.statusAmizades[friendshipId] = 'PENDING';
      repository.requesterIds[friendshipId] = meuUid;

      expect(
        () => service.recusarSolicitacaoAmizade(friendshipId),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.notTheRecipient,
          ),
        ),
      );
    });

    test('recusa: tentativa de recusar solicitação já resolvida', () async {
      final friendshipId = repository._calcFriendshipId(meuUid, outroUid);
      repository.statusAmizades[friendshipId] = 'ACCEPTED';
      repository.requesterIds[friendshipId] = outroUid;

      expect(
        () => service.recusarSolicitacaoAmizade(friendshipId),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.alreadyResolved,
          ),
        ),
      );
    });

    test('listar solicitações pendentes: retorna lista de pendências recebidas', () async {
      repository.solicitacoesFake.addAll([
        const SolicitacaoAmizade(
          friendshipId: 'amizade_1',
          remetente: UsuarioPublico(userId: 'u1', displayName: 'Lucas', username: 'lucas'),
        ),
        const SolicitacaoAmizade(
          friendshipId: 'amizade_2',
          remetente: UsuarioPublico(userId: 'u2', displayName: 'Juliana', username: 'jupaes'),
        ),
      ]);

      final pendencias = await service.listarSolicitacoesPendentes();
      expect(pendencias.requests.length, 2);
      expect(pendencias.requests[0].remetente.displayName, 'Lucas');
      expect(pendencias.requests[1].remetente.displayName, 'Juliana');
    });

    test('listar solicitações pendentes: exige usuário autenticado', () async {
      final authDeslogado = FakeAuthService(usuarioInicial: null);
      final servicoSemAuth = FriendshipService(authService: authDeslogado, repository: repository);

      expect(
        () => servicoSemAuth.listarSolicitacoesPendentes(),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.unauthenticated,
          ),
        ),
      );
    });

    test('tradução de erro de conexão/indisponibilidade', () async {
      repository.simularErroConexao = true;

      expect(
        () => service.enviarSolicitacaoAmizade(outroUid),
        throwsA(
          isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            FriendshipErrorCode.unavailable,
          ),
        ),
      );
    });
  });

  group('FriendshipException.fromFunctionsException', () {
    test('traduz desafio ativo com mensagem exata', () {
      final ex = FriendshipException.fromFunctionsException(
        FunctionsException(
          code: 'failed-precondition',
          message: 'Backend',
          motivo: 'desafio-ativo',
        ),
      );
      expect(ex.code, FriendshipErrorCode.activeChallenge);
      expect(ex.message,
          'Você tem um desafio em andamento com este amigo. Conclua ou cancele o desafio antes de remover a amizade.');
    });
    test('mapeia motivo auto-solicitacao para selfRequest', () {
      final fe = FunctionsException(
        code: 'invalid-argument',
        message: 'Auto solicitação',
        motivo: 'auto-solicitacao',
      );
      final ex = FriendshipException.fromFunctionsException(fe);
      expect(ex.code, FriendshipErrorCode.selfRequest);
      expect(ex.message, contains('si mesmo'));
    });

    test('mapeia motivo ja-amigos para alreadyFriends', () {
      final fe = FunctionsException(
        code: 'already-exists',
        message: 'Já amigos',
        motivo: 'ja-amigos',
      );
      final ex = FriendshipException.fromFunctionsException(fe);
      expect(ex.code, FriendshipErrorCode.alreadyFriends);
      expect(ex.message, contains('já são amigos'));
    });

    test('mapeia motivo solicitacao-duplicada para alreadyRequested', () {
      final fe = FunctionsException(
        code: 'already-exists',
        message: 'Duplicada',
        motivo: 'solicitacao-duplicada',
      );
      final ex = FriendshipException.fromFunctionsException(fe);
      expect(ex.code, FriendshipErrorCode.alreadyRequested);
      expect(ex.message, contains('solicitação de amizade pendente'));
    });

    test('mapeia motivo destinatario-inexistente para userNotFound', () {
      final fe = FunctionsException(
        code: 'not-found',
        message: 'Destinatário não encontrado',
        motivo: 'destinatario-inexistente',
      );
      final ex = FriendshipException.fromFunctionsException(fe);
      expect(ex.code, FriendshipErrorCode.userNotFound);
    });

    test('mapeia motivo solicitacao-ja-resolvida para alreadyResolved', () {
      final fe = FunctionsException(
        code: 'failed-precondition',
        message: 'Já resolvida',
        motivo: 'solicitacao-ja-resolvida',
      );
      final ex = FriendshipException.fromFunctionsException(fe);
      expect(ex.code, FriendshipErrorCode.alreadyResolved);
      expect(ex.message, contains('já foi resolvida'));
    });

    test('mapeia motivo nao-destinatario para notTheRecipient', () {
      final fe = FunctionsException(
        code: 'failed-precondition',
        message: 'Não destinatário',
        motivo: 'nao-destinatario',
      );
      final ex = FriendshipException.fromFunctionsException(fe);
      expect(ex.code, FriendshipErrorCode.notTheRecipient);
      expect(ex.message, contains('Apenas o destinatário'));
    });

    test('mapeia motivo solicitacao-inexistente para requestNotFound', () {
      final fe = FunctionsException(
        code: 'not-found',
        message: 'Inexistente',
        motivo: 'solicitacao-inexistente',
      );
      final ex = FriendshipException.fromFunctionsException(fe);
      expect(ex.code, FriendshipErrorCode.requestNotFound);
    });

    test('mapeia motivo nao-participante para permissionDenied', () {
      final fe = FunctionsException(
        code: 'permission-denied',
        message: 'Não participante',
        motivo: 'nao-participante',
      );
      final ex = FriendshipException.fromFunctionsException(fe);
      expect(ex.code, FriendshipErrorCode.permissionDenied);
    });
  });

  group('FriendshipService - Visualizar lista de amigos (RF-006, RN-FRD-001, RN-PROF-002)', () {
    test('exige usuário autenticado', () async {
      final auth = FakeAuthService(usuarioInicial: null);
      final repo = _FakeFriendshipRepository();
      final service = FriendshipService(authService: auth, repository: repo);

      expect(
        () => service.listarAmigosAceitos(),
        throwsA(isA<FriendshipException>().having(
          (e) => e.code,
          'code',
          FriendshipErrorCode.unauthenticated,
        )),
      );
    });

    test('retorna exclusivamente amigos com relação aceita e dados públicos permitidos', () async {
      const currentUid = 'uid-usuario-logado';
      final auth = FakeAuthService(usuarioInicial: FakeUser(currentUid));
      final repo = _FakeFriendshipRepository();
      final service = FriendshipService(authService: auth, repository: repo);

      repo.amigosFake.addAll([
        const UsuarioPublico(userId: 'uid_bob', displayName: 'Bob Silva', username: 'bobsilva'),
        const UsuarioPublico(userId: 'uid_carlos', displayName: 'Carlos Souza', username: 'carloss'),
      ]);

      final resultado = await service.listarAmigosAceitos();
      expect(resultado.length, 2);
      expect(resultado[0].userId, 'uid_bob');
      expect(resultado[0].displayName, 'Bob Silva');
      expect(resultado[0].username, 'bobsilva');
      expect(resultado[0].usernameComArroba, '@bobsilva');
      expect(resultado[1].displayName, 'Carlos Souza');
    });

    test('repassa erro de conexão ou indisponibilidade', () async {
      const currentUid = 'uid-usuario-logado';
      final auth = FakeAuthService(usuarioInicial: FakeUser(currentUid));
      final repo = _FakeFriendshipRepository()..simularErroConexao = true;
      final service = FriendshipService(authService: auth, repository: repo);

      expect(
        () => service.listarAmigosAceitos(),
        throwsA(isA<FriendshipException>().having(
          (e) => e.code,
          'code',
          FriendshipErrorCode.unavailable,
        )),
      );
    });
  });
}
