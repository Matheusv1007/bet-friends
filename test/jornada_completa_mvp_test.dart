// Integração e validação da jornada completa do MVP no Flutter (KAN-107, Plano Mestre v3.2 §2.1)
//
// Critérios de Aceitação KAN-107:
// 1. Rotas e retorno entre telas do MVP funcionam sem crash, pilhas duplicadas ou acesso indevido após logout;
// 2. UI mostra dados do usuário correto, sem vazamento de informações de terceiros e sem saldos/amigos fictícios identificados como reais;
// 3. Ao menos um cenário ponta a ponta com duas contas e dados controlados passam, incluindo criação e evolução de um desafio; resultados/BetCoins seguem os documentos persistidos;
// 4. Estados vazios, erros e offline têm comportamento adequado e nenhuma escrita é confirmada sem resposta do servidor;
// 5. Testes/roteiro de regressão são reproduzíveis e documentados, com limitações e partes ainda aguardando outros integrantes.

import 'dart:async';

import 'package:betfriends/app.dart';
import 'package:betfriends/data/firestore/challenge_repository.dart';
import 'package:betfriends/data/firestore/friendship_repository.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/data/firestore/user_search_repository.dart';
import 'package:betfriends/models/carteira.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:betfriends/models/friendship_model.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/models/usuario_publico.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/services/friendship_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/services/user_search_service.dart';
import 'package:betfriends/tela_amigos/tela_lista_amigos.dart';
import 'package:betfriends/tela_criar_desafio/modal_aceitar_desafio.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/tela_perfil/aviso_sem_conexao.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:betfriends/tela_sobre/tela_informacoes_creditos.dart';
import 'package:betfriends/telas_autenticacao/login_page.dart';
import 'package:betfriends/telas_principais/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

// ============================================================================
// FAKES CONTROLADOS PARA A JORNADA COMPLETA
// ============================================================================

class _JornadaAuthService extends FakeAuthService {
  _JornadaAuthService({super.usuarioInicial});

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (signInError != null) throw signInError!;
    final uid = email.toLowerCase().contains('bia')
        ? 'uidBia'
        : (email.toLowerCase().contains('ana') ? 'uidAna' : 'uid-$email');
    final user = FakeUser(uid, email: email);
    resolverSessao(user);
    return _FakeUserCredential(user);
  }
}

class _FakeUserCredential extends Fake implements UserCredential {
  @override
  final User user;
  _FakeUserCredential(this.user);
}

class _ControladorDePerfis implements UserProfileRepository {
  final Map<String, StreamController<PerfilObservado>> _streams = {};
  final Map<String, UserProfile> _perfis = {};
  final Map<String, Carteira> _carteiras = {};
  bool _offline = false;

  void cadastrarUsuario({
    required String uid,
    required String displayName,
    required String username,
    required int saldoDisponivel,
    int saldoReservado = 0,
  }) {
    _perfis[uid] = UserProfile(
      uid: uid,
      displayName: displayName,
      username: username,
      usernameNormalized: username.toLowerCase(),
      email: '$username@example.com',
    );
    _carteiras[uid] = Carteira(
      saldoTotal: saldoDisponivel + saldoReservado,
      saldoReservado: saldoReservado,
    );
    _emitir(uid);
  }

  void atualizarCarteira(String uid, {required int disponivel, required int reservado}) {
    _carteiras[uid] = Carteira(
      saldoTotal: disponivel + reservado,
      saldoReservado: reservado,
    );
    _emitir(uid);
  }

  void setOffline(bool offline) {
    _offline = offline;
    for (final uid in _perfis.keys) {
      _emitir(uid);
    }
  }

  void _emitir(String uid) {
    final controller = _streams[uid];
    if (controller != null && !controller.isClosed) {
      final perfil = _perfis[uid];
      final carteira = _carteiras[uid];
      controller.add(PerfilObservado(perfil, carteira: carteira, doCache: _offline));
    }
  }

  @override
  Stream<PerfilObservado> observarPorUid(String uid) async* {
    final perfil = _perfis[uid];
    final carteira = _carteiras[uid];
    yield PerfilObservado(perfil, carteira: carteira, doCache: _offline);
    final controller = _streams.putIfAbsent(uid, () => StreamController<PerfilObservado>.broadcast());
    yield* controller.stream;
  }

  @override
  Future<UserProfile?> buscarPorUid(String uid) async => _perfis[uid];

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {
    if (_offline) {
      throw const UserProfileException(
        UserProfileErrorCode.unavailable,
        'Sem conexão para salvar novo nome.',
      );
    }
    final anterior = _perfis[uid];
    if (anterior != null) {
      _perfis[uid] = UserProfile(
        uid: uid,
        displayName: displayName,
        username: anterior.username,
        usernameNormalized: anterior.usernameNormalized,
        email: anterior.email,
      );
      _emitir(uid);
    }
  }
}

class _ControladorDeAmizades implements FriendshipRepository {
  final Map<String, List<UsuarioPublico>> _amigosPorUsuario = {};
  final Map<String, List<SolicitacaoAmizade>> _solicitacoesPorUsuario = {};
  bool simularErro = false;
  String mensagemErro = 'Erro de comunicação com o servidor de amizades.';

  void adicionarAmizadeAceita(String uidA, UsuarioPublico amigoB) {
    _amigosPorUsuario.putIfAbsent(uidA, () => []).add(amigoB);
  }

  String? _uidAtual;
  void definirUidAtual(String? uid) => _uidAtual = uid;

  @override
  Future<List<UsuarioPublico>> listarAmigosAceitos() async {
    if (simularErro) {
      throw FriendshipException(FriendshipErrorCode.unavailable, mensagemErro);
    }
    return List.from(_amigosPorUsuario[_uidAtual] ?? []);
  }

  @override
  Future<List<SolicitacaoAmizade>> listarSolicitacoesPendentes() async {
    if (simularErro) {
      throw FriendshipException(FriendshipErrorCode.unavailable, mensagemErro);
    }
    return List.from(_solicitacoesPorUsuario[_uidAtual] ?? []);
  }

  @override
  Future<ResultadoAceiteAmizade> aceitarSolicitacaoAmizade(String solicitacaoId) async =>
      ResultadoAceiteAmizade(
        friendshipId: solicitacaoId,
        userAId: 'origem',
        userBId: _uidAtual ?? '',
        status: FriendshipStatus.accepted,
      );

  @override
  Future<ResultadoRecusaAmizade> recusarSolicitacaoAmizade(String solicitacaoId) async =>
      ResultadoRecusaAmizade(
        friendshipId: solicitacaoId,
        userAId: 'origem',
        userBId: _uidAtual ?? '',
        status: FriendshipStatus.rejected,
      );

  @override
  Future<ResultadoEnvioAmizade> enviarSolicitacaoAmizade(String toUserId) async =>
      const ResultadoEnvioAmizade(
        friendshipId: 'solic-nova',
        status: FriendshipStatus.pending,
        autoAccepted: false,
      );
}

class _ControladorDeBusca implements UserSearchRepository {
  List<UsuarioPublico> bancoUsuarios = [];

  @override
  Future<List<UsuarioPublico>> buscarUsuarios(
    String termo, {
    required String usuarioAtualUid,
    int limite = 20,
  }) async {
    final t = termo.trim().toLowerCase().replaceFirst('@', '');
    return bancoUsuarios.where((u) {
      if (u.userId == usuarioAtualUid) return false;
      return u.username.toLowerCase().contains(t) || u.displayName.toLowerCase().contains(t);
    }).toList();
  }
}

class _FakeChallengeRepository implements ChallengeRepository {
  final Map<String, StreamController<List<ChallengeModel>>> _streams = {};
  final List<ChallengeModel> _desafios = [];
  final _ControladorDePerfis _perfis;

  _FakeChallengeRepository(this._perfis);

  void notificar() {
    for (final entry in _streams.entries) {
      final uid = entry.key;
      final lista = _desafios.where((c) => c.temParticipante(uid)).toList();
      if (!entry.value.isClosed) {
        entry.value.add(List.from(lista));
      }
    }
  }

  @override
  Stream<List<ChallengeModel>> observarDesafiosDoUsuario(String uid) async* {
    final lista = _desafios.where((c) => c.temParticipante(uid)).toList();
    yield List.from(lista);
    final controller = _streams.putIfAbsent(uid, () => StreamController<List<ChallengeModel>>.broadcast());
    yield* controller.stream;
  }

  @override
  Future<List<ChallengeModel>> listarDesafiosDoUsuario(String uid) async {
    return _desafios.where((c) => c.temParticipante(uid)).toList();
  }

  @override
  Future<int?> buscarSaldoDisponivel(String uid) async {
    return _perfis._carteiras[uid]?.saldoDisponivel;
  }

  @override
  Future<List<AmigoItem>> listarAmigosAceitos(String uid) async {
    return (_perfis._perfis.values)
        .where((p) => p.uid != uid)
        .map((p) => AmigoItem(uid: p.uid, displayName: p.displayName, username: p.username))
        .toList();
  }

  @override
  Future<CriarDesafioResponse> criarDesafio(CriarDesafioRequest request) async {
    final criadorUid = request.challengedId == 'uidBia' ? 'uidAna' : 'uidBia';
    final saldoAtual = _perfis._carteiras[criadorUid];
    if (saldoAtual != null) {
      _perfis.atualizarCarteira(
        criadorUid,
        disponivel: saldoAtual.saldoDisponivel - request.amount,
        reservado: saldoAtual.saldoReservado + request.amount,
      );
    }
    final id = 'desafio-${_desafios.length + 1}';
    final now = DateTime.now();
    final model = ChallengeModel(
      id: id,
      challengerId: criadorUid,
      challengedId: request.challengedId,
      participants: [criadorUid, request.challengedId],
      matchId: request.matchId,
      challengerPrediction: request.challengerPrediction,
      amount: request.amount,
      status: StatusDesafio.pending,
      createdAt: now,
      updatedAt: now,
    );
    _desafios.add(model);
    notificar();
    return CriarDesafioResponse(
      challengeId: id,
      status: StatusDesafio.pending,
      challengerId: criadorUid,
      challengedId: request.challengedId,
      matchId: request.matchId,
      challengerPrediction: request.challengerPrediction,
      amount: request.amount,
    );
  }

  @override
  Future<AceitarDesafioResponse> aceitarDesafio(AceitarDesafioRequest request) async {
    final index = _desafios.indexWhere((c) => c.id == request.challengeId);
    final desafio = _desafios[index];
    final desafiadoUid = desafio.challengedId;
    final saldoAtual = _perfis._carteiras[desafiadoUid];
    if (saldoAtual != null) {
      _perfis.atualizarCarteira(
        desafiadoUid,
        disponivel: saldoAtual.saldoDisponivel - desafio.amount,
        reservado: saldoAtual.saldoReservado + desafio.amount,
      );
    }
    final now = DateTime.now();
    _desafios[index] = ChallengeModel(
      id: desafio.id,
      challengerId: desafio.challengerId,
      challengedId: desafio.challengedId,
      participants: desafio.participants,
      matchId: desafio.matchId,
      challengerPrediction: desafio.challengerPrediction,
      challengedPrediction: request.challengedPrediction,
      amount: desafio.amount,
      status: StatusDesafio.accepted,
      createdAt: desafio.createdAt,
      acceptedAt: now,
      updatedAt: now,
    );
    notificar();
    return AceitarDesafioResponse(
      challengeId: desafio.id,
      status: StatusDesafio.accepted,
      challengerId: desafio.challengerId,
      challengedId: desafio.challengedId,
      matchId: desafio.matchId,
      challengerPrediction: desafio.challengerPrediction,
      challengedPrediction: request.challengedPrediction,
      amount: desafio.amount,
      acceptedAt: now,
    );
  }

  @override
  Future<EncerrarDesafioResponse> recusarDesafio(String challengeId) async {
    final index = _desafios.indexWhere((c) => c.id == challengeId);
    final desafio = _desafios[index];
    final criadorCarteira = _perfis._carteiras[desafio.challengerId];
    if (criadorCarteira != null) {
      _perfis.atualizarCarteira(
        desafio.challengerId,
        disponivel: criadorCarteira.saldoDisponivel + desafio.amount,
        reservado: criadorCarteira.saldoReservado - desafio.amount,
      );
    }
    _desafios[index] = ChallengeModel(
      id: desafio.id,
      challengerId: desafio.challengerId,
      challengedId: desafio.challengedId,
      participants: desafio.participants,
      matchId: desafio.matchId,
      challengerPrediction: desafio.challengerPrediction,
      amount: desafio.amount,
      status: StatusDesafio.rejected,
      createdAt: desafio.createdAt,
      updatedAt: DateTime.now(),
    );
    notificar();
    return EncerrarDesafioResponse(challengeId: challengeId, status: StatusDesafio.rejected);
  }

  @override
  Future<EncerrarDesafioResponse> cancelarDesafio(String challengeId) async {
    final index = _desafios.indexWhere((c) => c.id == challengeId);
    final desafio = _desafios[index];
    final criadorCarteira = _perfis._carteiras[desafio.challengerId];
    if (criadorCarteira != null) {
      _perfis.atualizarCarteira(
        desafio.challengerId,
        disponivel: criadorCarteira.saldoDisponivel + desafio.amount,
        reservado: criadorCarteira.saldoReservado - desafio.amount,
      );
    }
    _desafios[index] = ChallengeModel(
      id: desafio.id,
      challengerId: desafio.challengerId,
      challengedId: desafio.challengedId,
      participants: desafio.participants,
      matchId: desafio.matchId,
      challengerPrediction: desafio.challengerPrediction,
      amount: desafio.amount,
      status: StatusDesafio.cancelled,
      createdAt: desafio.createdAt,
      updatedAt: DateTime.now(),
    );
    notificar();
    return EncerrarDesafioResponse(challengeId: challengeId, status: StatusDesafio.cancelled);
  }

  void resolverPartidaEFinalizarDesafio({
    required String challengeId,
    required String winnerId,
    required String loserId,
  }) {
    final index = _desafios.indexWhere((c) => c.id == challengeId);
    if (index == -1) return;
    final desafio = _desafios[index];

    final carteiraVencedor = _perfis._carteiras[winnerId]!;
    _perfis.atualizarCarteira(
      winnerId,
      disponivel: carteiraVencedor.saldoDisponivel + (desafio.amount * 2),
      reservado: carteiraVencedor.saldoReservado - desafio.amount,
    );

    final carteiraPerdedor = _perfis._carteiras[loserId]!;
    _perfis.atualizarCarteira(
      loserId,
      disponivel: carteiraPerdedor.saldoDisponivel,
      reservado: carteiraPerdedor.saldoReservado - desafio.amount,
    );

    _desafios[index] = ChallengeModel(
      id: desafio.id,
      challengerId: desafio.challengerId,
      challengedId: desafio.challengedId,
      participants: desafio.participants,
      matchId: desafio.matchId,
      challengerPrediction: desafio.challengerPrediction,
      challengedPrediction: desafio.challengedPrediction,
      amount: desafio.amount,
      status: StatusDesafio.finished,
      winnerId: winnerId,
      createdAt: desafio.createdAt,
      acceptedAt: desafio.acceptedAt,
      finishedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notificar();
  }
}

class _FakePartidasControlado extends PartidasService {
  final List<PartidaModel> partidasElegiveis;
  _FakePartidasControlado(this.partidasElegiveis);

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    return List.from(partidasElegiveis);
  }
}

// ============================================================================
// SUÍTE DE TESTES DE INTEGRAÇÃO DA JORNADA COMPLETA
// ============================================================================

void main() {
  late _JornadaAuthService authService;
  late _ControladorDePerfis perfisRepo;
  late _ControladorDeAmizades amizadesRepo;
  late _ControladorDeBusca buscaRepo;
  late _FakeChallengeRepository challengeRepo;
  late ChallengeService challengeService;
  late _FakePartidasControlado partidasService;

  late UserProfileService userProfileService;
  late FriendshipService friendshipService;
  late UserSearchService userSearchService;

  final partida1 = PartidaModel(
    id: 'match-101',
    timeMandante: 'Flamengo',
    timeVisitante: 'Fluminense',
    golsMandante: 1,
    golsVisitante: 0,
    status: 'EM ANDAMENTO',
  );

  setUp(() {
    authService = _JornadaAuthService(
      usuarioInicial: FakeUser('uidAna', email: 'ana@example.com'),
    );
    perfisRepo = _ControladorDePerfis();
    amizadesRepo = _ControladorDeAmizades();
    buscaRepo = _ControladorDeBusca();
    challengeRepo = _FakeChallengeRepository(perfisRepo);
    challengeService = ChallengeService(
      authService: authService,
      repository: challengeRepo,
    );
    partidasService = _FakePartidasControlado([partida1]);

    userProfileService = UserProfileService(
      authService: authService,
      repository: perfisRepo,
    );
    friendshipService = FriendshipService(
      authService: authService,
      repository: amizadesRepo,
    );
    userSearchService = UserSearchService(
      authService: authService,
      repository: buscaRepo,
    );

    // Cria as duas contas de demonstração controladas
    // Ana Lima: uidAna, @AnaL, 1000 BetCoins disponíveis
    perfisRepo.cadastrarUsuario(
      uid: 'uidAna',
      displayName: 'Ana Lima',
      username: 'AnaL',
      saldoDisponivel: 1000,
    );
    // Bia Rocha: uidBia, @BiaR, 1000 BetCoins disponíveis
    perfisRepo.cadastrarUsuario(
      uid: 'uidBia',
      displayName: 'Bia Rocha',
      username: 'BiaR',
      saldoDisponivel: 1000,
    );

    // Ana tem Bia como amiga aceita
    amizadesRepo.adicionarAmizadeAceita(
      'uidAna',
      const UsuarioPublico(userId: 'uidBia', displayName: 'Bia Rocha', username: 'BiaR'),
    );
    // Bia tem Ana como amiga aceita
    amizadesRepo.adicionarAmizadeAceita(
      'uidBia',
      const UsuarioPublico(userId: 'uidAna', displayName: 'Ana Lima', username: 'AnaL'),
    );
  });

  Widget construirApp() {
    return App(
      authService: authService,
      partidasService: partidasService,
      userProfileService: userProfileService,
      challengeService: challengeService,
      friendshipService: friendshipService,
      userSearchService: userSearchService,
    );
  }

  testWidgets(
    'Jornada completa e integrada do MVP com duas contas (Ana e Bia), criação/aceite de desafio, reserva de BetCoins, resolução e navegação sem crash',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // ----------------------------------------------------------------------
      // PASSO 1: Login de Ana Lima
      // ----------------------------------------------------------------------
      amizadesRepo.definirUidAtual('uidAna');

      await tester.pumpWidget(construirApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Home carrega com a saudação de Ana e carteira de Ana
      expect(find.text('Olá, Ana Lima'), findsOneWidget);
      expect(find.byKey(const Key('home_saldo')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('home_saldo'))).data, '1000 BetCoins');

      // ----------------------------------------------------------------------
      // PASSO 2: Navegação Home -> Perfil -> Meus Amigos
      // ----------------------------------------------------------------------
      // Toca no botão de Perfil na barra inferior (ícone ou índice 2)
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      expect(find.byType(PerfilScreen), findsOneWidget);
      expect(find.text('Ana Lima'), findsWidgets);
      expect(find.text('@AnaL'), findsOneWidget);

      // Abre a lista de amigos a partir do Perfil
      await tester.tap(find.byKey(const Key('perfil_meus_amigos')));
      await tester.pumpAndSettle();

      expect(find.byType(TelaListaAmigos), findsOneWidget);
      expect(find.text('Bia Rocha'), findsOneWidget);
      expect(find.text('@BiaR'), findsOneWidget);

      // ----------------------------------------------------------------------
      // PASSO 3: Clicar em "DESAFIAR" no card de Bia -> Abre CriarDesafioScreen com Bia pré-selecionada
      // ----------------------------------------------------------------------
      final btnDesafiarBia = find.byKey(const Key('btn_desafiar_amigo_uidBia'));
      expect(btnDesafiarBia, findsOneWidget);
      await tester.tap(btnDesafiarBia);
      await tester.pumpAndSettle();

      expect(find.byType(CriarDesafioScreen), findsOneWidget);

      // Rola para visualizar o amigo selecionado no ListView
      await tester.scrollUntilVisible(
        find.text('Bia Rocha'),
        200,
      );
      // Valida que Bia Rocha foi pré-selecionada automaticamente
      expect(find.text('Bia Rocha'), findsWidgets);

      // Seleciona aposta de 100 BetCoins
      await tester.tap(find.byKey(const Key('chip_valor_100')));
      await tester.pumpAndSettle();

      // Envia o desafio contra Bia
      final btnEnviarDesafio = find.byKey(const Key('btn_enviar_desafio'));
      expect(btnEnviarDesafio, findsOneWidget);
      await tester.tap(btnEnviarDesafio);
      await tester.pumpAndSettle();

      // Confirmação de retorno após criação do desafio
      expect(find.byType(TelaListaAmigos), findsOneWidget);

      // Volta para o Perfil
      await tester.tap(find.byKey(const Key('btn_voltar_amigos')));
      await tester.pumpAndSettle();
      expect(find.byType(PerfilScreen), findsOneWidget);

      // Volta de Perfil para Home
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.byType(Homepage), findsOneWidget);

      // Carteira de Ana foi atualizada: 900 BetCoins disponíveis (100 reservadas)
      expect(tester.widget<Text>(find.byKey(const Key('home_saldo'))).data, '900 BetCoins');

      // Na Home de Ana, a seção de Desafios Enviados exibe o desafio pendente
      expect(find.text('DESAFIOS ENVIADOS'), findsOneWidget);
      expect(find.text('Aguardando uidBia'), findsOneWidget);

      // ----------------------------------------------------------------------
      // PASSO 4: Logout de Ana Lima com confirmação
      // ----------------------------------------------------------------------
      // Toca no menu da conta no cabeçalho
      await tester.tap(find.byKey(const Key('menu_conta')));
      await tester.pumpAndSettle();

      // Clica em 'Sair da conta'
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      // Diálogo de confirmação aparece
      expect(find.text('Sair da conta?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Sair'));
      await tester.pumpAndSettle();

      // AuthGate redireciona para LoginPage
      expect(find.byType(LoginPage), findsOneWidget);

      // ----------------------------------------------------------------------
      // PASSO 5: Login como Bia Rocha
      // ----------------------------------------------------------------------
      amizadesRepo.definirUidAtual('uidBia');
      await tester.enterText(find.byType(TextField).first, 'bia@example.com');
      await tester.enterText(find.byType(TextField).last, 'senha123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'ENTRAR'));
      await tester.pumpAndSettle();

      // Home agora é a de Bia Rocha
      expect(find.byType(Homepage), findsOneWidget);
      expect(find.text('Olá, Bia Rocha'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('home_saldo'))).data, '1000 BetCoins'); // Saldo disponível de Bia

      // Home de Bia destaca o desafio recebido de Ana!
      expect(find.text('DESAFIOS RECEBIDOS'), findsOneWidget);
      expect(find.byKey(const Key('btn_responder_desafio_desafio-1')), findsOneWidget);

      // ----------------------------------------------------------------------
      // PASSO 6: Bia abre o modal e aceita o desafio
      // ----------------------------------------------------------------------
      await tester.scrollUntilVisible(
        find.byKey(const Key('btn_responder_desafio_desafio-1')),
        200,
      );
      await tester.tap(find.byKey(const Key('btn_responder_desafio_desafio-1')));
      await tester.pumpAndSettle();

      expect(find.byType(ModalAceitarDesafio), findsOneWidget);
      expect(find.text('Valor apostado: 100 BetCoins'), findsOneWidget);

      // Seleciona o palpite permitido (Vitória Visitante)
      final palpiteVisitante = find.text('Vitória Visitante');
      expect(palpiteVisitante, findsOneWidget);
      await tester.tap(palpiteVisitante);
      await tester.pumpAndSettle();

      // Confirma e aceita o desafio
      final btnConfirmarAceite = find.text('CONFIRMAR E ACEITAR');
      expect(btnConfirmarAceite, findsOneWidget);
      await tester.tap(btnConfirmarAceite);
      await tester.pumpAndSettle();

      // Modal fechado; volta à Home de Bia
      expect(find.byType(ModalAceitarDesafio), findsNothing);
      expect(find.byType(Homepage), findsOneWidget);

      // Carteira de Bia foi atualizada: 100 reservadas, 900 disponíveis
      expect(tester.widget<Text>(find.byKey(const Key('home_saldo'))).data, '900 BetCoins');

      // O desafio evoluiu para Aceito e foi para a seção "DESAFIOS EM ABERTO"
      expect(find.byKey(const Key('home_desafios_em_aberto')), findsOneWidget);
      expect(find.text('DESAFIOS EM ABERTO'), findsOneWidget);
      expect(find.text('Aceito'), findsOneWidget);

      // ----------------------------------------------------------------------
      // PASSO 7: Encerramento do desafio e validação dos resultados
      // ----------------------------------------------------------------------
      challengeRepo.resolverPartidaEFinalizarDesafio(
        challengeId: 'desafio-1',
        winnerId: 'uidAna',
        loserId: 'uidBia',
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Na Home de Bia, o desafio aparece na seção de DESAFIOS FINALIZADOS
      expect(find.byKey(const Key('home_desafios_finalizados')), findsOneWidget);
      expect(find.text('DESAFIOS FINALIZADOS'), findsOneWidget);

      // ----------------------------------------------------------------------
      // PASSO 8: Navegação até Informações e Créditos (RNF-011, RNF-012, D-015)
      // ----------------------------------------------------------------------
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.byType(PerfilScreen), findsOneWidget);

      // Rola até o botão de Informações e Créditos
      await tester.scrollUntilVisible(
        find.byKey(const Key('perfil_informacoes_creditos')),
        200,
      );
      await tester.tap(find.byKey(const Key('perfil_informacoes_creditos')));
      await tester.pumpAndSettle();

      expect(find.byType(TelaInformacoesCreditos), findsOneWidget);
      // Validar atribuição exata e obrigatória
      expect(find.text('Dados fornecidos por football-data.org'), findsOneWidget);

      // Retorna em segurança
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.byType(PerfilScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.byType(Homepage), findsOneWidget);
    },
  );

  testWidgets(
    'Tratamento honesto de estados de erro, vazio e offline sem dados falsos',
    (tester) async {
      // Usuário sem amigos cadastrados
      perfisRepo.cadastrarUsuario(
        uid: 'uidNovo',
        displayName: 'Novo Usuário',
        username: 'NovoU',
        saldoDisponivel: 500,
      );
      authService = _JornadaAuthService(
        usuarioInicial: FakeUser('uidNovo', email: 'novo@example.com'),
      );
      amizadesRepo.definirUidAtual('uidNovo');

      await tester.pumpWidget(construirApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Abre lista de amigos
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('perfil_meus_amigos')));
      await tester.pumpAndSettle();

      // Estado vazio amigável
      expect(find.byKey(const Key('lista_amigos_vazia')), findsOneWidget);
      expect(find.text('Nenhum amigo adicionado'), findsOneWidget);
      expect(find.byKey(const Key('btn_buscar_amigos_vazio')), findsOneWidget);

      // Simula erro de comunicação no serviço de amizade
      amizadesRepo.simularErro = true;
      amizadesRepo.mensagemErro = 'Falha temporária de rede.';
      await tester.tap(find.byKey(const Key('btn_voltar_amigos')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('perfil_meus_amigos')));
      await tester.pumpAndSettle();

      // Exibe mensagem de erro honesta sem inventar amigos
      expect(find.text('Falha ao carregar amigos'), findsOneWidget);
      expect(find.text('Falha temporária de rede.'), findsOneWidget);

      // Restaura amizade
      amizadesRepo.simularErro = false;
      await tester.tap(find.byKey(const Key('btn_voltar_amigos')));
      await tester.pumpAndSettle();

      // Simula perfil operando offline (cache)
      perfisRepo.setOffline(true);
      await tester.pumpAndSettle();

      // Exibe aviso de sem conexão no perfil
      expect(find.byType(AvisoSemConexao), findsOneWidget);
      expect(find.byKey(const Key('perfil_sem_conexao')), findsOneWidget);
    },
  );
}
