import '../data/firestore/friendship_repository.dart';
import '../models/friendship_model.dart';
import 'auth_service.dart';
import 'functions/functions_service.dart';

/// Serviço responsável por coordenar operações de amizade no aplicativo (RF-005, RN-FRD-001, RN-FRD-005).
///
/// Regras de Negócio:
/// - Exige usuário autenticado.
/// - Impede auto-solicitação (RN-FRD-002): o usuário atual não pode solicitar a si mesmo.
/// - Utiliza identificação exclusiva por userId (RN-AUTH-006).
/// - Integra com Callable Functions para persistência, validações de duplicidade (RN-FRD-003, RN-FRD-004)
///   e aceitação de solicitações de amizade (RN-FRD-001, RN-FRD-005).
class FriendshipService {
  final AuthService _authService;
  final FriendshipRepository? _repositorySobDemanda;
  final FunctionsService? _functions;

  FriendshipService({
    AuthService? authService,
    FriendshipRepository? repository,
    FunctionsService? functionsService,
  })  : _authService = authService ?? AuthService(),
        _repositorySobDemanda = repository,
        _functions = functionsService;

  FriendshipRepository get _repository =>
      _repositorySobDemanda ??
      FunctionsFriendshipRepository(functions: _functions);

  /// Envia uma solicitação de amizade para o usuário indicado por [toUserId].
  Future<ResultadoEnvioAmizade> enviarSolicitacaoAmizade(String toUserId) async {
    final usuarioLogado = _authService.currentUser;
    if (usuarioLogado == null) {
      throw const FriendshipException(
        FriendshipErrorCode.unauthenticated,
        'É necessário estar autenticado para enviar solicitação de amizade.',
      );
    }

    final targetUid = toUserId.trim();
    if (targetUid.isEmpty) {
      throw const FriendshipException(
        FriendshipErrorCode.invalidData,
        'Identificador de usuário inválido.',
      );
    }

    // RN-FRD-002: Usuário não pode enviar solicitação para si mesmo
    if (targetUid == usuarioLogado.uid) {
      throw const FriendshipException(
        FriendshipErrorCode.selfRequest,
        'Não é possível enviar solicitação de amizade para si mesmo.',
      );
    }

    return _repository.enviarSolicitacaoAmizade(targetUid);
  }

  /// Aceita uma solicitação de amizade pendente identificado por [identificador] (friendshipId ou UID).
  ///
  /// Critérios (RF-005, RN-FRD-001, RN-FRD-005):
  /// - Somente solicitação pendente pode ser aceita.
  /// - Consolida uma única relação aceita.
  /// - Ambos passam a aparecer como amigos elegíveis para desafios.
  Future<ResultadoAceiteAmizade> aceitarSolicitacaoAmizade(String identificador) async {
    final usuarioLogado = _authService.currentUser;
    if (usuarioLogado == null) {
      throw const FriendshipException(
        FriendshipErrorCode.unauthenticated,
        'É necessário estar autenticado para aceitar solicitação de amizade.',
      );
    }

    final cleanId = identificador.trim();
    if (cleanId.isEmpty) {
      throw const FriendshipException(
        FriendshipErrorCode.invalidData,
        'Identificador de solicitação ou usuário inválido.',
      );
    }

    return _repository.aceitarSolicitacaoAmizade(cleanId);
  }
}
