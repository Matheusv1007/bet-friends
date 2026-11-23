import 'package:betfriends/data/firestore/challenge_repository.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/widgets_home_page/card_de_desafios_ativos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

class _TestPartidasService extends PartidasService {
  final List<PartidaModel> partidas;
  _TestPartidasService(this.partidas);
  @override
  Future<List<PartidaModel>> getPartidas() async => partidas;
}

class _FakeChallengeRepository implements ChallengeRepository {
  String? lastCancelledId;
  ChallengeException? erro;

  @override
  Future<EncerrarDesafioResponse> cancelarDesafio(String challengeId) async {
    if (erro != null) throw erro!;
    lastCancelledId = challengeId;
    return const EncerrarDesafioResponse(
      challengeId: 'chl_enviado_1',
      status: StatusDesafio.cancelled,
    );
  }

  @override
  Future<EncerrarDesafioResponse> recusarDesafio(String challengeId) async =>
      throw UnimplementedError();

  @override
  Future<AceitarDesafioResponse> aceitarDesafio(AceitarDesafioRequest request) async =>
      throw UnimplementedError();

  @override
  Future<CriarDesafioResponse> criarDesafio(CriarDesafioRequest request) async =>
      throw UnimplementedError();

  @override
  Future<List<ChallengeModel>> listarDesafiosDoUsuario(String uid) async => [];

  @override
  Stream<List<ChallengeModel>> observarDesafiosDoUsuario(String uid) => const Stream.empty();

  @override
  Future<int?> buscarSaldoDisponivel(String uid) async => 1000;

  @override
  Future<List<AmigoItem>> listarAmigosAceitos(String uid) async => [];
}

void main() {
  const currentUid = 'uid_criador';
  late FakeAuthService authService;
  late _FakeChallengeRepository repo;
  late ChallengeService challengeService;
  late PartidasProvider partidasProvider;

  final agora = DateTime.now();
  final desafioEnviado = ChallengeModel(
    id: 'chl_enviado_1',
    challengerId: currentUid,
    challengedId: 'uid_amigo_1',
    participants: const [currentUid, 'uid_amigo_1'],
    matchId: 'match_123',
    amount: 50,
    challengerPrediction: Palpite.homeWin,
    status: StatusDesafio.pending,
    createdAt: agora,
    updatedAt: agora,
  );

  setUp(() async {
    authService = FakeAuthService(usuarioInicial: FakeUser(currentUid));
    repo = _FakeChallengeRepository();
    challengeService = ChallengeService(
      authService: authService,
      repository: repo,
    );
    final service = _TestPartidasService([
      PartidaModel(
        id: 'match_123',
        timeMandante: 'Flamengo',
        timeVisitante: 'Palmeiras',
      ),
    ]);
    partidasProvider = PartidasProvider(partidasService: service);
    await partidasProvider.carregarPartidas();
  });

  Widget criarApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: partidasProvider),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('Cancelar Desafio Pendente (KAN-60, RF-013, RN-CHL-018, RN-CHL-020)', () {
    testWidgets('exibe card de enviados e cancelar fecha diálogo mantendo desafio', (tester) async {
      await tester.pumpWidget(criarApp(
        DesafiosAtivosWidget(
          desafios: [desafioEnviado],
          currentUserId: currentUid,
          challengeService: challengeService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_desafios_enviados_pendentes')), findsOneWidget);
      expect(find.text('CANCELAR'), findsOneWidget);

      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar desafio?'), findsOneWidget);
      expect(find.byKey(const Key('btn_manter_desafio')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_manter_desafio')));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar desafio?'), findsNothing);
      expect(repo.lastCancelledId, isNull);
    });

    testWidgets('confirmar cancelamento chama o backend e exibe snackbar de sucesso', (tester) async {
      await tester.pumpWidget(criarApp(
        DesafiosAtivosWidget(
          desafios: [desafioEnviado],
          currentUserId: currentUid,
          challengeService: challengeService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_confirmar_cancelamento')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento')));
      await tester.pumpAndSettle();

      expect(repo.lastCancelledId, 'chl_enviado_1');
      expect(
        find.text('Desafio cancelado. Suas BetCoins foram liberadas.'),
        findsOneWidget,
      );
    });

    testWidgets('erro ao cancelar exibe mensagem amigável no snackbar', (tester) async {
      repo.erro = const ChallengeException(
        ChallengeErrorCode.notPending,
        'O criador só pode cancelar um desafio pendente.',
      );

      await tester.pumpWidget(criarApp(
        DesafiosAtivosWidget(
          desafios: [desafioEnviado],
          currentUserId: currentUid,
          challengeService: challengeService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento')));
      await tester.pumpAndSettle();

      expect(
        find.text('O criador só pode cancelar um desafio pendente.'),
        findsOneWidget,
      );
    });
  });
}
