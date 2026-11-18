import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:betfriends/data/firestore/friendship_repository.dart';
import 'package:betfriends/models/friendship_model.dart';
import 'package:betfriends/models/usuario_publico.dart';
import 'package:betfriends/services/friendship_service.dart';
import 'package:betfriends/tela_amigos/tela_comunicacoes_amizade.dart';

import 'support/fake_auth.dart';

class _FakeFriendshipRepoForComunicacoes implements FriendshipRepository {
  List<SolicitacaoAmizade> solicitacoes = [];
  bool throwError = false;
  String? errorMessage;

  final List<String> aceitas = [];
  final List<String> recusadas = [];

  @override
  Future<List<SolicitacaoAmizade>> listarSolicitacoesPendentes() async {
    if (throwError) {
      throw FriendshipException(
        FriendshipErrorCode.unavailable,
        errorMessage ?? 'Serviço temporariamente indisponível. Verifique sua conexão.',
      );
    }
    return List.from(solicitacoes);
  }

  @override
  Future<ResultadoAceiteAmizade> aceitarSolicitacaoAmizade(String identificador) async {
    if (throwError) {
      throw FriendshipException(
        FriendshipErrorCode.alreadyResolved,
        errorMessage ?? 'Esta solicitação de amizade já foi resolvida.',
      );
    }
    aceitas.add(identificador);
    return ResultadoAceiteAmizade(
      friendshipId: identificador,
      status: FriendshipStatus.accepted,
      userAId: 'user_remetente',
      userBId: 'user_destinatario',
    );
  }

  @override
  Future<ResultadoRecusaAmizade> recusarSolicitacaoAmizade(String identificador) async {
    if (throwError) {
      throw FriendshipException(
        FriendshipErrorCode.alreadyResolved,
        errorMessage ?? 'Esta solicitação de amizade já foi resolvida.',
      );
    }
    recusadas.add(identificador);
    return ResultadoRecusaAmizade(
      friendshipId: identificador,
      status: FriendshipStatus.rejected,
      userAId: 'user_remetente',
      userBId: 'user_destinatario',
    );
  }

  @override
  Future<ResultadoEnvioAmizade> enviarSolicitacaoAmizade(String toUserId) {
    throw UnimplementedError();
  }

  @override
  Future<List<UsuarioPublico>> listarAmigosAceitos() async => [];
}

void main() {
  group('TelaComunicacoesAmizade - Widget Tests (RF-005, RN-PROF-002)', () {
    const meuUid = 'uid-meu-usuario';
    late FakeAuthService authService;
    late _FakeFriendshipRepoForComunicacoes repository;
    late FriendshipService friendshipService;

    final solicitacaoAlice = SolicitacaoAmizade(
      friendshipId: 'amizade_alice_meu',
      remetente: const UsuarioPublico(
        userId: 'uid-alice',
        displayName: 'Alice Silva',
        username: 'alicesilva',
      ),
      createdAt: DateTime(2026, 11, 15, 14, 30),
      status: FriendshipStatus.pending,
    );

    final solicitacaoBob = SolicitacaoAmizade(
      friendshipId: 'amizade_bob_meu',
      remetente: const UsuarioPublico(
        userId: 'uid-bob',
        displayName: 'Roberto Santos',
        username: 'bobsantos',
      ),
      createdAt: DateTime(2026, 11, 16, 10, 0),
      status: FriendshipStatus.pending,
    );

    setUp(() {
      authService = FakeAuthService(usuarioInicial: FakeUser(meuUid));
      repository = _FakeFriendshipRepoForComunicacoes();
      friendshipService = FriendshipService(
        authService: authService,
        repository: repository,
      );
    });

    Widget criarTela({FriendshipService? service}) {
      return MaterialApp(
        home: TelaComunicacoesAmizade(
          friendshipService: service ?? friendshipService,
        ),
      );
    }

    testWidgets('1. Listar pendências: propostas pendentes recebidas são apresentadas com dados públicos', (tester) async {
      repository.solicitacoes = [solicitacaoAlice, solicitacaoBob];

      await tester.pumpWidget(criarTela());
      await tester.pumpAndSettle();

      // Lista exibida
      expect(find.byKey(const Key('lista_comunicacoes_amizade')), findsOneWidget);

      // Identificação pública do remetente 1 (Alice)
      expect(find.byKey(const Key('card_solicitacao_amizade_alice_meu')), findsOneWidget);
      expect(find.byKey(const Key('solicitacao_nome_uid-alice')), findsOneWidget);
      expect(find.text('Alice Silva'), findsOneWidget);
      expect(find.byKey(const Key('solicitacao_username_uid-alice')), findsOneWidget);
      expect(find.text('@alicesilva'), findsOneWidget);

      // Identificação pública do remetente 2 (Bob)
      expect(find.byKey(const Key('card_solicitacao_amizade_bob_meu')), findsOneWidget);
      expect(find.byKey(const Key('solicitacao_nome_uid-bob')), findsOneWidget);
      expect(find.text('Roberto Santos'), findsOneWidget);
      expect(find.byKey(const Key('solicitacao_username_uid-bob')), findsOneWidget);
      expect(find.text('@bobsantos'), findsOneWidget);

      // Ações de aceitar e recusar disponíveis
      expect(find.byKey(const Key('btn_aceitar_uid-alice')), findsOneWidget);
      expect(find.byKey(const Key('btn_recusar_uid-alice')), findsOneWidget);
      expect(find.byKey(const Key('btn_aceitar_uid-bob')), findsOneWidget);
      expect(find.byKey(const Key('btn_recusar_uid-bob')), findsOneWidget);
    });

    testWidgets('2. Privacidade: dados privados do remetente não são expostos (RN-PROF-002)', (tester) async {
      repository.solicitacoes = [solicitacaoAlice];

      await tester.pumpWidget(criarTela());
      await tester.pumpAndSettle();

      // Garante ausência total de e-mail, saldos, BetCoins ou dados confidenciais
      expect(find.textContaining('@example.com'), findsNothing);
      expect(find.textContaining('alice@'), findsNothing);
      expect(find.textContaining('saldo'), findsNothing);
      expect(find.textContaining('Saldo'), findsNothing);
      expect(find.textContaining('BetCoins'), findsNothing);
      expect(find.textContaining('fichas'), findsNothing);
      expect(find.textContaining('transações'), findsNothing);
    });

    testWidgets('3. Resolver solicitação com Aceite: remove da lista de pendentes e chama repositório', (tester) async {
      repository.solicitacoes = [solicitacaoAlice, solicitacaoBob];

      await tester.pumpWidget(criarTela());
      await tester.pumpAndSettle();

      // Clica em Aceitar Alice
      await tester.tap(find.byKey(const Key('btn_aceitar_uid-alice')));
      await tester.pumpAndSettle();

      // Valida chamada no backend/repositório
      expect(repository.aceitas, contains('amizade_alice_meu'));

      // A solicitação resolvida deixa de aparecer como pendente na lista
      expect(find.byKey(const Key('card_solicitacao_amizade_alice_meu')), findsNothing);
      expect(find.text('Alice Silva'), findsNothing);

      // A outra solicitação (Bob) continua pendente
      expect(find.byKey(const Key('card_solicitacao_amizade_bob_meu')), findsOneWidget);
      expect(find.text('Roberto Santos'), findsOneWidget);

      // SnackBar de sucesso exibido
      expect(find.byKey(const Key('snackbar_sucesso')), findsOneWidget);
      expect(find.text('Você e Alice Silva agora são amigos!'), findsOneWidget);
    });

    testWidgets('4. Resolver solicitação com Recusa: remove da lista de pendentes e chama repositório', (tester) async {
      repository.solicitacoes = [solicitacaoAlice, solicitacaoBob];

      await tester.pumpWidget(criarTela());
      await tester.pumpAndSettle();

      // Clica em Recusar Bob
      await tester.tap(find.byKey(const Key('btn_recusar_uid-bob')));
      await tester.pumpAndSettle();

      // Valida chamada no backend/repositório
      expect(repository.recusadas, contains('amizade_bob_meu'));

      // A solicitação recusada deixa de aparecer como pendente na lista
      expect(find.byKey(const Key('card_solicitacao_amizade_bob_meu')), findsNothing);
      expect(find.text('Roberto Santos'), findsNothing);

      // A solicitação da Alice continua presente
      expect(find.byKey(const Key('card_solicitacao_amizade_alice_meu')), findsOneWidget);

      // SnackBar de recusa exibido
      expect(find.byKey(const Key('snackbar_recusada')), findsOneWidget);
      expect(find.text('Solicitação de Roberto Santos recusada.'), findsOneWidget);
    });

    testWidgets('5. Estado vazio: exibe mensagem quando não há pendências recebidas', (tester) async {
      repository.solicitacoes = [];

      await tester.pumpWidget(criarTela());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('comunicacoes_vazio')), findsOneWidget);
      expect(find.text('Nenhuma pendência'), findsOneWidget);
      expect(
        find.text('Você não possui solicitações de amizade pendentes no momento.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('lista_comunicacoes_amizade')), findsNothing);
    });

    testWidgets('6. Tratamento de erro: exibe mensagem amigável e permite tentar novamente', (tester) async {
      repository.throwError = true;
      repository.errorMessage = 'Falha de conexão com o servidor.';

      await tester.pumpWidget(criarTela());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('comunicacoes_erro')), findsOneWidget);
      expect(find.text('Falha de conexão com o servidor.'), findsOneWidget);

      // Corrige o erro no mock e tenta novamente
      repository.throwError = false;
      repository.solicitacoes = [solicitacaoAlice];

      await tester.tap(find.byKey(const Key('comunicacoes_tentar_novamente')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('comunicacoes_erro')), findsNothing);
      expect(find.text('Alice Silva'), findsOneWidget);
    });

    testWidgets('7. Botão de recarregar na AppBar atualiza as pendências', (tester) async {
      repository.solicitacoes = [solicitacaoAlice];

      await tester.pumpWidget(criarTela());
      await tester.pumpAndSettle();

      expect(find.text('Alice Silva'), findsOneWidget);
      expect(find.text('Roberto Santos'), findsNothing);

      // Adiciona nova pendência e clica no botão de recarregar
      repository.solicitacoes = [solicitacaoAlice, solicitacaoBob];
      await tester.tap(find.byKey(const Key('btn_recarregar_comunicacoes')));
      await tester.pumpAndSettle();

      expect(find.text('Alice Silva'), findsOneWidget);
      expect(find.text('Roberto Santos'), findsOneWidget);
    });
  });
}
