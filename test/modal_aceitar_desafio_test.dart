import 'package:betfriends/data/firestore/challenge_repository.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/tela_criar_desafio/modal_aceitar_desafio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

class _FakeChallengeRepository implements ChallengeRepository {
  String? lastRejectedId;
  String? lastAcceptedId;
  Palpite? lastAcceptedPrediction;
  ChallengeException? erro;

  @override
  Future<EncerrarDesafioResponse> recusarDesafio(String challengeId) async {
    if (erro != null) throw erro!;
    lastRejectedId = challengeId;
    return const EncerrarDesafioResponse(
      challengeId: 'chl_100',
      status: StatusDesafio.rejected,
    );
  }

  @override
  Future<AceitarDesafioResponse> aceitarDesafio(AceitarDesafioRequest request) async {
    if (erro != null) throw erro!;
    lastAcceptedId = request.challengeId;
    lastAcceptedPrediction = request.challengedPrediction;
    return AceitarDesafioResponse(
      challengeId: request.challengeId,
      status: StatusDesafio.accepted,
      challengerId: 'uid_criador',
      challengedId: 'uid_desafiado',
      matchId: 'match_123',
      challengerPrediction: Palpite.homeWin,
      challengedPrediction: request.challengedPrediction,
      amount: 50,
      acceptedAt: DateTime.now(),
    );
  }

  @override
  Future<EncerrarDesafioResponse> cancelarDesafio(String challengeId) async =>
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
  const currentUid = 'uid_desafiado';
  late FakeAuthService authService;
  late _FakeChallengeRepository repo;
  late ChallengeService challengeService;

  final agora = DateTime.now();
  final desafioExemplo = ChallengeModel(
    id: 'chl_100',
    challengerId: 'uid_criador',
    challengedId: currentUid,
    participants: const ['uid_criador', currentUid],
    matchId: 'match_123',
    amount: 50,
    challengerPrediction: Palpite.homeWin,
    status: StatusDesafio.pending,
    createdAt: agora,
    updatedAt: agora,
  );

  setUp(() {
    authService = FakeAuthService(usuarioInicial: FakeUser(currentUid));
    repo = _FakeChallengeRepository();
    challengeService = ChallengeService(
      authService: authService,
      repository: repo,
    );
  });

  Widget criarApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('btn_abrir_modal'),
            onPressed: () => ModalAceitarDesafio.exibir(
              context: context,
              desafio: desafioExemplo,
              nomeCriador: 'Pedro Simon',
              descricaoPartida: 'Flamengo x Palmeiras',
              challengeService: challengeService,
            ),
            child: const Text('Abrir Modal'),
          ),
        ),
      ),
    );
  }

  group('ModalAceitarDesafio (KAN-59, RF-012, RN-CHL-017, RN-PRD-003)', () {
    testWidgets('exibe informações do desafio e permite recusar', (tester) async {
      await tester.pumpWidget(criarApp(const SizedBox()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_abrir_modal')));
      await tester.pumpAndSettle();

      expect(find.text('Aceitar Desafio'), findsOneWidget);
      expect(find.text('Desafiado por Pedro Simon'), findsOneWidget);
      expect(find.text('Flamengo x Palmeiras'), findsOneWidget);
      expect(find.text('Valor apostado: 50 BetCoins'), findsOneWidget);
      expect(find.byKey(const Key('btn_recusar_desafio')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_recusar_desafio')));
      await tester.pumpAndSettle();

      expect(repo.lastRejectedId, 'chl_100');
      expect(find.text('Desafio recusado.'), findsOneWidget);
      expect(find.text('Aceitar Desafio'), findsNothing);
    });

    testWidgets('erro ao recusar desafio exibe snackbar de erro', (tester) async {
      repo.erro = const ChallengeException(
        ChallengeErrorCode.notChallengedUser,
        'Somente o usuário desafiado pode recusar o desafio.',
      );

      await tester.pumpWidget(criarApp(const SizedBox()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_abrir_modal')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_recusar_desafio')));
      await tester.pumpAndSettle();

      expect(find.text('Somente o usuário desafiado pode recusar o desafio.'), findsOneWidget);
    });

    testWidgets('aceitar desafio com palpite válido reserva BetCoins', (tester) async {
      await tester.pumpWidget(criarApp(const SizedBox()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_abrir_modal')));
      await tester.pumpAndSettle();

      // Clica em um palpite permitido (ex: Empate)
      await tester.tap(find.text('Empate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONFIRMAR E ACEITAR'));
      await tester.pumpAndSettle();

      expect(repo.lastAcceptedId, 'chl_100');
      expect(repo.lastAcceptedPrediction, Palpite.draw);
      expect(
        find.text('Desafio aceito com sucesso! Suas BetCoins foram reservadas.'),
        findsOneWidget,
      );
      expect(find.text('Desafio recebido!'), findsNothing);
    });
  });
}
