import '../data/firestore/historico_de_desafios_repository.dart';
import 'auth_service.dart';

/// Histórico de desafios do usuário logado (KAN-89). O UID vem sempre do
/// Firebase Authentication, nunca de parâmetros informados pela tela.
class HistoricoDeDesafiosService {
  final AuthService _authService;
  final HistoricoDeDesafiosRepository _repository;

  HistoricoDeDesafiosService({
    AuthService? authService,
    HistoricoDeDesafiosRepository? repository,
  })  : _authService = authService ?? AuthService(),
        _repository = repository ?? FirestoreHistoricoDeDesafiosRepository();

  Future<PaginaDoHistorico> buscarDoUsuarioAtual({
    int limite = FirestoreHistoricoDeDesafiosRepository.limitePadrao,
    CursorDoHistorico? cursor,
  }) {
    final usuario = _authService.currentUser;
    if (usuario == null) {
      throw const HistoricoException(
        HistoricoErrorCode.unauthenticated,
        'É necessário estar autenticado.',
      );
    }
    return _repository.buscar(usuario.uid, limite: limite, cursor: cursor);
  }
}
