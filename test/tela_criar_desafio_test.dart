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

class FakePartidasProvider extends ChangeNotifier implements PartidasProvider {
  final List<PartidaModel> _partidas;

  FakePartidasProvider(this._partidas);

  @override
  List<PartidaModel> get partidas => _partidas;

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
  void limparErroRefresh() {}

  @override
  Future<void> carregarPartidas({int limit = 15, bool silencioso = false}) async {}
}

class FakeChallengeService implements ChallengeService {
  CriarDesafioResponse? createResult;
  AceitarDesafioResponse? acceptResult;

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

  @override
  Future<List<ChallengeModel>> listarDesafios() async => [];

  @override
  Stream<List<ChallengeModel>> observarDesafios() => const Stream.empty();

  @override
  Future<int?> buscarSaldoDisponivel() async => 500;

  @override
  Future<List<AmigoItem>> listarAmigosAceitos() async => [];
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
                  builder: (_) => ChangeNotifierProvider<PartidasProvider>.value(
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
    testWidgets('renderiza elementos principais e palpite do criador', (tester) async {
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

      expect(find.text('Criar Desafio'), findsOneWidget);
      expect(find.text('ESCOLHA A PARTIDA'), findsOneWidget);
      expect(find.text('SEU PALPITE NO JOGO'), findsOneWidget);
      expect(find.text('VALOR DO DESAFIO (BetCoins)'), findsOneWidget);
      expect(find.text('ENVIAR DESAFIO'), findsOneWidget);

      // Partida renderizada
      expect(find.text('Flamengo'), findsOneWidget);
      expect(find.text('Palmeiras'), findsOneWidget);

      // Palpites renderizados
      expect(find.byKey(const Key('palpite_home_win')), findsOneWidget);
      expect(find.byKey(const Key('palpite_draw')), findsOneWidget);
      expect(find.byKey(const Key('palpite_away_win')), findsOneWidget);

      // Faz scroll para visualizar o amigo selecionado no fim da lista
      await tester.scrollUntilVisible(find.text('Carlos Silva'), 100);
      expect(find.text('Carlos Silva'), findsOneWidget);
    });

    testWidgets('seleciona palpite e altera valor de aposta', (tester) async {
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

      // Altera valor clicando no chip de 100
      await tester.tap(find.byKey(const Key('chip_valor_100')));
      await tester.pumpAndSettle();

      expect(find.text('100 BetCoins'), findsOneWidget);

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
  });

  group('ModalAceitarDesafio UI e Interação', () {
    testWidgets('exibe informações e restringe palpite diferente do criador (RN-PRD-003)', (tester) async {
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

      expect(find.text('Aceitar Desafio'), findsOneWidget);
      expect(find.text('Desafiado por Alice Silva'), findsOneWidget);
      expect(find.text('Valor apostado: 50 BetCoins'), findsOneWidget);
      expect(find.text('Palpite do criador: Vitória Mandante'), findsOneWidget);

      // O palpite HOME_WIN (Vitória Mandante) NÃO deve estar disponível para escolha
      expect(find.text('Vitória Visitante'), findsOneWidget);
      expect(find.text('Empate'), findsOneWidget);

      // Toca em 'CONFIRMAR E ACEITAR'
      await tester.tap(find.text('CONFIRMAR E ACEITAR'));
      await tester.pumpAndSettle();

      expect(fakeService.lastAcceptedChallengeId, 'chl_pendente_99');
      // O palpite padrão inicial disponível deve ser um dos permitidos
      expect(fakeService.lastAcceptedPrediction, isNot(Palpite.homeWin));
    });
  });
}
