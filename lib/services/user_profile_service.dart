import 'package:firebase_auth/firebase_auth.dart' show User;

import '../data/firestore/user_profile_repository.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

/// Liga o perfil ao usuário autenticado: o UID e o e-mail vêm sempre do
/// Firebase Authentication, nunca de parâmetros informados pela tela.
class UserProfileService {
  final AuthService _authService;
  final UserProfileRepository _repository;

  UserProfileService({
    AuthService? authService,
    UserProfileRepository? repository,
  })  : _authService = authService ?? AuthService(),
        _repository = repository ?? FirestoreUserProfileRepository();

  /// Perfil do usuário logado, ou `null` se ainda não foi criado.
  Future<UserProfile?> carregarPerfilAtual() {
    return _repository.buscarPorUid(_usuarioAtual().uid);
  }

  Stream<PerfilObservado> observarPerfilAtual() {
    return _repository.observarPorUid(_usuarioAtual().uid);
  }

  /// Cria `users/{uid}` para o usuário logado. Ponto de entrada para o
  /// cadastro (KAN-25); a validação de unicidade do username é da KAN-31.
  Future<UserProfile> criarPerfilDoUsuarioAtual({
    required String displayName,
    required String username,
    required String usernameNormalized,
  }) async {
    final usuario = _usuarioAtual();
    final email = usuario.email;
    if (email == null || email.trim().isEmpty) {
      throw const UserProfileException(
        UserProfileErrorCode.invalidData,
        'O usuário autenticado não possui e-mail.',
      );
    }

    final perfil = UserProfile(
      uid: usuario.uid,
      displayName: displayName.trim(),
      username: username.trim(),
      usernameNormalized: usernameNormalized.trim(),
      email: email,
    );

    if (perfil.displayName.isEmpty ||
        perfil.username.isEmpty ||
        perfil.usernameNormalized.isEmpty) {
      throw const UserProfileException(
        UserProfileErrorCode.invalidData,
        'Nome e username são obrigatórios.',
      );
    }

    await _repository.criar(perfil);
    return perfil;
  }

  /// Altera o nome de exibição do usuário logado. Segue o schema §3.1:
  /// 1 a 60 caracteres após `trim`. O UID e as demais referências não mudam.
  Future<void> atualizarDisplayNameAtual(String displayName) async {
    final uid = _usuarioAtual().uid;
    final nome = displayName.trim();
    if (nome.isEmpty || nome.length > 60) {
      throw const UserProfileException(
        UserProfileErrorCode.invalidData,
        'O nome deve ter entre 1 e 60 caracteres.',
      );
    }
    await _repository.atualizarDisplayName(uid, nome);
  }

  User _usuarioAtual() {
    final usuario = _authService.currentUser;
    if (usuario == null) {
      throw const UserProfileException(
        UserProfileErrorCode.unauthenticated,
        'É necessário estar autenticado.',
      );
    }
    return usuario;
  }
}
