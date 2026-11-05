import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:betfriends/data/firestore/challenge_repository.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/services/functions/functions_service.dart';

class MockUser implements User {
  @override
  final String uid;

  @override
  final String? email;

  MockUser({required this.uid, this.email});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  User? _user;

  FakeAuthService([this._user]);

  void setUser(User? user) => _user = user;

  @override
  User? get currentUser => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeChallengeRepository implements ChallengeRepository {
  CriarDesafioRequest? lastCreateRequest;
  AceitarDesafioRequest? lastAcceptRequest;

  CriarDesafioResponse? createResponse;
  AceitarDesafioResponse? acceptResponse;

  Exception? errorToThrow;

  @override
  Future<CriarDesafioResponse> criarDesafio(CriarDesafioRequest request) async {
    lastCreateRequest = request;
    if (errorToThrow != null) throw errorToThrow!;
    return createResponse ??
        CriarDesafioResponse(
          challengeId: 'chl_generated',
          status: StatusDesafio.pending,
          challengerId: 'uid_alice',
          challengedId: request.challengedId,
          matchId: request.matchId,
          challengerPrediction: request.challengerPrediction,
          amount: request.amount,
        );
  }

  @override
  Future<AceitarDesafioResponse> aceitarDesafio(AceitarDesafioRequest request) async {
    lastAcceptRequest = request;
    if (errorToThrow != null) throw errorToThrow!;
    return acceptResponse ??
        AceitarDesafioResponse(
          challengeId: request.challengeId,
          status: StatusDesafio.accepted,
          challengerId: 'uid_alice',
          challengedId: 'uid_bob',
          matchId: 'match_123',
          challengerPrediction: Palpite.homeWin,
          challengedPrediction: request.challengedPrediction,
          amount: 50,
          acceptedAt: DateTime.now(),
        );
  }

  @override
  Future<List<ChallengeModel>> listarDesafiosDoUsuario(String uid) async => [];

  @override
  Stream<List<ChallengeModel>> observarDesafiosDoUsuario(String uid) => const Stream.empty();

  @override
  Future<int?> buscarSaldoDisponivel(String uid) async => 500;

  @override
  Future<List<AmigoItem>> listarAmigosAceitos(String uid) async => [];
}

void main() {
  group('ChallengeService - Criação e Aceite de Desafios', () {
    late FakeAuthService authService;
    late FakeChallengeRepository repository;
    late ChallengeService service;

    setUp(() {
      authService = FakeAuthService(MockUser(uid: 'uid_alice'));
      repository = FakeChallengeRepository();
      service = ChallengeService(
        authService: authService,
        repository: repository,
      );
    });

    group('criarDesafio', () {
      test('exige usuário autenticado', () async {
        authService.setUser(null);

        expect(
          () => service.criarDesafio(
            challengedId: 'uid_bob',
            matchId: 'match_123',
            challengerPrediction: Palpite.homeWin,
            amount: 50,
          ),
          throwsA(
            isA<ChallengeException>().having(
              (e) => e.code,
              'code',
              ChallengeErrorCode.unauthenticated,
            ),
          ),
        );
      });

      test('impede auto-desafio (challengerId == challengedId)', () async {
        expect(
          () => service.criarDesafio(
            challengedId: 'uid_alice', // mesmo do usuário logado
            matchId: 'match_123',
            challengerPrediction: Palpite.homeWin,
            amount: 50,
          ),
          throwsA(
            isA<ChallengeException>().having(
              (e) => e.code,
              'code',
              ChallengeErrorCode.selfChallenge,
            ),
          ),
        );
      });

      test('rejeita amount menor que 10 BetCoins (RN-BET-002)', () async {
        expect(
          () => service.criarDesafio(
            challengedId: 'uid_bob',
            matchId: 'match_123',
            challengerPrediction: Palpite.homeWin,
            amount: 9,
          ),
          throwsA(
            isA<ChallengeException>().having(
              (e) => e.code,
              'code',
              ChallengeErrorCode.invalidAmount,
            ),
          ),
        );
      });

      test('rejeita amount maior que 500 BetCoins (RN-BET-003)', () async {
        expect(
          () => service.criarDesafio(
            challengedId: 'uid_bob',
            matchId: 'match_123',
            challengerPrediction: Palpite.homeWin,
            amount: 501,
          ),
          throwsA(
            isA<ChallengeException>().having(
              (e) => e.code,
              'code',
              ChallengeErrorCode.invalidAmount,
            ),
          ),
        );
      });

      test('rejeita matchId vazio', () async {
        expect(
          () => service.criarDesafio(
            challengedId: 'uid_bob',
            matchId: '   ',
            challengerPrediction: Palpite.homeWin,
            amount: 50,
          ),
          throwsA(
            isA<ChallengeException>().having(
              (e) => e.code,
              'code',
              ChallengeErrorCode.invalidMatch,
            ),
          ),
        );
      });

      test('criação válida repassa dados corretos ao repositório', () async {
        final res = await service.criarDesafio(
          challengedId: 'uid_bob',
          matchId: 'match_123',
          challengerPrediction: Palpite.homeWin,
          amount: 100,
        );

        expect(repository.lastCreateRequest?.challengedId, 'uid_bob');
        expect(repository.lastCreateRequest?.matchId, 'match_123');
        expect(repository.lastCreateRequest?.challengerPrediction, Palpite.homeWin);
        expect(repository.lastCreateRequest?.amount, 100);
        expect(res.status, StatusDesafio.pending);
      });
    });

    group('aceitarDesafio', () {
      test('exige usuário autenticado', () async {
        authService.setUser(null);

        expect(
          () => service.aceitarDesafio(
            challengeId: 'chl_123',
            challengedPrediction: Palpite.awayWin,
          ),
          throwsA(
            isA<ChallengeException>().having(
              (e) => e.code,
              'code',
              ChallengeErrorCode.unauthenticated,
            ),
          ),
        );
      });

      test('rejeita challengeId vazio', () async {
        expect(
          () => service.aceitarDesafio(
            challengeId: '   ',
            challengedPrediction: Palpite.awayWin,
          ),
          throwsA(
            isA<ChallengeException>().having(
              (e) => e.code,
              'code',
              ChallengeErrorCode.challengeNotFound,
            ),
          ),
        );
      });

      test('aceite válido repassa dados corretos ao repositório', () async {
        final res = await service.aceitarDesafio(
          challengeId: 'chl_123',
          challengedPrediction: Palpite.awayWin,
        );

        expect(repository.lastAcceptRequest?.challengeId, 'chl_123');
        expect(repository.lastAcceptRequest?.challengedPrediction, Palpite.awayWin);
        expect(res.status, StatusDesafio.accepted);
      });
    });

    group('ChallengeException.fromFunctionsException', () {
      test('mapeia motivo auto-desafio', () {
        final e = ChallengeException.fromFunctionsException(
          FunctionsException(
            code: 'invalid-argument',
            message: 'Auto desafio',
            motivo: 'auto-desafio',
          ),
        );
        expect(e.code, ChallengeErrorCode.selfChallenge);
      });

      test('mapeia motivo amizade-necessaria', () {
        final e = ChallengeException.fromFunctionsException(
          FunctionsException(
            code: 'failed-precondition',
            message: 'Amizade necessaria',
            motivo: 'amizade-necessaria',
          ),
        );
        expect(e.code, ChallengeErrorCode.friendshipRequired);
      });

      test('mapeia motivo partida-no-corte', () {
        final e = ChallengeException.fromFunctionsException(
          FunctionsException(
            code: 'failed-precondition',
            message: 'Corte',
            motivo: 'partida-no-corte',
          ),
        );
        expect(e.code, ChallengeErrorCode.matchCutoff);
      });

      test('mapeia motivo desafio-ativo-existente', () {
        final e = ChallengeException.fromFunctionsException(
          FunctionsException(
            code: 'already-exists',
            message: 'Ja ativo',
            motivo: 'desafio-ativo-existente',
          ),
        );
        expect(e.code, ChallengeErrorCode.activeChallengeExists);
      });

      test('mapeia motivo saldo-insuficiente', () {
        final e = ChallengeException.fromFunctionsException(
          FunctionsException(
            code: 'failed-precondition',
            message: 'Sem saldo',
            motivo: 'saldo-insuficiente',
          ),
        );
        expect(e.code, ChallengeErrorCode.insufficientBalance);
      });

      test('mapeia motivo palpite-duplicado', () {
        final e = ChallengeException.fromFunctionsException(
          FunctionsException(
            code: 'invalid-argument',
            message: 'Mesmo palpite',
            motivo: 'palpite-duplicado',
          ),
        );
        expect(e.code, ChallengeErrorCode.duplicatePrediction);
      });

      test('mapeia motivo nao-desafiado', () {
        final e = ChallengeException.fromFunctionsException(
          FunctionsException(
            code: 'permission-denied',
            message: 'Nao desafiado',
            motivo: 'nao-desafiado',
          ),
        );
        expect(e.code, ChallengeErrorCode.notChallengedUser);
      });
    });
  });
}
