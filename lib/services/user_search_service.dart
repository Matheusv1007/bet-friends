import '../data/firestore/user_profile_repository.dart';
import '../data/firestore/user_search_repository.dart';
import '../models/usuario_publico.dart';
import 'auth_service.dart';
import 'functions/functions_service.dart';

/// Serviço responsável por coordenar a busca pública de outros usuários (RF-004).
///
/// Diretrizes e Regras de Negócio:
/// - Exige usuário autenticado (unauthenticated se a sessão for nula).
/// - Identidade estável pelo [UsuarioPublico.userId] (RN-AUTH-006).
/// - Exclusão estrita do próprio usuário solicitante (RN-FRD-002): o usuário atual
///   nunca aparece nos resultados e não pode ser adicionado por si mesmo.
/// - Exposição estritamente de dados públicos: nome e username (RN-PROF-002).
///   E-mails, saldos e transações nunca são retornados.
class UserSearchService {
  final AuthService _authService;
  final UserSearchRepository? _repositorySobDemanda;
  final FunctionsService? _functions;

  UserSearchService({
    AuthService? authService,
    UserSearchRepository? repository,
    FunctionsService? functionsService,
  })  : _authService = authService ?? AuthService(),
        _repositorySobDemanda = repository,
        _functions = functionsService;

  UserSearchRepository get _repository =>
      _repositorySobDemanda ??
      FunctionsUserSearchRepository(functions: _functions);

  /// Busca outros usuários cadastrados a partir do termo digitado.
  Future<List<UsuarioPublico>> buscarUsuarios(
    String termo, {
    int limite = 20,
  }) async {
    final usuario = _authService.currentUser;
    if (usuario == null) {
      throw const UserProfileException(
        UserProfileErrorCode.unauthenticated,
        'É necessário estar autenticado para buscar usuários.',
      );
    }

    final query = termo.trim();
    if (query.isEmpty) {
      return const <UsuarioPublico>[];
    }

    final resultados = await _repository.buscarUsuarios(
      query,
      usuarioAtualUid: usuario.uid,
      limite: limite,
    );

    // Garantia em camada de serviço de que o próprio usuário nunca seja incluído (RN-FRD-002)
    return resultados
        .where((u) => u.userId != usuario.uid)
        .toList(growable: false);
  }
}
