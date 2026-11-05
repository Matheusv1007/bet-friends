import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/challenge_model.dart';
import '../../services/functions/functions_service.dart';
import 'firestore_collections.dart';

enum ChallengeErrorCode {
  unauthenticated,
  selfChallenge,
  friendshipRequired,
  matchCutoff,
  invalidMatch,
  activeChallengeExists,
  notPending,
  notChallengedUser,
  duplicatePrediction,
  invalidPrediction,
  insufficientBalance,
  invalidAmount,
  challengeNotFound,
  permissionDenied,
  unavailable,
  unknown,
}

/// Exceção de domínio para operações de desafio (RF-009, RF-010, RF-011).
class ChallengeException implements Exception {
  final ChallengeErrorCode code;
  final String message;

  const ChallengeException(this.code, this.message);

  factory ChallengeException.fromFunctionsException(FunctionsException e) {
    final motivo = e.motivo;

    if (motivo == 'auto-desafio') {
      return const ChallengeException(
        ChallengeErrorCode.selfChallenge,
        'Não é permitido criar um desafio para si mesmo.',
      );
    }
    if (motivo == 'amizade-necessaria') {
      return const ChallengeException(
        ChallengeErrorCode.friendshipRequired,
        'É necessário ter amizade aceita com o amigo para criar um desafio.',
      );
    }
    if (motivo == 'partida-no-corte') {
      return const ChallengeException(
        ChallengeErrorCode.matchCutoff,
        'A partida já atingiu o corte de 5 minutos antes do início.',
      );
    }
    if (motivo == 'partida-invalida') {
      return const ChallengeException(
        ChallengeErrorCode.invalidMatch,
        'A partida não está disponível para apostas.',
      );
    }
    if (motivo == 'desafio-ativo-existente') {
      return const ChallengeException(
        ChallengeErrorCode.activeChallengeExists,
        'Você já possui um desafio ativo para esta partida.',
      );
    }
    if (motivo == 'desafio-nao-pendente') {
      return const ChallengeException(
        ChallengeErrorCode.notPending,
        'Somente desafios pendentes podem ser aceitos.',
      );
    }
    if (motivo == 'nao-desafiado') {
      return const ChallengeException(
        ChallengeErrorCode.notChallengedUser,
        'Somente o usuário desafiado pode aceitar o desafio.',
      );
    }
    if (motivo == 'palpite-duplicado') {
      return const ChallengeException(
        ChallengeErrorCode.duplicatePrediction,
        'O palpite do desafiado deve ser diferente do palpite do criador.',
      );
    }
    if (motivo == 'palpite-invalido') {
      return const ChallengeException(
        ChallengeErrorCode.invalidPrediction,
        'Palpite inválido. Escolha Mandante, Empate ou Visitante.',
      );
    }
    if (motivo == 'saldo-insuficiente') {
      return const ChallengeException(
        ChallengeErrorCode.insufficientBalance,
        'Saldo disponível de BetCoins insuficiente para esta aposta.',
      );
    }
    if (motivo == 'valor-invalido') {
      return const ChallengeException(
        ChallengeErrorCode.invalidAmount,
        'O valor da aposta deve ser entre 10 e 500 BetCoins.',
      );
    }
    if (motivo == 'desafio-inexistente') {
      return const ChallengeException(
        ChallengeErrorCode.challengeNotFound,
        'Desafio não encontrado.',
      );
    }

    switch (e.code) {
      case 'unauthenticated':
        return const ChallengeException(
          ChallengeErrorCode.unauthenticated,
          'É necessário estar autenticado para realizar esta ação.',
        );
      case 'not-found':
        return const ChallengeException(
          ChallengeErrorCode.challengeNotFound,
          'Desafio ou partida não encontrado.',
        );
      case 'permission-denied':
        return const ChallengeException(
          ChallengeErrorCode.permissionDenied,
          'Sem permissão para alterar este desafio.',
        );
      case 'already-exists':
        return const ChallengeException(
          ChallengeErrorCode.activeChallengeExists,
          'Já existe um desafio ativo para esta partida.',
        );
      case 'failed-precondition':
        return ChallengeException(
          ChallengeErrorCode.notPending,
          e.message.isNotEmpty ? e.message : 'Ação não permitida no estado atual do desafio.',
        );
      case 'invalid-argument':
        return ChallengeException(
          ChallengeErrorCode.invalidAmount,
          e.message.isNotEmpty ? e.message : 'Dados informados para o desafio são inválidos.',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return const ChallengeException(
          ChallengeErrorCode.unavailable,
          'Serviço indisponível no momento. Verifique sua conexão.',
        );
      default:
        return ChallengeException(
          ChallengeErrorCode.unknown,
          e.message.isNotEmpty
              ? e.message
              : 'Não foi possível processar a operação de desafio.',
        );
    }
  }

  @override
  String toString() => 'ChallengeException(${code.name}): $message';
}

/// Contrato para operações de desafios no aplicativo.
abstract interface class ChallengeRepository {
  Future<CriarDesafioResponse> criarDesafio(CriarDesafioRequest request);
  Future<AceitarDesafioResponse> aceitarDesafio(AceitarDesafioRequest request);
  Future<List<ChallengeModel>> listarDesafiosDoUsuario(String uid);
  Stream<List<ChallengeModel>> observarDesafiosDoUsuario(String uid);
  Future<int?> buscarSaldoDisponivel(String uid);
  Future<List<AmigoItem>> listarAmigosAceitos(String uid);
}

/// Implementação padrão que utiliza Callable Functions para mutações e Firestore para leituras.
class FunctionsChallengeRepository implements ChallengeRepository {
  final FunctionsService? _functionsSobDemanda;
  final FirebaseFirestore _firestore;

  FunctionsChallengeRepository({
    FunctionsService? functions,
    FirebaseFirestore? firestore,
  })  : _functionsSobDemanda = functions,
        _firestore = firestore ?? FirebaseFirestore.instance;

  FunctionsService get _functions => _functionsSobDemanda ?? FunctionsService();

  @override
  Future<CriarDesafioResponse> criarDesafio(CriarDesafioRequest request) async {
    try {
      final response = await _functions.call(
        CallableNames.createChallenge,
        request.toMap(),
      );
      return CriarDesafioResponse.fromMap(response);
    } on FunctionsException catch (e) {
      throw ChallengeException.fromFunctionsException(e);
    } catch (_) {
      throw const ChallengeException(
        ChallengeErrorCode.unknown,
        'Não foi possível criar o desafio. Tente novamente.',
      );
    }
  }

  @override
  Future<AceitarDesafioResponse> aceitarDesafio(AceitarDesafioRequest request) async {
    try {
      final response = await _functions.call(
        CallableNames.acceptChallenge,
        request.toMap(),
      );
      return AceitarDesafioResponse.fromMap(response);
    } on FunctionsException catch (e) {
      throw ChallengeException.fromFunctionsException(e);
    } catch (_) {
      throw const ChallengeException(
        ChallengeErrorCode.unknown,
        'Não foi possível aceitar o desafio. Tente novamente.',
      );
    }
  }

  @override
  Future<List<ChallengeModel>> listarDesafiosDoUsuario(String uid) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.challenges)
        .where('participants', arrayContains: uid)
        .get();

    return snapshot.docs
        .map((doc) => ChallengeModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Stream<List<ChallengeModel>> observarDesafiosDoUsuario(String uid) {
    return _firestore
        .collection(FirestoreCollections.challenges)
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<int?> buscarSaldoDisponivel(String uid) async {
    try {
      final doc = await _firestore.collection(FirestoreCollections.users).doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      final total = (data['saldoTotal'] as num?)?.toInt() ?? 1000;
      final reservado = (data['saldoReservado'] as num?)?.toInt() ?? 0;
      return total - reservado;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AmigoItem>> listarAmigosAceitos(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.friendships)
          .where('participants', arrayContains: uid)
          .where('status', isEqualTo: 'ACCEPTED')
          .get();

      var resultado = <AmigoItem>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userAId = data['userAId']?.toString() ?? '';
        final userBId = data['userBId']?.toString() ?? '';
        final otherUid = userAId == uid ? userBId : userAId;

        if (otherUid.isNotEmpty) {
          final friendDoc = await _firestore.collection(FirestoreCollections.users).doc(otherUid).get();
          final friendData = friendDoc.data() ?? {};
          final name = friendData['displayName']?.toString() ?? 'Amigo';
          final uname = friendData['username']?.toString() ?? otherUid;
          resultado = [...resultado, AmigoItem(uid: otherUid, displayName: name, username: uname)];
        }
      }
      return resultado;
    } catch (_) {
      return const [];
    }
  }
}

