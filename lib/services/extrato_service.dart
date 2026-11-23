import '../data/firestore/extrato_repository.dart';
import 'auth_service.dart';

/// Extrato de BetCoins do usuário logado (RF-019). O UID vem sempre do
/// Firebase Authentication, nunca de parâmetros informados pela tela.
class ExtratoService {
  final AuthService _authService;
  final ExtratoRepository _repository;

  ExtratoService({
    AuthService? authService,
    ExtratoRepository? repository,
  })  : _authService = authService ?? AuthService(),
        _repository = repository ?? FirestoreExtratoRepository();

  Future<PaginaDoExtrato> buscarDoUsuarioAtual({
    int limite = FirestoreExtratoRepository.limitePadrao,
    CursorDoExtrato? cursor,
  }) {
    final usuario = _authService.currentUser;
    if (usuario == null) {
      throw const ExtratoException(
        ExtratoErrorCode.unauthenticated,
        'É necessário estar autenticado.',
      );
    }
    return _repository.buscar(usuario.uid, limite: limite, cursor: cursor);
  }
}
