import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:betfriends/data/firestore/friendship_repository.dart';
import 'package:betfriends/data/firestore/user_search_repository.dart';
import 'package:betfriends/models/friendship_model.dart';
import 'package:betfriends/models/usuario_publico.dart';
import 'package:betfriends/services/friendship_service.dart';
import 'package:betfriends/services/user_search_service.dart';
import 'package:betfriends/tela_amigos/tela_buscar_usuarios.dart';

import 'support/fake_auth.dart';

class _FakeSearchRepository implements UserSearchRepository {
  final List<UsuarioPublico> database;
  bool throwError = false;

  _FakeSearchRepository(this.database);

  @override
  Future<List<UsuarioPublico>> buscarUsuarios(
    String termo, {
    required String usuarioAtualUid,
    int limite = 20,
  }) async {
    if (throwError) {
      throw Exception('Falha de conexão com o servidor');
    }
    final lower = termo.toLowerCase().replaceFirst(RegExp(r'^@'), '');
    return database
        .where((u) =>
            u.displayName.toLowerCase().contains(lower) ||
            u.username.toLowerCase().contains(lower))
        .where((u) => u.userId != usuarioAtualUid)
        .toList();
  }
}

class _FakeFriendshipRepoForWidget implements FriendshipRepository {
  bool crossRequest = false;
  bool throwError = false;
  String? errorMessage;

  @override
  Future<ResultadoEnvioAmizade> enviarSolicitacaoAmizade(String toUserId) async {
    if (throwError) {
      throw FriendshipException(
        FriendshipErrorCode.alreadyFriends,
        errorMessage ?? 'Vocês já são amigos.',
      );
    }
    if (crossRequest) {
      return const ResultadoEnvioAmizade(
        friendshipId: 'amizade_cruzada',
        status: FriendshipStatus.accepted,
        autoAccepted: true,
      );
    }
    return const ResultadoEnvioAmizade(
      friendshipId: 'amizade_pendente',
      status: FriendshipStatus.pending,
      autoAccepted: false,
    );
  }

  @override
  Future<ResultadoAceiteAmizade> aceitarSolicitacaoAmizade(String identificador) async {
    if (throwError) {
      throw FriendshipException(
        FriendshipErrorCode.alreadyResolved,
        errorMessage ?? 'Esta solicitação de amizade já foi resolvida.',
      );
    }
    return const ResultadoAceiteAmizade(
      friendshipId: 'amizade_aceita',
      status: FriendshipStatus.accepted,
      userAId: 'uid-amigo-1',
      userBId: 'uid-meu-usuario',
    );
  }
}

void main() {
  group('TelaBuscarUsuarios - Widget Tests (RF-004, RF-005, RN-PROF-002, RN-FRD-002)', () {
    const meuUid = 'uid-meu-usuario';
    late FakeAuthService authService;
    late _FakeSearchRepository repository;
    late UserSearchService searchService;

    setUp(() {
      authService = FakeAuthService(usuarioInicial: FakeUser(meuUid));
      repository = _FakeSearchRepository([
        const UsuarioPublico(userId: 'uid-amigo-1', displayName: 'Juliana Paes', username: 'jupaes'),
        const UsuarioPublico(userId: 'uid-amigo-2', displayName: 'Lucas Lima', username: 'lucaslima'),
        // O próprio usuário com o mesmo nome que será pesquisado
        const UsuarioPublico(userId: meuUid, displayName: 'Lucas Meu Nome', username: 'lucas_eu'),
      ]);
      searchService = UserSearchService(authService: authService, repository: repository);
    });

    testWidgets('exibe tela inicial com campo de busca e orientações', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(searchService: searchService),
      ));

      expect(find.text('Buscar Usuários'), findsOneWidget);
      expect(find.byKey(const Key('search_users_input')), findsOneWidget);
      expect(find.text('Encontre amigos no BetFriends'), findsOneWidget);
    });

    testWidgets('busca e exibe usuário existente com nome e @username', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(searchService: searchService),
      ));

      // Digita 'Juliana'
      await tester.enterText(find.byKey(const Key('search_users_input')), 'Juliana');
      // Aguarda o debounce de 300ms
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_users_list')), findsOneWidget);
      expect(find.text('Juliana Paes'), findsOneWidget);
      expect(find.text('@jupaes'), findsOneWidget);
      expect(find.text('Convidar'), findsOneWidget);

      // Não exibe e-mail nem dados privados
      expect(find.textContaining('@example.com'), findsNothing);
      expect(find.textContaining('fichas'), findsNothing);
      expect(find.textContaining('saldo'), findsNothing);
    });

    testWidgets('exclusão do próprio usuário: pesquisar nome compartilhado não lista o usuário logado (RN-FRD-002)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(searchService: searchService),
      ));

      // 'Lucas' existe para o outro usuário e para o próprio usuário logado
      await tester.enterText(find.byKey(const Key('search_users_input')), 'Lucas');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Encontra apenas o outro usuário ('Lucas Lima')
      expect(find.text('Lucas Lima'), findsOneWidget);
      expect(find.text('@lucaslima'), findsOneWidget);

      // O próprio usuário logado ('Lucas Meu Nome') NÃO deve ser exibido
      expect(find.text('Lucas Meu Nome'), findsNothing);
      expect(find.text('@lucas_eu'), findsNothing);
    });

    testWidgets('exibe estado vazio quando busca usuário inexistente', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(searchService: searchService),
      ));

      await tester.enterText(find.byKey(const Key('search_users_input')), 'usuario_inexistente_999');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_users_empty')), findsOneWidget);
      expect(find.text('Nenhum usuário encontrado'), findsOneWidget);
    });

    testWidgets('exibe mensagem amigável e botão tentar novamente em caso de erro', (tester) async {
      repository.throwError = true;

      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(searchService: searchService),
      ));

      await tester.enterText(find.byKey(const Key('search_users_input')), 'qualquer');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_users_error')), findsOneWidget);
      expect(find.byKey(const Key('search_users_retry_button')), findsOneWidget);

      // Desliga erro e clica em tentar novamente
      repository.throwError = false;
      await tester.tap(find.byKey(const Key('search_users_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_users_error')), findsNothing);
    });

    testWidgets('envio de solicitação com sucesso exibe feedback e atualiza botão para Pendente (RF-005)', (tester) async {
      final friendRepo = _FakeFriendshipRepoForWidget();
      final friendService = FriendshipService(authService: authService, repository: friendRepo);

      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(
          searchService: searchService,
          friendshipService: friendService,
        ),
      ));

      await tester.enterText(find.byKey(const Key('search_users_input')), 'Juliana');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final convidarBtn = find.byKey(const Key('btn_convidar_uid-amigo-1'));
      expect(convidarBtn, findsOneWidget);

      await tester.tap(convidarBtn);
      await tester.pumpAndSettle();

      expect(find.text('Solicitação de amizade enviada para Juliana Paes!'), findsOneWidget);
      expect(find.byKey(const Key('btn_pendente_uid-amigo-1')), findsOneWidget);
    });

    testWidgets('solicitação cruzada: feedback de aceitação automática e estado Amigos (RN-FRD-005)', (tester) async {
      final friendRepo = _FakeFriendshipRepoForWidget()..crossRequest = true;
      final friendService = FriendshipService(authService: authService, repository: friendRepo);

      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(
          searchService: searchService,
          friendshipService: friendService,
        ),
      ));

      await tester.enterText(find.byKey(const Key('search_users_input')), 'Juliana');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final convidarBtn = find.byKey(const Key('btn_convidar_uid-amigo-1'));
      await tester.tap(convidarBtn);
      await tester.pumpAndSettle();

      expect(find.text('Amizade aceita automaticamente com Juliana Paes!'), findsOneWidget);
      expect(find.byKey(const Key('btn_amigos_uid-amigo-1')), findsOneWidget);
    });

    testWidgets('exibe botão Aceitar e confirma amizade ao aceitar solicitação recebida (RF-005, RN-FRD-001)', (tester) async {
      final friendRepo = _FakeFriendshipRepoForWidget();
      final friendService = FriendshipService(authService: authService, repository: friendRepo);

      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(
          searchService: searchService,
          friendshipService: friendService,
          solicitacoesRecebidas: const {'uid-amigo-1'},
        ),
      ));

      await tester.enterText(find.byKey(const Key('search_users_input')), 'Juliana');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Botão Aceitar deve ser exibido para o usuário que enviou a solicitação
      final aceitarBtn = find.byKey(const Key('btn_aceitar_uid-amigo-1'));
      expect(aceitarBtn, findsOneWidget);
      expect(find.text('Aceitar'), findsOneWidget);

      await tester.tap(aceitarBtn);
      await tester.pumpAndSettle();

      // Mensagem de sucesso e botão muda para Amigos
      expect(find.text('Agora você e Juliana Paes são amigos!'), findsOneWidget);
      expect(find.byKey(const Key('btn_amigos_uid-amigo-1')), findsOneWidget);
    });

    testWidgets('exibe erro no SnackBar se falhar ao enviar solicitação (RN-FRD-003)', (tester) async {
      final friendRepo = _FakeFriendshipRepoForWidget()
        ..throwError = true
        ..errorMessage = 'Vocês já são amigos.';
      final friendService = FriendshipService(authService: authService, repository: friendRepo);

      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(
          searchService: searchService,
          friendshipService: friendService,
        ),
      ));

      await tester.enterText(find.byKey(const Key('search_users_input')), 'Juliana');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final convidarBtn = find.byKey(const Key('btn_convidar_uid-amigo-1'));
      await tester.tap(convidarBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vocês já são amigos.'), findsOneWidget);
    });
  });
}
