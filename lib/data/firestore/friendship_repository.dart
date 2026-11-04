import '../../models/friendship_model.dart';
import '../../services/functions/functions_service.dart';

enum FriendshipErrorCode {
  unauthenticated,
  selfRequest,
  userNotFound,
  alreadyFriends,
  alreadyRequested,
  alreadyResolved,
  notTheRecipient,
  requestNotFound,
  permissionDenied,
  unavailable,
  invalidData,
  unknown,
}

/// Exceção de domínio para operações de amizade (RF-005, RN-FRD-001, RN-FRD-003, RN-FRD-005).
class FriendshipException implements Exception {
  final FriendshipErrorCode code;
  final String message;

  const FriendshipException(this.code, this.message);

  factory FriendshipException.fromFunctionsException(FunctionsException e) {
    final motivo = e.motivo;

    if (motivo == 'auto-solicitacao') {
      return const FriendshipException(
        FriendshipErrorCode.selfRequest,
        'Não é possível enviar solicitação de amizade para si mesmo.',
      );
    }
    if (motivo == 'ja-amigos') {
      return const FriendshipException(
        FriendshipErrorCode.alreadyFriends,
        'Vocês já são amigos.',
      );
    }
    if (motivo == 'solicitacao-duplicada') {
      return const FriendshipException(
        FriendshipErrorCode.alreadyRequested,
        'Já existe uma solicitação de amizade pendente para este usuário.',
      );
    }
    if (motivo == 'destinatario-inexistente') {
      return const FriendshipException(
        FriendshipErrorCode.userNotFound,
        'Usuário destinatário não encontrado.',
      );
    }
    if (motivo == 'solicitacao-ja-resolvida') {
      return const FriendshipException(
        FriendshipErrorCode.alreadyResolved,
        'Esta solicitação de amizade já foi resolvida.',
      );
    }
    if (motivo == 'nao-destinatario') {
      return const FriendshipException(
        FriendshipErrorCode.notTheRecipient,
        'Apenas o destinatário pode aceitar a solicitação.',
      );
    }
    if (motivo == 'solicitacao-inexistente') {
      return const FriendshipException(
        FriendshipErrorCode.requestNotFound,
        'Solicitação de amizade não encontrada.',
      );
    }
    if (motivo == 'nao-participante') {
      return const FriendshipException(
        FriendshipErrorCode.permissionDenied,
        'Você não participa desta relação de amizade.',
      );
    }

    switch (e.code) {
      case 'unauthenticated':
        return const FriendshipException(
          FriendshipErrorCode.unauthenticated,
          'É necessário estar autenticado para realizar esta ação.',
        );
      case 'not-found':
        return const FriendshipException(
          FriendshipErrorCode.requestNotFound,
          'Solicitação de amizade ou usuário não encontrado.',
        );
      case 'permission-denied':
        return const FriendshipException(
          FriendshipErrorCode.permissionDenied,
          'Sem permissão para alterar esta relação de amizade.',
        );
      case 'already-exists':
        return const FriendshipException(
          FriendshipErrorCode.alreadyRequested,
          'Já existe uma relação ativa ou pendente para este usuário.',
        );
      case 'failed-precondition':
        return FriendshipException(
          FriendshipErrorCode.alreadyResolved,
          e.message.isNotEmpty ? e.message : 'A solicitação não pode ser aceita no estado atual.',
        );
      case 'invalid-argument':
        return FriendshipException(
          FriendshipErrorCode.invalidData,
          e.message.isNotEmpty
              ? e.message
              : 'Dados inválidos para a solicitação de amizade.',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return const FriendshipException(
          FriendshipErrorCode.unavailable,
          'Serviço temporariamente indisponível. Verifique sua conexão.',
        );
      default:
        return FriendshipException(
          FriendshipErrorCode.unknown,
          e.message.isNotEmpty
              ? e.message
              : 'Não foi possível processar a solicitação. Tente novamente.',
        );
    }
  }

  @override
  String toString() => 'FriendshipException(${code.name}): $message';
}

/// Contrato para operações com amizades no backend/banco (RF-005, RN-FRD-001, RN-FRD-005).
abstract interface class FriendshipRepository {
  /// Envia solicitação de amizade para [toUserId].
  Future<ResultadoEnvioAmizade> enviarSolicitacaoAmizade(String toUserId);

  /// Aceita solicitação de amizade pendente identificado por [identificador] (friendshipId ou UID).
  Future<ResultadoAceiteAmizade> aceitarSolicitacaoAmizade(String identificador);
}

/// Implementação padrão recomendada via Callable Function do backend.
class FunctionsFriendshipRepository implements FriendshipRepository {
  final FunctionsService? _functionsSobDemanda;

  FunctionsFriendshipRepository({FunctionsService? functions})
      : _functionsSobDemanda = functions;

  FunctionsService get _functions => _functionsSobDemanda ?? FunctionsService();

  @override
  Future<ResultadoEnvioAmizade> enviarSolicitacaoAmizade(String toUserId) async {
    final cleanUid = toUserId.trim();
    if (cleanUid.isEmpty) {
      throw const FriendshipException(
        FriendshipErrorCode.invalidData,
        'Identificador de usuário inválido.',
      );
    }

    try {
      final response = await _functions.call(CallableNames.sendFriendRequest, {
        'toUserId': cleanUid,
      });

      return ResultadoEnvioAmizade.fromMap(response);
    } on FunctionsException catch (e) {
      throw FriendshipException.fromFunctionsException(e);
    } catch (_) {
      throw const FriendshipException(
        FriendshipErrorCode.unknown,
        'Não foi possível enviar a solicitação. Tente novamente.',
      );
    }
  }

  @override
  Future<ResultadoAceiteAmizade> aceitarSolicitacaoAmizade(String identificador) async {
    final cleanId = identificador.trim();
    if (cleanId.isEmpty) {
      throw const FriendshipException(
        FriendshipErrorCode.invalidData,
        'Identificador de amizade ou usuário inválido.',
      );
    }

    try {
      final response = await _functions.call(CallableNames.acceptFriendRequest, {
        'friendshipId': cleanId,
      });

      return ResultadoAceiteAmizade.fromMap(response);
    } on FunctionsException catch (e) {
      throw FriendshipException.fromFunctionsException(e);
    } catch (_) {
      throw const FriendshipException(
        FriendshipErrorCode.unknown,
        'Não foi possível aceitar a solicitação. Tente novamente.',
      );
    }
  }
}
