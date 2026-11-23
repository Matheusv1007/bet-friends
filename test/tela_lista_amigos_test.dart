// Visualizar lista de amigos (RF-006, RN-PROF-002, RN-FRD-001)
//
// Critérios de Aceitação:
// - Somente relações aceitas aparecem (RN-FRD-001);
// - Nome e nome de usuário do amigo são exibidos (RN-PROF-002);
// - E-mail não é exibido (RN-PROF-002);
// - Saldo detalhado não é descrito (RN-PROF-002);
// - Transações não são exibidas (RN-PROF-002);
// - Dados internos do usuário não são expostos (RN-PROF-002).
//
// Testes / Validação:
// - Listar amigos aceitos;
// - Confirmar ausência de relações pendentes;
// - Validar a privacidade dos dados exibidos.

import 'dart:async';

import 'package:betfriends/data/firestore/friendship_repository.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/carteira.dart';
import 'package:betfriends/models/friendship_model.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/models/usuario_publico.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/friendship_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tela_amigos/tela_buscar_usuarios.dart';
import 'package:betfriends/tela_amigos/tela_lista_amigos.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

class _FakeFriendshipRepository implements FriendshipRepository {
  List<UsuarioPublico> amigosAceitos = [];
  List<SolicitacaoAmizade> pendentes = [];
  bool simularErro = false;
  String mensagemErro = 'Erro de conexão simulado';
  int remocoes = 0;
  String? ultimoFriendshipId;
  FriendshipException? erroRemocao;
  Completer<void>? conclusaoRemocao;

  @override
  Future<void> removerAmizade(String friendshipId) async {
    remocoes++;
    ultimoFriendshipId = friendshipId;
    if (conclusaoRemocao != null) await conclusaoRemocao!.future;
    if (erroRemocao != null) throw erroRemocao!;
  }


  @override
  Future<List<UsuarioPublico>> listarAmigosAceitos() async {
    if (simularErro) {
      throw FriendshipException(FriendshipErrorCode.unavailable, mensagemErro);
    }
    return List.from(amigosAceitos);
  }

  @override
  Future<List<SolicitacaoAmizade>> listarSolicitacoesPendentes() async {
    if (simularErro) {
      throw FriendshipException(FriendshipErrorCode.unavailable, mensagemErro);
    }
    return List.from(pendentes);
  }

  @override
  Future<ResultadoAceiteAmizade> aceitarSolicitacaoAmizade(String identificador) async =>
      throw UnimplementedError();

  @override
  Future<ResultadoEnvioAmizade> enviarSolicitacaoAmizade(String toUserId) async =>
      throw UnimplementedError();

  @override
  Future<ResultadoRecusaAmizade> recusarSolicitacaoAmizade(String identificador) async =>
      throw UnimplementedError();
}

class _FakeUserProfileRepository implements UserProfileRepository {
  final _controller = StreamController<PerfilObservado>.broadcast();

  void emitir(UserProfile? perfil, {Carteira? carteira}) =>
      _controller.add(PerfilObservado(perfil, carteira: carteira));

  @override
  Stream<PerfilObservado> observarPorUid(String uid) => _controller.stream;

  @override
  Future<UserProfile?> buscarPorUid(String uid) async => null;

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {}
}

void main() {
  const currentUid = 'uid-usuario-logado';
  late FakeAuthService authService;
  late _FakeFriendshipRepository repo;
  late FriendshipService friendshipService;

  setUp(() {
    authService = FakeAuthService(usuarioInicial: FakeUser(currentUid));
    repo = _FakeFriendshipRepository();
    friendshipService = FriendshipService(authService: authService, repository: repo);
  });

  Widget criarApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PartidasProvider(partidasService: CountingPartidasService()),
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  final amigosExemplo = [
    const UsuarioPublico(
      userId: 'uid_amigo_1',
      displayName: 'Carlos Silva',
      username: 'carlossilva',
    ),
    const UsuarioPublico(
      userId: 'uid_amigo_2',
      displayName: 'Beatriz Costa',
      username: 'biacosta',
    ),
  ];

  group('TelaListaAmigos - Visualizar lista de amigos (RF-006, RN-FRD-001, RN-PROF-002)', () {
    testWidgets('cancelar preserva amizade e não chama serviço', (tester) async {
      repo.amigosAceitos = List.from(amigosExemplo);
      await tester.pumpWidget(criarApp(
        TelaListaAmigos(friendshipService: friendshipService),
      ));
      await tester.pumpAndSettle();
      final remover = find.byKey(const Key('btn_remover_amigo_uid_amigo_1'));
      expect(tester.getSize(remover).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(remover).height, greaterThanOrEqualTo(48));
      await tester.tap(remover);
      await tester.pumpAndSettle();
      expect(find.textContaining('não poderão se desafiar'), findsOneWidget);
      expect(find.textContaining('histórico de desafios será mantido'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancelar_remocao_amizade')));
      await tester.pumpAndSettle();
      expect(repo.remocoes, 0);
      expect(find.byKey(const Key('card_amigo_uid_amigo_1')), findsOneWidget);
    });

    testWidgets('confirma uma vez e atualiza lista somente após sucesso', (tester) async {
      repo.amigosAceitos = List.from(amigosExemplo);
      repo.conclusaoRemocao = Completer<void>();
      await tester.pumpWidget(criarApp(
        TelaListaAmigos(friendshipService: friendshipService),
      ));
      await tester.pumpAndSettle();
      final remover = find.byKey(const Key('btn_remover_amigo_uid_amigo_1'));
      await tester.tap(remover);
      await tester.tap(remover);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmar_remocao_amizade')));
      await tester.pumpAndSettle();
      expect(repo.remocoes, 1);
      expect(repo.ultimoFriendshipId, 'uid-usuario-logado_uid_amigo_1');
      expect(find.byKey(const Key('card_amigo_uid_amigo_1')), findsOneWidget);
      final botao = tester.widget<IconButton>(remover);
      expect(botao.onPressed, isNull);
      repo.conclusaoRemocao!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card_amigo_uid_amigo_1')), findsNothing);
      expect(find.byKey(const Key('card_amigo_uid_amigo_2')), findsOneWidget);
      expect(find.text('1 amigo(s)'), findsOneWidget);
      expect(find.text('Amizade removida com sucesso.'), findsOneWidget);
    });

    for (final erro in [
      const FriendshipException(
        FriendshipErrorCode.activeChallenge,
        'Você tem um desafio em andamento com este amigo. Conclua ou cancele o desafio antes de remover a amizade.',
      ),
      const FriendshipException(
        FriendshipErrorCode.unavailable,
        'Serviço temporariamente indisponível. Verifique sua conexão.',
      ),
      const FriendshipException(
        FriendshipErrorCode.requestNotFound,
        'Solicitação de amizade não encontrada.',
      ),
    ]) {
      testWidgets('erro ${erro.code.name} preserva lista e não reenvia', (tester) async {
        repo.amigosAceitos = List.from(amigosExemplo);
        repo.erroRemocao = erro;
        await tester.pumpWidget(criarApp(
          TelaListaAmigos(friendshipService: friendshipService),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_remover_amigo_uid_amigo_1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmar_remocao_amizade')));
        await tester.pumpAndSettle();
        expect(find.text(erro.message), findsOneWidget);
        expect(find.byKey(const Key('card_amigo_uid_amigo_1')), findsOneWidget);
        expect(find.text('Amizade removida com sucesso.'), findsNothing);
        repo.erroRemocao = null;
        await tester.pump(const Duration(seconds: 5));
        expect(repo.remocoes, 1);
      });
    }

    testWidgets('listar amigos aceitos com exibição de nome e username e botão desafiar', (tester) async {
      repo.amigosAceitos = List.from(amigosExemplo);

      await tester.pumpWidget(criarApp(
        TelaListaAmigos(friendshipService: friendshipService),
      ));

      // Estado inicial com loading
      expect(find.byKey(const Key('loading_lista_amigos')), findsOneWidget);

      await tester.pumpAndSettle();

      // Lista carregada com sucesso
      expect(find.byKey(const Key('lista_amigos_conteudo')), findsOneWidget);
      expect(find.byKey(const Key('badge_total_amigos')), findsOneWidget);
      expect(find.text('2 amigo(s)'), findsOneWidget);

      // Card do Amigo 1
      expect(find.byKey(const Key('card_amigo_uid_amigo_1')), findsOneWidget);
      expect(find.text('Carlos Silva'), findsOneWidget);
      expect(find.text('@carlossilva'), findsOneWidget);
      expect(find.byKey(const Key('btn_desafiar_amigo_uid_amigo_1')), findsOneWidget);

      // Card do Amigo 2
      expect(find.byKey(const Key('card_amigo_uid_amigo_2')), findsOneWidget);
      expect(find.text('Beatriz Costa'), findsOneWidget);
      expect(find.text('@biacosta'), findsOneWidget);

      // Clicar em Desafiar abre a tela de criar desafio
      await tester.tap(find.byKey(const Key('btn_desafiar_amigo_uid_amigo_1')));
      await tester.pumpAndSettle();
      expect(find.byType(CriarDesafioScreen), findsOneWidget);
    });

    testWidgets('filtro local por nome ou @username filtra a lista em tempo real', (tester) async {
      repo.amigosAceitos = List.from(amigosExemplo);

      await tester.pumpWidget(criarApp(
        TelaListaAmigos(friendshipService: friendshipService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Carlos Silva'), findsOneWidget);
      expect(find.text('Beatriz Costa'), findsOneWidget);

      // Digita no campo de filtro
      await tester.enterText(find.byKey(const Key('campo_busca_amigos')), 'bia');
      await tester.pumpAndSettle();

      // Apenas Beatriz deve aparecer
      expect(find.text('Beatriz Costa'), findsOneWidget);
      expect(find.text('Carlos Silva'), findsNothing);

      // Limpa filtro
      await tester.enterText(find.byKey(const Key('campo_busca_amigos')), '');
      await tester.pumpAndSettle();

      expect(find.text('Carlos Silva'), findsOneWidget);
      expect(find.text('Beatriz Costa'), findsOneWidget);
    });

    testWidgets('confirmar ausência de relações pendentes na lista de amigos (RN-FRD-001)', (tester) async {
      // Configura amigos aceitos e solicitações pendentes no repositório
      repo.amigosAceitos = [
        const UsuarioPublico(
          userId: 'uid_amigo_aceito',
          displayName: 'Amigo Confirmado',
          username: 'confirmado',
        ),
      ];
      repo.pendentes = [
        const SolicitacaoAmizade(
          friendshipId: 'uid-usuario-logado_uid_pendente',
          remetente: UsuarioPublico(
            userId: 'uid_pendente',
            displayName: 'Pessoa Pendente',
            username: 'pendente',
          ),
          status: FriendshipStatus.pending,
        ),
      ];

      await tester.pumpWidget(criarApp(
        TelaListaAmigos(friendshipService: friendshipService),
      ));
      await tester.pumpAndSettle();

      // Somente o amigo aceito aparece
      expect(find.text('Amigo Confirmado'), findsOneWidget);
      expect(find.text('@confirmado'), findsOneWidget);

      // A relação pendente NÃO deve constar na lista de amigos aceitos
      expect(find.text('Pessoa Pendente'), findsNothing);
      expect(find.text('@pendente'), findsNothing);
      expect(find.text('PENDENTE'), findsNothing);
      expect(find.byKey(const Key('card_amigo_uid_pendente')), findsNothing);
    });

    testWidgets('validar a privacidade dos dados exibidos (RN-PROF-002)', (tester) async {
      repo.amigosAceitos = [
        const UsuarioPublico(
          userId: 'uid_joao_123',
          displayName: 'João da Silva',
          username: 'joaosilva',
        ),
      ];

      await tester.pumpWidget(criarApp(
        TelaListaAmigos(friendshipService: friendshipService),
      ));
      await tester.pumpAndSettle();

      // Dados públicos permitidos são exibidos
      expect(find.text('João da Silva'), findsOneWidget);
      expect(find.text('@joaosilva'), findsOneWidget);

      // Validação estrita de ausência de dados privados (RN-PROF-002)
      // 1. E-mail não é exibido
      expect(find.textContaining('@example.com'), findsNothing);
      expect(find.textContaining('@gmail.com'), findsNothing);
      expect(find.textContaining('email'), findsNothing);
      expect(find.textContaining('E-mail'), findsNothing);

      // 2. Saldo detalhado não é exibido
      expect(find.textContaining('saldoTotal'), findsNothing);
      expect(find.textContaining('saldoReservado'), findsNothing);
      expect(find.textContaining('saldoDisponivel'), findsNothing);
      expect(find.textContaining('BetCoins'), findsNothing);
      expect(find.textContaining('Saldo'), findsNothing);

      // 3. Transações não são exibidas
      expect(find.textContaining('transações'), findsNothing);
      expect(find.textContaining('extrato'), findsNothing);
      expect(find.textContaining('histórico'), findsNothing);

      // 4. Dados internos não são expostos
      expect(find.textContaining('token'), findsNothing);
      expect(find.textContaining('rawToken'), findsNothing);
      expect(find.textContaining('internal'), findsNothing);
    });

    testWidgets('exibe estado amigável quando lista de amigos está vazia com botão buscar amigos', (tester) async {
      repo.amigosAceitos = [];

      await tester.pumpWidget(criarApp(
        TelaListaAmigos(friendshipService: friendshipService),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lista_amigos_vazia')), findsOneWidget);
      expect(find.text('Nenhum amigo adicionado'), findsOneWidget);
      expect(find.byKey(const Key('btn_buscar_amigos_vazio')), findsOneWidget);

      // Clicar no botão navega para TelaBuscarUsuarios
      await tester.tap(find.byKey(const Key('btn_buscar_amigos_vazio')));
      await tester.pumpAndSettle();
      expect(find.byType(TelaBuscarUsuarios), findsOneWidget);
    });

    testWidgets('exibe mensagem de erro e botão tentar novamente quando ocorre falha', (tester) async {
      repo.simularErro = true;
      repo.mensagemErro = 'Serviço temporariamente indisponível.';

      await tester.pumpWidget(criarApp(
        TelaListaAmigos(friendshipService: friendshipService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Falha ao carregar amigos'), findsOneWidget);
      expect(find.text('Serviço temporariamente indisponível.'), findsOneWidget);
      expect(find.byKey(const Key('btn_tentar_novamente_amigos')), findsOneWidget);

      // Corrige erro e clica em Tentar Novamente
      repo.simularErro = false;
      repo.amigosAceitos = List.from(amigosExemplo);

      await tester.tap(find.byKey(const Key('btn_tentar_novamente_amigos')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Falha ao carregar amigos'), findsNothing);
      expect(find.text('Carlos Silva'), findsOneWidget);
      expect(find.text('Beatriz Costa'), findsOneWidget);
    });

    testWidgets('botão MEUS AMIGOS na tela de Perfil abre TelaListaAmigos', (tester) async {
      final perfilRepo = _FakeUserProfileRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserProfileService>(
              create: (_) => UserProfileService(authService: authService, repository: perfilRepo),
            ),
          ],
          child: const MaterialApp(
            home: PerfilScreen(),
          ),
        ),
      );

      perfilRepo.emitir(const UserProfile(
        uid: currentUid,
        displayName: 'Ana Lima',
        username: 'analima',
        usernameNormalized: 'analima',
        email: 'ana@example.com',
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('perfil_meus_amigos')), findsOneWidget);
      expect(find.text('MEUS AMIGOS'), findsOneWidget);

      await tester.tap(find.byKey(const Key('perfil_meus_amigos')));
      await tester.pumpAndSettle();

      expect(find.byType(TelaListaAmigos), findsOneWidget);
      expect(find.text('Meus Amigos'), findsOneWidget);
    });
  });
}
