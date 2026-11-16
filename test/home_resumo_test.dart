// Visualizar resumo da Home (D-003, Plano Mestre v3.2)
//
// Critérios de Aceitação:
// - Página inicial exibe saldo de BetCoins;
// - Home exibe desafios em aberto;
// - Home exibe próximos jogos;
// - Home destaca desafios recebidos aguardando resposta;
// - Home destaca desafios recentemente finalizados;
// - Os dados exibidos são agregados a partir dos módulos existentes;
// - Home não implementa ranking, feed ou sistema de notificações.
//
// Validações:
// - Home com todos os dados disponíveis;
// - Home sem desafios pendentes;
// - Casa sem partidas próximas ("Nenhuma partida disponível");
// - Validar ausência de funcionalidades fora do escopo.

import 'dart:async';

import 'package:betfriends/app.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/carteira.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/telas_principais/homePage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

/// Repositório de perfil controlado para testes.
class _RepositorioPerfilControlado implements UserProfileRepository {
  final _controller = StreamController<PerfilObservado>.broadcast();

  void emitir(UserProfile? perfil, {Carteira? carteira, bool doCache = false}) =>
      _controller.add(PerfilObservado(perfil, carteira: carteira, doCache: doCache));

  @override
  Stream<PerfilObservado> observarPorUid(String uid) => _controller.stream;

  @override
  Future<UserProfile?> buscarPorUid(String uid) async => null;

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {}
}

/// Fake do ChallengeService com controle de emissões de Stream.
class _FakeChallengeServiceControlado implements ChallengeService {
  final _desafiosController = StreamController<List<ChallengeModel>>.broadcast();
  List<ChallengeModel> _ultimoValor = [];

  void emitirDesafios(List<ChallengeModel> lista) {
    _ultimoValor = lista;
    _desafiosController.add(lista);
  }

  @override
  Stream<List<ChallengeModel>> observarDesafios() => _desafiosController.stream;

  @override
  Future<List<ChallengeModel>> listarDesafios() async => _ultimoValor;

  @override
  Future<int?> buscarSaldoDisponivel() async => 750;

  @override
  Future<List<AmigoItem>> listarAmigosAceitos() async => [];

  @override
  Future<CriarDesafioResponse> criarDesafio({
    required String challengedId,
    required String matchId,
    required Palpite challengerPrediction,
    required int amount,
  }) async =>
      CriarDesafioResponse(
        challengeId: 'chl_new',
        status: StatusDesafio.pending,
        challengerId: 'uid-ana',
        challengedId: challengedId,
        matchId: matchId,
        challengerPrediction: challengerPrediction,
        amount: amount,
      );

  @override
  Future<AceitarDesafioResponse> aceitarDesafio({
    required String challengeId,
    required Palpite challengedPrediction,
  }) async =>
      AceitarDesafioResponse(
        challengeId: challengeId,
        status: StatusDesafio.accepted,
        challengerId: 'Pedro',
        challengedId: 'uid-ana',
        matchId: 'partida_101',
        challengerPrediction: Palpite.homeWin,
        challengedPrediction: challengedPrediction,
        amount: 50,
        acceptedAt: DateTime.now(),
      );
}

/// Fake de PartidasService configurável para simular partidas presentes ou vazias.
class _FakePartidasServiceConfiguravel extends PartidasService {
  final List<PartidaModel> partidasRetorno;

  _FakePartidasServiceConfiguravel(this.partidasRetorno);

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async => partidasRetorno;
}

void main() {
  const currentUserId = 'uid-ana';
  late FakeAuthService authService;
  late _RepositorioPerfilControlado perfilRepo;
  late _FakeChallengeServiceControlado challengeService;

  setUp(() {
    authService = FakeAuthService(usuarioInicial: FakeUser(currentUserId));
    perfilRepo = _RepositorioPerfilControlado();
    challengeService = _FakeChallengeServiceControlado();
  });

  Future<void> renderizarHome(
    WidgetTester tester, {
    List<PartidaModel> partidas = const [],
  }) async {
    final partidasService = _FakePartidasServiceConfiguravel(partidas);

    await tester.pumpWidget(App(
      authService: authService,
      partidasService: partidasService,
      userProfileService: UserProfileService(authService: authService, repository: perfilRepo),
      challengeService: challengeService,
    ));

    await tester.pumpAndSettle();
    expect(find.byType(Homepage), findsOneWidget);
  }

  Future<void> encerrar(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  final desafioPendenteRecebido = ChallengeModel(
    id: 'chl_pendente_1',
    challengerId: 'Pedro',
    challengedId: currentUserId,
    participants: ['Pedro', currentUserId],
    matchId: 'partida_101',
    challengerPrediction: Palpite.homeWin,
    amount: 50,
    status: StatusDesafio.pending,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final desafioEmAberto = ChallengeModel(
    id: 'chl_aberto_2',
    challengerId: currentUserId,
    challengedId: 'Lucas',
    participants: [currentUserId, 'Lucas'],
    matchId: 'partida_102',
    challengerPrediction: Palpite.awayWin,
    challengedPrediction: Palpite.draw,
    amount: 100,
    status: StatusDesafio.accepted,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final desafioFinalizadoVitoria = ChallengeModel(
    id: 'chl_finalizado_3',
    challengerId: 'Guilherme',
    challengedId: currentUserId,
    participants: ['Guilherme', currentUserId],
    matchId: 'partida_103',
    challengerPrediction: Palpite.homeWin,
    challengedPrediction: Palpite.awayWin,
    winnerId: currentUserId,
    amount: 80,
    status: StatusDesafio.finished,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final partidasExemplo = [
    PartidaModel(
      id: 'partida_101',
      timeMandante: 'Flamengo',
      timeVisitante: 'Vasco',
      horario: 'Amanhã 16:00',
      status: 'PRÓXIMO JOGO',
      campeonato: 'Brasileirão',
    ),
    PartidaModel(
      id: 'partida_102',
      timeMandante: 'Palmeiras',
      timeVisitante: 'Santos',
      horario: 'Domingo 18:30',
      status: 'PRÓXIMO JOGO',
      campeonato: 'Brasileirão',
    ),
  ];

  group('Visualizar resumo da Home (D-003, Plano Mestre v3.2)', () {
    testWidgets('Home com todos os dados disponíveis (saldo, partidas, pendentes, abertos, finalizados)', (tester) async {
      await renderizarHome(tester, partidas: partidasExemplo);

      // Emite perfil e saldo de BetCoins (RF-003, RN-BET-004)
      perfilRepo.emitir(
        UserProfile(
          uid: currentUserId,
          displayName: 'Ana Lima',
          username: 'analima',
          usernameNormalized: 'analima',
          email: 'ana@example.com',
        ),
        carteira: Carteira(saldoTotal: 1000, saldoReservado: 250),
      );

      // Emite desafios nos 3 estados
      challengeService.emitirDesafios([
        desafioPendenteRecebido,
        desafioEmAberto,
        desafioFinalizadoVitoria,
      ]);

      await tester.pump();
      await tester.pump();

      // 1. Saldo de BetCoins exibido e consistente
      expect(find.byKey(const Key('home_saldo')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('home_saldo'))).data, '750 BetCoins');
      expect(find.byKey(const Key('card_carteira_container')), findsOneWidget);

      // 2. Próximos jogos exibidos
      expect(find.text('PARTIDAS'), findsOneWidget);
      expect(find.text('Flamengo'), findsOneWidget);
      expect(find.text('Vasco'), findsOneWidget);

      // 3. Destaque: alerta no topo de desafios recebidos aguardando resposta
      expect(find.byKey(const Key('home_alerta_desafios_pendentes')), findsOneWidget);
      expect(find.textContaining('desafio(s) aguardando sua resposta'), findsOneWidget);

      // Rola para a seção de desafios
      await tester.scrollUntilVisible(find.byKey(const Key('home_desafios_recebidos_pendentes')), 200);

      // 4. Seção destacada de Desafios Recebidos
      expect(find.byKey(const Key('home_desafios_recebidos_pendentes')), findsOneWidget);
      expect(find.byKey(const Key('badge_desafios_pendentes')), findsOneWidget);
      expect(find.byKey(const Key('card_desafio_pendente_chl_pendente_1')), findsOneWidget);
      expect(find.text('Desafio de Pedro'), findsOneWidget);
      expect(find.text('Partida #partida_101 • 50 BetCoins'), findsOneWidget);
      expect(find.byKey(const Key('btn_responder_desafio_chl_pendente_1')), findsOneWidget);

      // 5. Seção de Desafios em Aberto
      await tester.scrollUntilVisible(find.byKey(const Key('card_desafio_aberto_chl_aberto_2')), 200);
      expect(find.byKey(const Key('home_desafios_em_aberto')), findsOneWidget);
      expect(find.byKey(const Key('card_desafio_aberto_chl_aberto_2')), findsOneWidget);
      expect(find.text('$currentUserId x Lucas'), findsOneWidget);
      expect(find.text('Partida #partida_102 • 100 BetCoins'), findsOneWidget);

      // 6. Destaque de Desafios Recentemente Finalizados
      await tester.scrollUntilVisible(find.byKey(const Key('card_desafio_finalizado_chl_finalizado_3')), 200);
      expect(find.byKey(const Key('home_desafios_finalizados')), findsOneWidget);
      expect(find.byKey(const Key('badge_desafios_finalizados')), findsOneWidget);
      expect(find.byKey(const Key('card_desafio_finalizado_chl_finalizado_3')), findsOneWidget);
      expect(find.text('Você venceu!'), findsOneWidget);

      await encerrar(tester);
    });

    testWidgets('Home sem desafios pendentes não exibe destaque de pendentes mas exibe abertos', (tester) async {
      await renderizarHome(tester, partidas: partidasExemplo);

      perfilRepo.emitir(
        UserProfile(
          uid: currentUserId,
          displayName: 'Ana Lima',
          username: 'analima',
          usernameNormalized: 'analima',
          email: 'ana@example.com',
        ),
        carteira: Carteira(saldoTotal: 1000, saldoReservado: 0),
      );

      // Apenas desafios abertos e finalizados, nenhum pendente recebido
      challengeService.emitirDesafios([
        desafioEmAberto,
        desafioFinalizadoVitoria,
      ]);

      await tester.pump();
      await tester.pump();

      // Destaque de pendentes NÃO deve aparecer
      expect(find.byKey(const Key('home_alerta_desafios_pendentes')), findsNothing);
      expect(find.byKey(const Key('home_desafios_recebidos_pendentes')), findsNothing);
      expect(find.byKey(const Key('badge_desafios_pendentes')), findsNothing);

      // Desafios em aberto continuam visíveis normalmente
      await tester.scrollUntilVisible(find.byKey(const Key('home_desafios_em_aberto')), 200);
      expect(find.byKey(const Key('home_desafios_em_aberto')), findsOneWidget);
      expect(find.byKey(const Key('card_desafio_aberto_chl_aberto_2')), findsOneWidget);

      await encerrar(tester);
    });

    testWidgets('Home sem partidas próximas exibe container amigável sem quebrar o layout', (tester) async {
      // Lista de partidas vazia
      await renderizarHome(tester, partidas: []);

      perfilRepo.emitir(
        UserProfile(
          uid: currentUserId,
          displayName: 'Ana Lima',
          username: 'analima',
          usernameNormalized: 'analima',
          email: 'ana@example.com',
        ),
        carteira: Carteira(saldoTotal: 500, saldoReservado: 0),
      );

      challengeService.emitirDesafios([desafioEmAberto]);

      await tester.pump();
      await tester.pump();

      // Exibe estado amigável de partidas indisponíveis
      expect(find.text('Nenhuma partida disponível'), findsOneWidget);
      expect(find.text('Não encontramos partidas disponíveis no momento.'), findsOneWidget);
      expect(find.text('ATUALIZAR'), findsOneWidget);

      // Saldo de BetCoins continua operando
      expect(tester.widget<Text>(find.byKey(const Key('home_saldo'))).data, '500 BetCoins');

      // Desafios continuam operando
      await tester.scrollUntilVisible(find.byKey(const Key('card_desafio_aberto_chl_aberto_2')), 200);
      expect(find.byKey(const Key('card_desafio_aberto_chl_aberto_2')), findsOneWidget);

      await encerrar(tester);
    });

    testWidgets('validar ausência de funcionalidades fora do escopo (sem ranking, sem feed, sem notificações)', (tester) async {
      await renderizarHome(tester, partidas: partidasExemplo);

      // 1. Sem ranking (D-002, RN-RNK-001)
      expect(find.text('Ranking'), findsNothing);
      expect(find.text('Leaderboard'), findsNothing);
      expect(find.text('Classificação'), findsNothing);

      final barraNavegacao = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(barraNavegacao.items.map((i) => i.label), ['Home', 'Desafios', 'Perfil']);

      // 2. Sem feed genérico ou rede social (D-003)
      expect(find.text('Feed'), findsNothing);
      expect(find.text('Comentários'), findsNothing);
      expect(find.text('Publicações'), findsNothing);
      expect(find.text('Postagens'), findsNothing);

      // 3. Sem sistema de notificações gerais do app (D-003)
      expect(find.byIcon(Icons.notifications), findsNothing);
      expect(find.byIcon(Icons.notifications_active), findsNothing);
      expect(find.text('Notificações'), findsNothing);

      await encerrar(tester);
    });

    testWidgets('Home sem nenhum desafio exibe estado vazio amigável com botão de criar desafio', (tester) async {
      await renderizarHome(tester, partidas: partidasExemplo);

      // Lista vazia de desafios
      challengeService.emitirDesafios([]);

      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(find.byKey(const Key('home_desafios_vazio')), 200);
      expect(find.byKey(const Key('home_desafios_vazio')), findsOneWidget);
      expect(find.text('Nenhum desafio no momento'), findsOneWidget);
      expect(find.byKey(const Key('btn_home_criar_desafio')), findsOneWidget);

      await encerrar(tester);
    });
  });
}
