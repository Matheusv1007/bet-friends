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
import 'package:betfriends/widgets_home_page/card_de_desafios_ativos.dart';
import 'package:betfriends/data/firestore/challenge_repository.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/data/firestore/historico_de_desafios_repository.dart';
import 'package:betfriends/models/carteira.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/services/historico_de_desafios_service.dart';
import 'package:betfriends/tela_historico/tela_historico_desafios.dart';
import 'package:betfriends/telas_principais/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

/// Repositório de perfil controlado para testes.
class _RepositorioPerfilControlado implements UserProfileRepository {
  final _controller = StreamController<PerfilObservado>.broadcast();

  void emitir(
    UserProfile? perfil, {
    Carteira? carteira,
    bool doCache = false,
  }) => _controller.add(
    PerfilObservado(perfil, carteira: carteira, doCache: doCache),
  );

  @override
  Stream<PerfilObservado> observarPorUid(String uid) => _controller.stream;

  @override
  Future<UserProfile?> buscarPorUid(String uid) async => null;

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {}
}

/// Fake do ChallengeService com controle de emissões de Stream.
class _FakeChallengeServiceControlado implements ChallengeService {
  final _desafiosController =
      StreamController<List<ChallengeModel>>.broadcast();
  List<ChallengeModel> _ultimoValor = [];

  void emitirDesafios(List<ChallengeModel> lista) {
    _ultimoValor = lista;
    _desafiosController.add(lista);
  }

  @override
  Stream<List<ChallengeModel>> observarDesafios() async* {
    yield _ultimoValor;
    yield* _desafiosController.stream;
  }

  @override
  Future<List<ChallengeModel>> listarDesafios() async => _ultimoValor;

  @override
  Future<int?> buscarSaldoDisponivel() async => 750;

  List<AmigoItem> amigos = const [
    AmigoItem(uid: 'u7P9x', displayName: 'Pedro', username: 'pedro'),
    AmigoItem(uid: 'v8Q0z', displayName: 'Lucas', username: 'lucas'),
    AmigoItem(uid: 'w1R2a', displayName: 'Guilherme', username: 'gui'),
  ];
  bool falharNomes = false;

  @override
  Future<List<AmigoItem>> listarAmigosAceitos() async {
    if (falharNomes) throw Exception('Sem conexão');
    return amigos;
  }

  @override
  Future<CriarDesafioResponse> criarDesafio({
    required String challengedId,
    required String matchId,
    required Palpite challengerPrediction,
    required int amount,
  }) async => CriarDesafioResponse(
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
  }) async => AceitarDesafioResponse(
    challengeId: challengeId,
    status: StatusDesafio.accepted,
    challengerId: 'u7P9x',
    challengedId: 'uid-ana',
    matchId: 'partida_101',
    challengerPrediction: Palpite.homeWin,
    challengedPrediction: challengedPrediction,
    amount: 50,
    acceptedAt: DateTime.now(),
  );

  final cancelados = <String>[];
  final recusados = <String>[];
  Exception? erroAoCancelar;

  @override
  Future<EncerrarDesafioResponse> recusarDesafio({
    required String challengeId,
  }) async {
    recusados.add(challengeId);
    return EncerrarDesafioResponse(
      challengeId: challengeId,
      status: StatusDesafio.rejected,
    );
  }

  @override
  Future<EncerrarDesafioResponse> cancelarDesafio({
    required String challengeId,
  }) async {
    if (erroAoCancelar != null) throw erroAoCancelar!;
    cancelados.add(challengeId);
    return EncerrarDesafioResponse(
      challengeId: challengeId,
      status: StatusDesafio.cancelled,
    );
  }
}

/// Fake de PartidasService configurável para simular partidas presentes ou vazias.
class _FakePartidasServiceConfiguravel extends PartidasService {
  final List<PartidaModel> partidasRetorno;

  _FakePartidasServiceConfiguravel(this.partidasRetorno);

  @override
  Future<List<PartidaModel>> getPartidas() async => partidasRetorno;
}

class _FakeHistoricoService extends Fake implements HistoricoDeDesafiosService {
  int consultas = 0;

  @override
  Future<PaginaDoHistorico> buscarDoUsuarioAtual({
    int limite = 20,
    CursorDoHistorico? cursor,
  }) async {
    consultas++;
    return const PaginaDoHistorico(
      itens: [],
      ignorados: 0,
      doCache: false,
      temMais: false,
      proximoCursor: null,
    );
  }
}

void main() {
  testWidgets('N-20: falha tem retry sem desafios demonstrativos', (
    tester,
  ) async {
    var tentativas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesafiosAtivosWidget(
            erro: true,
            onTentarNovamente: () => tentativas++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar os desafios.'), findsOneWidget);
    expect(find.textContaining('DEMONSTRATIVO'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    expect(tentativas, 1);
  });

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
    HistoricoDeDesafiosService? historicoService,
  }) async {
    final partidasService = _FakePartidasServiceConfiguravel(partidas);

    await tester.pumpWidget(
      App(
        authService: authService,
        partidasService: partidasService,
        userProfileService: UserProfileService(
          authService: authService,
          repository: perfilRepo,
        ),
        challengeService: challengeService,
        historicoService: historicoService,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(Homepage), findsOneWidget);
  }

  Future<void> encerrar(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  final desafioPendenteRecebido = ChallengeModel(
    id: 'chl_pendente_1',
    challengerId: 'u7P9x',
    challengedId: currentUserId,
    participants: ['u7P9x', currentUserId],
    matchId: 'partida_101',
    challengerPrediction: Palpite.homeWin,
    amount: 50,
    status: StatusDesafio.pending,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final partidaDoDesafio = PartidaModel(
    id: 'partida_101',
    timeMandante: 'Time A',
    timeVisitante: 'Time B',
  );

  for (final confirmar in [false, true]) {
    testWidgets(
      'recusa inline ${confirmar ? "confirmada" : "cancelada"} preserva a confirmação',
      (tester) async {
        await renderizarHome(tester, partidas: [partidaDoDesafio]);
        challengeService.emitirDesafios([desafioPendenteRecebido]);
        await tester.pumpAndSettle();
        final botao = find.byKey(
          const Key('btn_recusar_desafio_chl_pendente_1'),
        );
        await tester.ensureVisible(botao);
        await tester.pumpAndSettle();
        await tester.tap(botao);
        // O botão continua ocupado enquanto a confirmação está aberta.
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Recusar desafio?'), findsOneWidget);
        expect(challengeService.recusados, isEmpty);
        await tester.tap(
          find.byKey(
            Key(confirmar ? 'btn_confirmar_recusa' : 'btn_manter_recebido'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          challengeService.recusados,
          confirmar ? ['chl_pendente_1'] : isEmpty,
        );
        expect(find.byType(AlertDialog), findsNothing);
        if (confirmar) expect(find.text('Desafio recusado.'), findsOneWidget);
        await encerrar(tester);
      },
    );
  }

  testWidgets('aviso único leva aos recebidos e mostra prêmio líquido', (
    tester,
  ) async {
    await renderizarHome(tester, partidas: [partidaDoDesafio]);
    challengeService.emitirDesafios([desafioPendenteRecebido]);
    await tester.pumpAndSettle();
    final aviso = find.byKey(const Key('home_alerta_desafios_pendentes'));
    expect(aviso, findsOneWidget);
    final responder = find.descendant(
      of: aviso,
      matching: find.text('Responder'),
    );
    await tester.ensureVisible(responder);
    await tester.pumpAndSettle();
    await tester.tap(responder);
    await tester.pumpAndSettle();
    final secao = find.byKey(const Key('home_desafios_recebidos_pendentes'));
    expect(
      tester.getTopLeft(secao).dy,
      lessThan(tester.view.physicalSize.height),
    );
    final tabela = find.byKey(
      const Key('desafio_pendente_info_chl_pendente_1'),
    );
    expect(
      find.descendant(of: tabela, matching: find.text('Time A')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabela, matching: find.text('50')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabela, matching: find.text('+50')),
      findsOneWidget,
    );
    await encerrar(tester);
  });

  testWidgets('T-05: UID desconhecido usa Jogador e atualiza após falha', (
    tester,
  ) async {
    challengeService.falharNomes = true;
    await renderizarHome(tester, partidas: [partidaDoDesafio]);
    challengeService.emitirDesafios([desafioPendenteRecebido]);
    await tester.pumpAndSettle();

    expect(find.text('Jogador te desafiou'), findsOneWidget);
    expect(find.text('Amigo te desafiou'), findsNothing);
    challengeService.falharNomes = false;
    await tester.ensureVisible(find.byKey(const Key('home_atualizar_nomes')));
    await tester.tap(find.byKey(const Key('home_atualizar_nomes')));
    await tester.pumpAndSettle();
    expect(find.text('Pedro te desafiou'), findsOneWidget);
    expect(find.byKey(const Key('home_atualizar_nomes')), findsNothing);
    await encerrar(tester);
  });

  testWidgets(
    'T-05: recarrega amigos quando chega um adversário desconhecido',
    (tester) async {
      challengeService.amigos = [];
      await renderizarHome(tester, partidas: [partidaDoDesafio]);
      challengeService.amigos = const [
        AmigoItem(uid: 'u7P9x', displayName: 'Pedro', username: 'pedro'),
      ];
      challengeService.emitirDesafios([desafioPendenteRecebido]);
      await tester.pumpAndSettle();
      expect(find.text('Pedro te desafiou'), findsOneWidget);
      await encerrar(tester);
    },
  );

  testWidgets('T-05: mantém nome público já visto quando deixa de ser amigo', (
    tester,
  ) async {
    await renderizarHome(tester, partidas: [partidaDoDesafio]);
    challengeService.emitirDesafios([desafioPendenteRecebido]);
    await tester.pumpAndSettle();
    expect(find.text('Pedro te desafiou'), findsOneWidget);

    challengeService.amigos = [];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Pedro te desafiou'), findsOneWidget);
    expect(find.text('Amigo te desafiou'), findsNothing);
    await encerrar(tester);
  });

  final desafioEmAberto = ChallengeModel(
    id: 'chl_aberto_2',
    challengerId: currentUserId,
    challengedId: 'v8Q0z',
    participants: [currentUserId, 'v8Q0z'],
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
    challengerId: 'w1R2a',
    challengedId: currentUserId,
    participants: ['w1R2a', currentUserId],
    matchId: 'partida_103',
    challengerPrediction: Palpite.homeWin,
    challengedPrediction: Palpite.awayWin,
    winnerId: currentUserId,
    amount: 80,
    status: StatusDesafio.finished,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final desafioEnviadoPendente = ChallengeModel(
    id: 'chl_enviado_4',
    challengerId: currentUserId,
    challengedId: 'v8Q0z',
    participants: [currentUserId, 'v8Q0z'],
    matchId: 'partida_104',
    challengerPrediction: Palpite.homeWin,
    amount: 60,
    status: StatusDesafio.pending,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final desafioCanceladoPelaPartida = ChallengeModel(
    id: 'chl_cancelado_5',
    challengerId: 'w1R2a',
    challengedId: currentUserId,
    participants: ['w1R2a', currentUserId],
    matchId: 'partida_105',
    challengerPrediction: Palpite.homeWin,
    challengedPrediction: Palpite.awayWin,
    amount: 80,
    status: StatusDesafio.cancelled,
    cancelReason: 'MATCH_CANCELLED',
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
    testWidgets(
      'Ver todos nos finalizados abre o histórico usando o serviço injetado',
      (tester) async {
        final historicoService = _FakeHistoricoService();
        await renderizarHome(
          tester,
          partidas: partidasExemplo,
          historicoService: historicoService,
        );
        challengeService.emitirDesafios([desafioFinalizadoVitoria]);
        await tester.pump();
        await tester.pump();
        final entrada = find.byKey(const Key('home_ver_todos_desafios'));
        await tester.scrollUntilVisible(entrada, 200);
        await tester.tap(entrada);
        await tester.pumpAndSettle();
        expect(find.byType(TelaHistoricoDesafios), findsOneWidget);
        expect(
          find.text('Você ainda não tem desafios encerrados'),
          findsOneWidget,
        );
        expect(historicoService.consultas, 1);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(Homepage), findsOneWidget);
        await encerrar(tester);
      },
    );

    testWidgets(
      'Home com todos os dados disponíveis (saldo, partidas, pendentes, abertos, finalizados)',
      (tester) async {
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
        expect(
          tester.widget<Text>(find.byKey(const Key('home_saldo'))).data,
          '750',
        );
        expect(find.byKey(const Key('home_bloco_saldo')), findsOneWidget);

        // 2. Próximos jogos exibidos
        expect(find.text('PARTIDAS'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('card_partida_partida_101')),
            matching: find.text('Flamengo'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('card_partida_partida_101')),
            matching: find.text('Vasco'),
          ),
          findsOneWidget,
        );

        // 3. Destaque: alerta no topo de desafios recebidos aguardando resposta
        expect(
          find.byKey(const Key('home_alerta_desafios_pendentes')),
          findsOneWidget,
        );
        expect(find.textContaining('desafio aguardando você'), findsOneWidget);

        // Rola para a seção de desafios
        await tester.scrollUntilVisible(
          find.byKey(const Key('home_desafios_recebidos_pendentes')),
          200,
        );

        // 4. Seção destacada de Desafios Recebidos
        expect(
          find.byKey(const Key('home_desafios_recebidos_pendentes')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('badge_desafios_pendentes')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('card_desafio_pendente_chl_pendente_1')),
          findsOneWidget,
        );
        expect(find.text('Pedro te desafiou'), findsOneWidget);
        expect(find.text('Flamengo x Vasco'), findsOneWidget);
        expect(
          find.byKey(const Key('desafio_pendente_info_chl_pendente_1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('btn_responder_desafio_chl_pendente_1')),
          findsOneWidget,
        );

        // 5. Seção de Desafios em Aberto
        await tester.scrollUntilVisible(
          find.byKey(const Key('card_desafio_aberto_chl_aberto_2')),
          200,
        );
        expect(
          find.byKey(const Key('home_desafios_em_aberto')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('card_desafio_aberto_chl_aberto_2')),
          findsOneWidget,
        );
        expect(find.text('Você x Lucas'), findsOneWidget);
        expect(find.textContaining('Palmeiras x'), findsOneWidget);

        // 6. Destaque de Desafios Recentemente Finalizados
        await tester.scrollUntilVisible(
          find.byKey(const Key('card_desafio_finalizado_chl_finalizado_3')),
          200,
        );
        expect(
          find.byKey(const Key('home_desafios_finalizados')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('badge_desafios_finalizados')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('card_desafio_finalizado_chl_finalizado_3')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('resultado_desafio_chl_finalizado_3')),
          findsOneWidget,
        );
        expect(find.text('+80'), findsOneWidget);

        await encerrar(tester);
      },
    );

    testWidgets(
      'Home sem desafios pendentes não exibe destaque de pendentes mas exibe abertos',
      (tester) async {
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
        expect(
          find.byKey(const Key('home_alerta_desafios_pendentes')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('home_desafios_recebidos_pendentes')),
          findsNothing,
        );
        expect(find.byKey(const Key('badge_desafios_pendentes')), findsNothing);

        // Desafios em aberto continuam visíveis normalmente
        await tester.scrollUntilVisible(
          find.byKey(const Key('home_desafios_em_aberto')),
          200,
        );
        expect(
          find.byKey(const Key('home_desafios_em_aberto')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('card_desafio_aberto_chl_aberto_2')),
          findsOneWidget,
        );

        await encerrar(tester);
      },
    );

    testWidgets(
      'Home sem partidas próximas exibe container amigável sem quebrar o layout',
      (tester) async {
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
        expect(
          find.text('Não encontramos partidas disponíveis no momento.'),
          findsOneWidget,
        );
        expect(find.text('Atualizar'), findsOneWidget);

        // Saldo de BetCoins continua operando
        expect(
          tester.widget<Text>(find.byKey(const Key('home_saldo'))).data,
          '500',
        );

        // Desafios continuam operando
        await tester.scrollUntilVisible(
          find.byKey(const Key('card_desafio_aberto_chl_aberto_2')),
          200,
        );
        expect(
          find.byKey(const Key('card_desafio_aberto_chl_aberto_2')),
          findsOneWidget,
        );

        await encerrar(tester);
      },
    );

    testWidgets(
      'validar ausência de funcionalidades fora do escopo (sem ranking, sem feed, sem notificações)',
      (tester) async {
        await renderizarHome(tester, partidas: partidasExemplo);

        // 1. Sem ranking (D-002, RN-RNK-001)
        expect(find.text('Ranking'), findsNothing);
        expect(find.text('Leaderboard'), findsNothing);
        expect(find.text('Classificação'), findsNothing);

        final barraNavegacao = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(barraNavegacao.items.map((i) => i.label), [
          'Home',
          'Desafiar',
          'Perfil',
        ]);

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
      },
    );

    testWidgets(
      'Home sem nenhum desafio exibe estado vazio amigável com botão de criar desafio',
      (tester) async {
        await renderizarHome(tester, partidas: partidasExemplo);

        // Lista vazia de desafios
        challengeService.emitirDesafios([]);

        await tester.pump();
        await tester.pump();

        await tester.scrollUntilVisible(
          find.byKey(const Key('home_desafios_vazio')),
          200,
        );
        expect(find.byKey(const Key('home_desafios_vazio')), findsOneWidget);
        expect(find.text('Nenhum desafio no momento'), findsOneWidget);
        expect(find.byKey(const Key('btn_home_criar_desafio')), findsOneWidget);

        await encerrar(tester);
      },
    );

    testWidgets(
      'Desafio enviado pendente aparece em DESAFIOS ENVIADOS e o criador cancela só depois de confirmar',
      (tester) async {
        await renderizarHome(tester, partidas: partidasExemplo);

        challengeService.emitirDesafios([desafioEnviadoPendente]);
        await tester.pump();
        await tester.pump();

        final botaoCancelar = find.byKey(
          const Key('btn_cancelar_desafio_chl_enviado_4'),
        );
        await tester.scrollUntilVisible(botaoCancelar, 200);
        expect(
          find.byKey(const Key('home_desafios_enviados_pendentes')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('home_desafios_recebidos_pendentes')),
          findsNothing,
        );

        // Manter: nada é cancelado
        await tester.tap(botaoCancelar);
        await tester.pumpAndSettle();
        expect(find.text('Cancelar desafio?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_manter_desafio')));
        await tester.pumpAndSettle();
        expect(challengeService.cancelados, isEmpty);

        // Confirmar: cancela o desafio certo e avisa
        await tester.tap(botaoCancelar);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento')));
        await tester.pumpAndSettle();
        expect(challengeService.cancelados, ['chl_enviado_4']);
        expect(
          find.text('Desafio cancelado. Suas BetCoins foram liberadas.'),
          findsOneWidget,
        );

        await encerrar(tester);
      },
    );

    testWidgets('Falha ao cancelar mostra a mensagem do servidor', (
      tester,
    ) async {
      challengeService.erroAoCancelar = const ChallengeException(
        ChallengeErrorCode.notPending,
        'Este desafio não está mais pendente.',
      );
      await renderizarHome(tester, partidas: partidasExemplo);

      challengeService.emitirDesafios([desafioEnviadoPendente]);
      await tester.pump();
      await tester.pump();

      final botaoCancelar = find.byKey(
        const Key('btn_cancelar_desafio_chl_enviado_4'),
      );
      await tester.scrollUntilVisible(botaoCancelar, 200);
      await tester.tap(botaoCancelar);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento')));
      await tester.pumpAndSettle();

      expect(find.text('Este desafio não está mais pendente.'), findsOneWidget);
      expect(
        find.text('Desafio cancelado. Suas BetCoins foram liberadas.'),
        findsNothing,
      );

      await encerrar(tester);
    });

    testWidgets(
      'Desafio recebido pendente não gera botão de cancelar: só o criador cancela',
      (tester) async {
        await renderizarHome(tester, partidas: partidasExemplo);

        challengeService.emitirDesafios([desafioPendenteRecebido]);
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(const Key('home_desafios_recebidos_pendentes')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('home_desafios_enviados_pendentes')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('btn_cancelar_desafio_chl_pendente_1')),
          findsNothing,
        );

        await encerrar(tester);
      },
    );

    testWidgets(
      'Desafio cancelado pela partida mostra o motivo entre os finalizados',
      (tester) async {
        await renderizarHome(tester, partidas: partidasExemplo);

        challengeService.emitirDesafios([desafioCanceladoPelaPartida]);
        await tester.pump();
        await tester.pump();

        await tester.scrollUntilVisible(
          find.byKey(const Key('card_desafio_finalizado_chl_cancelado_5')),
          200,
        );
        expect(find.text('Partida cancelada'), findsOneWidget);

        await encerrar(tester);
      },
    );

    testWidgets(
      'Desafio finalizado sem vencedor informa que as apostas foram devolvidas e o resultado oficial',
      (tester) async {
        await renderizarHome(tester, partidas: partidasExemplo);

        challengeService.emitirDesafios([
          ChallengeModel(
            id: 'chl_empate_6',
            challengerId: 'w1R2a',
            challengedId: currentUserId,
            participants: ['w1R2a', currentUserId],
            matchId: 'partida_103',
            challengerPrediction: Palpite.homeWin,
            challengedPrediction: Palpite.awayWin,
            settledResult: Palpite.draw,
            amount: 50,
            status: StatusDesafio.finished,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ]);
        await tester.pump();
        await tester.pump();

        await tester.scrollUntilVisible(
          find.byKey(const Key('card_desafio_finalizado_chl_empate_6')),
          200,
        );
        expect(find.text('Ninguém acertou'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('btn_detalhes_desafio_finalizado_chl_empate_6')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Resultado oficial: Empate'), findsOneWidget);
        expect(
          find.text('BetCoins: Apostas devolvidas, saldo inalterado'),
          findsOneWidget,
        );

        await encerrar(tester);
      },
    );
  });
}
