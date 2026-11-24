import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:betfriends/data/firestore/challenge_repository.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/tela_criar_desafio/modal_aceitar_desafio.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/widgets_home_page/escudo_do_time.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/models/carteira.dart';

class FakePartidasProvider extends ChangeNotifier implements PartidasProvider {
  final List<PartidaModel> _partidas;

  FakePartidasProvider(this._partidas);

  @override
  List<PartidaModel> get partidas => _partidas;

  @override
  List<PartidaModel> get partidasDaHome => _partidas;

  @override
  bool get isLoading => false;

  @override
  bool get isAutoRefreshing => false;

  @override
  String? get errorMessage => null;

  @override
  String? get refreshErrorMessage => null;

  @override
  bool get hasRefreshError => false;

  @override
  DateTime? get ultimaAtualizacao => null;

  @override
  String? get ultimaAtualizacaoFormatada => null;

  @override
  bool get deveAtualizar => false;

  @override
  bool get isRateLimited => false;

  @override
  void limparErroRefresh() {}

  @override
  Future<void> carregarPartidas({
    bool silencioso = false,
    bool forcar = false,
  }) async {}
}

ChallengeModel _desafioPendente() => ChallengeModel(
  id: 'chl_pendente_99',
  challengerId: 'uid_alice',
  challengedId: 'uid_bob',
  participants: const ['uid_alice', 'uid_bob'],
  matchId: 'match_flamengo_palmeiras',
  challengerPrediction: Palpite.homeWin,
  amount: 50,
  status: StatusDesafio.pending,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

class FakeChallengeService implements ChallengeService {
  CriarDesafioResponse? createResult;
  AceitarDesafioResponse? acceptResult;
  Completer<void>? bloqueioAceite;

  String? lastChallengedId;
  String? lastMatchId;
  Palpite? lastChallengerPrediction;
  int? lastAmount;

  String? lastAcceptedChallengeId;
  Palpite? lastAcceptedPrediction;

  @override
  Future<CriarDesafioResponse> criarDesafio({
    required String challengedId,
    required String matchId,
    required Palpite challengerPrediction,
    required int amount,
  }) async {
    lastChallengedId = challengedId;
    lastMatchId = matchId;
    lastChallengerPrediction = challengerPrediction;
    lastAmount = amount;

    return createResult ??
        CriarDesafioResponse(
          challengeId: 'chl_created_123',
          status: StatusDesafio.pending,
          challengerId: 'uid_current',
          challengedId: challengedId,
          matchId: matchId,
          challengerPrediction: challengerPrediction,
          amount: amount,
        );
  }

  @override
  Future<AceitarDesafioResponse> aceitarDesafio({
    required String challengeId,
    required Palpite challengedPrediction,
  }) async {
    await bloqueioAceite?.future;
    lastAcceptedChallengeId = challengeId;
    lastAcceptedPrediction = challengedPrediction;

    return acceptResult ??
        AceitarDesafioResponse(
          challengeId: challengeId,
          status: StatusDesafio.accepted,
          challengerId: 'uid_alice',
          challengedId: 'uid_bob',
          matchId: 'match_1',
          challengerPrediction: Palpite.homeWin,
          challengedPrediction: challengedPrediction,
          amount: 50,
          acceptedAt: DateTime.now(),
        );
  }

  String? lastRejectedChallengeId;
  String? lastCancelledChallengeId;
  ChallengeException? rejectError;

  @override
  Future<EncerrarDesafioResponse> recusarDesafio({
    required String challengeId,
  }) async {
    if (rejectError != null) throw rejectError!;
    lastRejectedChallengeId = challengeId;
    return EncerrarDesafioResponse(
      challengeId: challengeId,
      status: StatusDesafio.rejected,
    );
  }

  @override
  Future<EncerrarDesafioResponse> cancelarDesafio({
    required String challengeId,
  }) async {
    lastCancelledChallengeId = challengeId;
    return EncerrarDesafioResponse(
      challengeId: challengeId,
      status: StatusDesafio.cancelled,
    );
  }

  @override
  Future<List<ChallengeModel>> listarDesafios() async => [];

  @override
  Stream<List<ChallengeModel>> observarDesafios() => const Stream.empty();

  @override
  Future<int?> buscarSaldoDisponivel() async => 500;

  @override
  Future<List<AmigoItem>> listarAmigosAceitos() async => [];
}

class FakeCarteiraService extends Fake implements UserProfileService {
  FakeCarteiraService(this.stream);
  final Stream<Carteira?> stream;
  @override
  Stream<Carteira?> observarCarteiraAtual() => stream;
}

void main() {
  final List<PartidaModel> partidasFake = [
    PartidaModel(
      id: 'match_flamengo_palmeiras',
      timeMandante: 'Flamengo',
      timeVisitante: 'Palmeiras',
      status: 'AGENDADA',
      horario: '20:00',
      startsAtUtc: DateTime.now().add(const Duration(hours: 3)),
      campeonato: 'Brasileirão',
    ),
  ];

  Widget montarAppComNavegacao({
    required Widget child,
    required PartidasProvider provider,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const Key('btn_abrir_tela'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ChangeNotifierProvider<PartidasProvider>.value(
                        value: provider,
                        child: child,
                      ),
                ),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
  }

  group('CriarDesafioScreen UI e Interação', () {
    testWidgets(
      'N-17: seleção indisponível é limpa sem escolher outra partida',
      (tester) async {
        final partidas = [
          ...partidasFake,
          PartidaModel(
            id: 'm9d7',
            timeMandante: 'Time C',
            timeVisitante: 'Time D',
            startsAtUtc: DateTime.now().toUtc().add(const Duration(hours: 4)),
          ),
        ];
        final provider = FakePartidasProvider(partidas);
        final service = FakeChallengeService();
        await tester.pumpWidget(
          montarAppComNavegacao(
            provider: provider,
            child: CriarDesafioScreen(
              preSelectedMatchId: partidas.first.id,
              preSelectedFriendId: 'p8r6',
              preSelectedFriendName: 'Bia Rocha',
              challengeService: service,
              saldoInicial: 500,
              amigosIniciais: const [],
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('btn_abrir_tela')));
        await tester.pumpAndSettle();
        partidas.removeAt(0);
        provider.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          find.text(
            'A partida selecionada não está mais disponível. Escolha outra partida.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('partida_desafio_m9d7')), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_enviar_desafio')));
        await tester.pumpAndSettle();
        expect(
          find.text('Selecione uma partida válida para criar o desafio.'),
          findsOneWidget,
        );
        expect(service.lastMatchId, isNull);
      },
    );

    testWidgets(
      'falha da carteira não bloqueia a carga independente de amigos',
      (tester) async {
        await tester.pumpWidget(
          montarAppComNavegacao(
            provider: FakePartidasProvider(partidasFake),
            child: CriarDesafioScreen(
              challengeService: FakeChallengeService(),
              userProfileService: FakeCarteiraService(
                Stream.error(StateError('offline')),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('btn_abrir_tela')));
        await tester.pumpAndSettle();
        expect(find.text('Não foi possível carregar o saldo.'), findsOneWidget);
        expect(find.text('Recarregar saldo'), findsOneWidget);
        expect(find.text('Carregando...'), findsNothing);
      },
    );

    testWidgets('renderiza elementos principais e palpite do criador', (
      tester,
    ) async {
      final fakeProvider = FakePartidasProvider(partidasFake);
      final fakeService = FakeChallengeService();

      await tester.pumpWidget(
        montarAppComNavegacao(
          provider: fakeProvider,
          child: CriarDesafioScreen(
            preSelectedFriendId: 'uid_amigo_1',
            preSelectedFriendName: 'Carlos Silva',
            challengeService: fakeService,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('btn_abrir_tela')));
      await tester.pumpAndSettle();

      expect(find.byType(CriarDesafioScreen), findsOneWidget);

      // Partida renderizada
      expect(find.text('Flamengo'), findsOneWidget);
      expect(find.text('Palmeiras'), findsOneWidget);

      // Palpites renderizados
      expect(find.byKey(const Key('palpite_home_win')), findsOneWidget);
      expect(find.byKey(const Key('palpite_draw')), findsOneWidget);
      expect(find.byKey(const Key('palpite_away_win')), findsOneWidget);

      // Faz scroll para visualizar o amigo selecionado no fim da lista
      await tester.scrollUntilVisible(
        find.text('Carlos Silva'),
        100,
        // A faixa de filtros por campeonato também rola (na horizontal).
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Carlos Silva'), findsOneWidget);
    });

    testWidgets('seleciona palpite e altera valor de aposta', (tester) async {
      // Tela alta o bastante para a lista (com a faixa de filtros) caber inteira.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fakeProvider = FakePartidasProvider(partidasFake);
      final fakeService = FakeChallengeService();

      await tester.pumpWidget(
        montarAppComNavegacao(
          provider: fakeProvider,
          child: CriarDesafioScreen(
            preSelectedFriendId: 'uid_amigo_1',
            preSelectedFriendName: 'Carlos Silva',
            challengeService: fakeService,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('btn_abrir_tela')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('partida_desafio_match_flamengo_palmeiras')),
      );
      await tester.pumpAndSettle();

      // Altera valor clicando no chip de 100
      await tester.tap(find.byKey(const Key('chip_valor_100')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Prêmio se acertar +100'), findsOneWidget);

      // Altera palpite para Empate
      await tester.tap(find.byKey(const Key('palpite_draw')));
      await tester.pumpAndSettle();

      // Envia desafio
      await tester.tap(find.byKey(const Key('btn_enviar_desafio')));
      await tester.pumpAndSettle();

      expect(fakeService.lastChallengedId, 'uid_amigo_1');
      expect(fakeService.lastMatchId, 'match_flamengo_palmeiras');
      expect(fakeService.lastChallengerPrediction, Palpite.draw);
      expect(fakeService.lastAmount, 100);
    });

    List<PartidaModel> oitoPartidas() => [
      for (var i = 1; i <= 8; i++)
        PartidaModel(
          id: 'jogo_$i',
          timeMandante: 'Casa $i',
          timeVisitante: 'Fora $i',
          status: 'AGENDADA',
          horario: '20:00',
          startsAtUtc: DateTime.now().add(Duration(hours: 3 + i)),
          logoMandante: 'https://crests.football-data.org/$i.png',
        ),
    ];

    testWidgets(
      'lista só as 5 primeiras partidas com escudos, e "Mostrar mais" revela as demais',
      (tester) async {
        // Tela alta o bastante para todas as partidas ficarem na área visível.
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          montarAppComNavegacao(
            provider: FakePartidasProvider(oitoPartidas()),
            child: CriarDesafioScreen(
              challengeService: FakeChallengeService(),
              saldoInicial: 500,
              amigosIniciais: const [],
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('btn_abrir_tela')));
        await tester.pumpAndSettle();

        for (var i = 1; i <= 5; i++) {
          expect(
            find.byKey(Key('partida_desafio_jogo_$i')),
            findsOneWidget,
            reason: 'jogo $i',
          );
        }
        for (var i = 6; i <= 8; i++) {
          expect(
            find.byKey(Key('partida_desafio_jogo_$i')),
            findsNothing,
            reason: 'jogo $i',
          );
        }
        // Um escudo por time: 5 partidas x 2 times.
        expect(find.byType(EscudoDoTime), findsNWidgets(10));

        // "Mostrar mais" revela as demais; "Mostrar menos" volta às 5 primeiras.
        final botao = find.byKey(const Key('btn_mostrar_mais_partidas'));
        expect(find.text('Mostrar mais (3)'), findsOneWidget);
        await tester.ensureVisible(botao);
        await tester.tap(botao);
        await tester.pumpAndSettle();
        for (var i = 1; i <= 8; i++) {
          expect(
            find.byKey(Key('partida_desafio_jogo_$i')),
            findsOneWidget,
            reason: 'jogo $i',
          );
        }
        expect(find.text('Mostrar menos'), findsOneWidget);

        await tester.ensureVisible(botao);
        await tester.tap(botao);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('partida_desafio_jogo_6')), findsNothing);
        expect(find.text('Mostrar mais (3)'), findsOneWidget);
      },
    );

    testWidgets(
      'partida pré-selecionada fora das 5 primeiras continua visível e selecionável',
      (tester) async {
        final service = FakeChallengeService();
        await tester.pumpWidget(
          montarAppComNavegacao(
            provider: FakePartidasProvider(oitoPartidas()),
            child: CriarDesafioScreen(
              preSelectedMatchId: 'jogo_7',
              preSelectedFriendId: 'p8r6',
              preSelectedFriendName: 'Bia Rocha',
              challengeService: service,
              saldoInicial: 500,
              amigosIniciais: const [],
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('btn_abrir_tela')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('partida_desafio_jogo_7')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_jogo_6')), findsNothing);
        expect(
          find.text(
            'A partida selecionada não está mais disponível. Escolha outra partida.',
          ),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('btn_enviar_desafio')));
        await tester.pumpAndSettle();
        expect(service.lastMatchId, 'jogo_7');
      },
    );
  });

  group('CriarDesafioScreen - campeonatos', () {
    // As quatro ligas já entre as 5 primeiras; BSA tem 7 para exercitar o limite.
    List<PartidaModel> partidasDasLigas() {
      var hora = 1;
      PartidaModel p(String id, String codigo) => PartidaModel(
        id: id,
        timeMandante: 'Casa $id',
        timeVisitante: 'Fora $id',
        status: 'AGENDADA',
        horario: '20:00',
        startsAtUtc: DateTime.now().add(Duration(hours: 3 + hora++)),
        competitionCode: codigo,
      );
      return [
        p('bsa_1', 'BSA'),
        p('pl_1', 'PL'),
        p('sa_1', 'SA'),
        p('pd_1', 'PD'),
        p('pl_2', 'PL'),
        for (var i = 2; i <= 7; i++) p('bsa_$i', 'BSA'),
      ];
    }

    Future<FakeChallengeService> abrir(
      WidgetTester tester,
      List<PartidaModel> partidas, {
      String? preSelecionada,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = FakeChallengeService();
      await tester.pumpWidget(
        montarAppComNavegacao(
          provider: FakePartidasProvider(partidas),
          child: CriarDesafioScreen(
            preSelectedMatchId: preSelecionada,
            preSelectedFriendId: 'p8r6',
            preSelectedFriendName: 'Bia Rocha',
            challengeService: service,
            saldoInicial: 500,
            amigosIniciais: const [],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('btn_abrir_tela')));
      await tester.pumpAndSettle();
      return service;
    }

    Future<void> filtrar(WidgetTester tester, String chave) async {
      final chip = find.byKey(Key('filtro_campeonato_$chave'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    String? rotulo(WidgetTester tester, String id) => tester
        .widget<Text>(find.byKey(Key('partida_desafio_campeonato_$id')))
        .data;

    testWidgets('lista partidas das 4 ligas, cada uma com o nome da liga', (
      tester,
    ) async {
      await abrir(tester, partidasDasLigas());
      await tester.tap(find.byKey(const Key('btn_mostrar_mais_partidas')));
      await tester.pumpAndSettle();

      expect(rotulo(tester, 'bsa_1'), 'Brasileirão Série A');
      expect(rotulo(tester, 'pl_1'), 'Premier League');
      expect(rotulo(tester, 'sa_1'), 'Serie A');
      expect(rotulo(tester, 'pd_1'), 'La Liga');
    });

    testWidgets(
      'mostra os 5 chips, com "Todos" selecionado por padrão e alvo de toque de 48 dp',
      (tester) async {
        await abrir(tester, partidasDasLigas());
        for (final chave in ['todos', 'BSA', 'PL', 'SA', 'PD']) {
          final chip = find.byKey(Key('filtro_campeonato_$chave'));
          expect(chip, findsOneWidget, reason: chave);
          expect(
            tester.getSize(chip).height,
            greaterThanOrEqualTo(48),
            reason: chave,
          );
        }
        expect(find.text('Todos'), findsOneWidget);
        expect(find.text('Brasileirão'), findsOneWidget);
        // Sem filtro: as 5 primeiras de todas as ligas e o contador de ocultas.
        expect(find.byKey(const Key('partida_desafio_pd_1')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_bsa_2')), findsNothing);
        expect(find.text('Mostrar mais (6)'), findsOneWidget);
      },
    );

    testWidgets(
      'filtro mostra só a liga escolhida e "Todos" volta a mostrar tudo',
      (tester) async {
        await abrir(tester, partidasDasLigas());
        await filtrar(tester, 'PL');
        expect(find.byKey(const Key('partida_desafio_pl_1')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_pl_2')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_bsa_1')), findsNothing);
        expect(find.byKey(const Key('partida_desafio_sa_1')), findsNothing);
        expect(
          find.byKey(const Key('btn_mostrar_mais_partidas')),
          findsNothing,
        );

        await filtrar(tester, 'PD');
        expect(find.byKey(const Key('partida_desafio_pd_1')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_pl_1')), findsNothing);

        await filtrar(tester, 'todos');
        expect(find.byKey(const Key('partida_desafio_bsa_1')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_pl_1')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_sa_1')), findsOneWidget);
      },
    );

    testWidgets(
      '"Mostrar mais" conta dentro do filtro e trocar de filtro recolhe a lista',
      (tester) async {
        await abrir(tester, partidasDasLigas());
        await filtrar(tester, 'BSA');
        expect(find.byKey(const Key('partida_desafio_bsa_5')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_bsa_6')), findsNothing);
        expect(find.text('Mostrar mais (2)'), findsOneWidget);

        final botao = find.byKey(const Key('btn_mostrar_mais_partidas'));
        await tester.ensureVisible(botao);
        await tester.tap(botao);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('partida_desafio_bsa_7')), findsOneWidget);
        expect(find.text('Mostrar menos'), findsOneWidget);

        // Trocar de filtro (e voltar) recolhe: o limite de 5 vale de novo.
        await filtrar(tester, 'PL');
        expect(find.text('Mostrar menos'), findsNothing);
        await filtrar(tester, 'BSA');
        expect(find.byKey(const Key('partida_desafio_bsa_7')), findsNothing);
        expect(find.text('Mostrar mais (2)'), findsOneWidget);
      },
    );

    testWidgets(
      'partida pré-selecionada de outra liga continua visível e é enviada com o filtro ativo',
      (tester) async {
        final service = await abrir(
          tester,
          partidasDasLigas(),
          preSelecionada: 'pd_1',
        );
        await filtrar(tester, 'PL');

        expect(find.byKey(const Key('partida_desafio_pl_1')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_pd_1')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_bsa_1')), findsNothing);
        expect(
          find.text(
            'A partida selecionada não está mais disponível. Escolha outra partida.',
          ),
          findsNothing,
        );

        await tester.ensureVisible(find.byKey(const Key('btn_enviar_desafio')));
        await tester.tap(find.byKey(const Key('btn_enviar_desafio')));
        await tester.pumpAndSettle();
        expect(service.lastMatchId, 'pd_1');
      },
    );

    testWidgets(
      'liga sem partidas mostra a mensagem e os chips continuam utilizáveis',
      (tester) async {
        final semSerieA = partidasDasLigas()
            .where((p) => p.competitionCode != 'SA')
            .toList();
        await abrir(tester, semSerieA);
        await filtrar(tester, 'SA');

        expect(
          find.text(
            'Nenhuma partida agendada disponível em Serie A no momento.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('filtro_campeonato_SA')), findsOneWidget);
        expect(find.byKey(const Key('partida_desafio_pl_1')), findsNothing);

        await filtrar(tester, 'PL');
        expect(find.byKey(const Key('filtro_campeonato_vazio')), findsNothing);
        expect(find.byKey(const Key('partida_desafio_pl_1')), findsOneWidget);
      },
    );

    testWidgets('selecionar uma partida da PL e enviar usa o matchId dela', (
      tester,
    ) async {
      final service = await abrir(tester, partidasDasLigas());
      await filtrar(tester, 'PL');
      await tester.tap(find.byKey(const Key('partida_desafio_pl_2')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('btn_enviar_desafio')));
      await tester.tap(find.byKey(const Key('btn_enviar_desafio')));
      await tester.pumpAndSettle();
      expect(service.lastMatchId, 'pl_2');
    });

    testWidgets(
      'partida antiga (só BSA, sem código) aparece, entra no filtro do Brasileirão e é enviada',
      (tester) async {
        final antiga = PartidaModel.fromFirestoreMap({
          'homeTeam': 'Santos',
          'awayTeam': 'Bahia',
          'status': 'SCHEDULED',
          'startsAtUtc': DateTime.now()
              .toUtc()
              .add(const Duration(days: 2))
              .toIso8601String(),
        }, 'antiga_1');
        final service = await abrir(tester, [antiga]);

        expect(rotulo(tester, 'antiga_1'), 'Brasileirão Série A');
        await filtrar(tester, 'BSA');
        expect(
          find.byKey(const Key('partida_desafio_antiga_1')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('partida_desafio_antiga_1')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('btn_enviar_desafio')));
        await tester.tap(find.byKey(const Key('btn_enviar_desafio')));
        await tester.pumpAndSettle();
        expect(service.lastMatchId, 'antiga_1');
      },
    );
  });

  group('ModalAceitarDesafio UI e Interação', () {
    testWidgets('N-18: modal impede fechamento durante o aceite', (
      tester,
    ) async {
      final service = FakeChallengeService()
        ..bloqueioAceite = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ModalAceitarDesafio.exibir(
                  context: context,
                  desafio: _desafioPendente(),
                  challengeService: service,
                ),
                child: const Text('Abrir aceite'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir aceite'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_confirmar_aceite')));
      await tester.pump();
      final fechar = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.close),
      );
      expect(fechar.onPressed, isNull);
      final scope = tester.widget<PopScope>(find.byType(PopScope));
      expect(scope.canPop, isFalse);
      final contexto = tester.element(find.byType(ModalAceitarDesafio));
      await Navigator.of(contexto).maybePop();
      await tester.pump();
      expect(find.byType(ModalAceitarDesafio), findsOneWidget);
      service.bloqueioAceite!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ModalAceitarDesafio), findsNothing);
    });

    testWidgets(
      'exibe informações e restringe palpite diferente do criador (RN-PRD-003)',
      (tester) async {
        final fakeService = FakeChallengeService();
        final desafio = ChallengeModel(
          id: 'chl_pendente_99',
          challengerId: 'uid_alice',
          challengedId: 'uid_bob',
          participants: const ['uid_alice', 'uid_bob'],
          matchId: 'match_flamengo_palmeiras',
          challengerPrediction: Palpite.homeWin, // Criador escolheu HOME_WIN
          amount: 50,
          status: StatusDesafio.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModalAceitarDesafio(
                desafio: desafio,
                nomeCriador: 'Alice Silva',
                descricaoPartida: 'Flamengo x Palmeiras',
                challengeService: fakeService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ModalAceitarDesafio), findsOneWidget);
        expect(find.text('Alice Silva'), findsOneWidget);
        expect(find.text('50 BetCoins'), findsOneWidget);
        expect(
          find.byKey(const Key('modal_aceitar_palpite_criador')),
          findsOneWidget,
        );

        // O palpite HOME_WIN (Vitória Mandante) NÃO deve estar disponível para escolha
        expect(find.text('Vitória Visitante'), findsOneWidget);
        expect(find.text('Empate'), findsOneWidget);

        // Toca em 'CONFIRMAR E ACEITAR'
        await tester.tap(find.byKey(const Key('btn_confirmar_aceite')));
        await tester.pumpAndSettle();

        expect(fakeService.lastAcceptedChallengeId, 'chl_pendente_99');
        // O palpite padrão inicial disponível deve ser um dos permitidos
        expect(fakeService.lastAcceptedPrediction, isNot(Palpite.homeWin));
      },
    );

    testWidgets(
      'RECUSAR DESAFIO chama a recusa para o desafio e fecha o modal com sucesso',
      (tester) async {
        final fakeService = FakeChallengeService();
        bool? resultado;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('btn_abrir_modal'),
                  onPressed: () async {
                    resultado = await ModalAceitarDesafio.exibir(
                      context: context,
                      desafio: _desafioPendente(),
                      challengeService: fakeService,
                    );
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('btn_abrir_modal')));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('btn_recusar_desafio')),
        );
        await tester.tap(find.byKey(const Key('btn_recusar_desafio')));
        await tester.pumpAndSettle();

        expect(fakeService.lastRejectedChallengeId, 'chl_pendente_99');
        expect(
          fakeService.lastAcceptedChallengeId,
          isNull,
          reason: 'recusar não aceita',
        );
        expect(resultado, isTrue);
        expect(
          find.byType(ModalAceitarDesafio),
          findsNothing,
          reason: 'o modal fecha',
        );
      },
    );

    testWidgets(
      'falha ao recusar mostra a mensagem do servidor e mantém o modal aberto',
      (tester) async {
        final fakeService = FakeChallengeService()
          ..rejectError = const ChallengeException(
            ChallengeErrorCode.notPending,
            'Este desafio não está mais pendente.',
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModalAceitarDesafio(
                desafio: _desafioPendente(),
                challengeService: fakeService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('btn_recusar_desafio')),
        );
        await tester.tap(find.byKey(const Key('btn_recusar_desafio')));
        await tester.pumpAndSettle();

        expect(
          find.text('Este desafio não está mais pendente.'),
          findsOneWidget,
        );
        expect(
          find.byType(ModalAceitarDesafio),
          findsOneWidget,
          reason: 'o modal continua aberto',
        );
        // botão volta a ficar disponível para nova tentativa
        await tester.tap(find.byKey(const Key('btn_recusar_desafio')));
        await tester.pumpAndSettle();
        expect(
          find.text('Este desafio não está mais pendente.'),
          findsOneWidget,
        );
      },
    );
  });
}
