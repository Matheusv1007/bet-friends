import '../data/firestore/challenge_repository.dart';
import '../models/challenge_model.dart';
import 'auth_service.dart';
import 'functions/functions_service.dart';

/// Serviço responsável pelas operações e regras de negócio de desafios (RF-009, RF-010, RF-011).
class ChallengeService {
  final AuthService _authService;
  final ChallengeRepository? _repositorySobDemanda;
  final FunctionsService? _functions;

  ChallengeService({
    AuthService? authService,
    ChallengeRepository? repository,
    FunctionsService? functionsService,
  })  : _authService = authService ?? AuthService(),
        _repositorySobDemanda = repository,
        _functions = functionsService;

  ChallengeRepository get _repository =>
      _repositorySobDemanda ??
      FunctionsChallengeRepository(functions: _functions);

  /// Cria um desafio para um amigo com validações locais prévias e persistência atômica no backend.
  Future<CriarDesafioResponse> criarDesafio({
    required String challengedId,
    required String matchId,
    required Palpite challengerPrediction,
    required int amount,
  }) async {
    final usuarioLogado = _authService.currentUser;
    if (usuarioLogado == null) {
      throw const ChallengeException(
        ChallengeErrorCode.unauthenticated,
        'É necessário estar autenticado para criar um desafio.',
      );
    }

    final cleanChallengedId = challengedId.trim();
    if (cleanChallengedId.isEmpty) {
      throw const ChallengeException(
        ChallengeErrorCode.invalidAmount,
        'Identificador do amigo desafiado é obrigatório.',
      );
    }

    if (cleanChallengedId == usuarioLogado.uid) {
      throw const ChallengeException(
        ChallengeErrorCode.selfChallenge,
        'Não é permitido criar um desafio para si mesmo.',
      );
    }

    final cleanMatchId = matchId.trim();
    if (cleanMatchId.isEmpty) {
      throw const ChallengeException(
        ChallengeErrorCode.invalidMatch,
        'Identificador da partida é obrigatório.',
      );
    }

    if (amount < 10 || amount > 500) {
      throw const ChallengeException(
        ChallengeErrorCode.invalidAmount,
        'O valor da aposta deve ser entre 10 e 500 BetCoins.',
      );
    }

    return _repository.criarDesafio(
      CriarDesafioRequest(
        challengedId: cleanChallengedId,
        matchId: cleanMatchId,
        challengerPrediction: challengerPrediction,
        amount: amount,
      ),
    );
  }

  /// Aceita um desafio pendente escolhendo um palpite diferente e reservando BetCoins no backend.
  Future<AceitarDesafioResponse> aceitarDesafio({
    required String challengeId,
    required Palpite challengedPrediction,
  }) async {
    final usuarioLogado = _authService.currentUser;
    if (usuarioLogado == null) {
      throw const ChallengeException(
        ChallengeErrorCode.unauthenticated,
        'É necessário estar autenticado para aceitar um desafio.',
      );
    }

    final cleanChallengeId = challengeId.trim();
    if (cleanChallengeId.isEmpty) {
      throw const ChallengeException(
        ChallengeErrorCode.challengeNotFound,
        'Identificador do desafio é obrigatório.',
      );
    }

    return _repository.aceitarDesafio(
      AceitarDesafioRequest(
        challengeId: cleanChallengeId,
        challengedPrediction: challengedPrediction,
      ),
    );
  }

  /// Lista todos os desafios do usuário atual.
  Future<List<ChallengeModel>> listarDesafios() async {
    final usuarioLogado = _authService.currentUser;
    if (usuarioLogado == null) return [];
    return _repository.listarDesafiosDoUsuario(usuarioLogado.uid);
  }

  /// Observa os desafios do usuário atual em tempo real.
  Stream<List<ChallengeModel>> observarDesafios() {
    final usuarioLogado = _authService.currentUser;
    if (usuarioLogado == null) return const Stream.empty();
    return _repository.observarDesafiosDoUsuario(usuarioLogado.uid);
  }

  /// Retorna o saldo disponível de BetCoins do usuário logado.
  Future<int?> buscarSaldoDisponivel() async {
    final usuarioLogado = _authService.currentUser;
    if (usuarioLogado == null) return null;
    return _repository.buscarSaldoDisponivel(usuarioLogado.uid);
  }

  /// Lista os amigos com relação aceita elegíveis para novos desafios.
  Future<List<AmigoItem>> listarAmigosAceitos() async {
    final usuarioLogado = _authService.currentUser;
    if (usuarioLogado == null) return const [];
    return _repository.listarAmigosAceitos(usuarioLogado.uid);
  }
}

