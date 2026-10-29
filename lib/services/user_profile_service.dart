import 'package:firebase_auth/firebase_auth.dart' show User;

import '../data/firestore/user_profile_repository.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';
import 'functions/functions_service.dart';

/// Liga o perfil ao usuário autenticado: o UID e o e-mail vêm sempre do
/// Firebase Authentication, nunca de parâmetros informados pela tela.
class UserProfileService {
  final AuthService _authService;
  final UserProfileRepository _repository;
  FunctionsService? _functionsSobDemanda;

  UserProfileService({
    AuthService? authService,
    UserProfileRepository? repository,
    FunctionsService? functionsService,
  })  : _authService = authService ?? AuthService(),
        _repository = repository ?? FirestoreUserProfileRepository(),
        _functionsSobDemanda = functionsService;

  // Criado sob demanda: telas que só leem o perfil não dependem das Functions
  FunctionsService get _functions => _functionsSobDemanda ??= FunctionsService();

  /// Perfil do usuário logado, ou `null` se ainda não foi criado.
  Future<UserProfile?> carregarPerfilAtual() {
    return _repository.buscarPorUid(_usuarioAtual().uid);
  }

  Stream<PerfilObservado> observarPerfilAtual() {
    return _repository.observarPorUid(_usuarioAtual().uid);
  }

  /// Cria o perfil do usuário logado pela Callable `createUserProfile`
  /// (KAN-31), que grava `users/{uid}`, `usernames/{usernameNormalized}` e a
  /// carteira inicial numa única transação. O app não grava nenhum desses
  /// documentos: o UID e o e-mail vêm do token no backend, e o username é
  /// validado e normalizado lá.
  ///
  /// Ponto de entrada do cadastro (KAN-25), depois de criar a conta no
  /// Firebase Auth. Pode ser repetida após uma falha: se o perfil já existir
  /// com o mesmo username, nada é gravado de novo e o retorno tem
  /// `criado == false`. Não há repetição automática; sem confirmação do
  /// servidor ([UserProfileErrorCode.unavailable]) o perfil pode ter sido
  /// criado ou não, e a nova tentativa depende de uma ação do usuário.
  ///
  /// Erros, sempre como [UserProfileException]:
  /// - `unauthenticated`: sem sessão ou token recusado;
  /// - `invalidData`: nome ou username fora do formato, ou conta sem e-mail;
  /// - `usernameUnavailable`: username de outro usuário;
  /// - `alreadyExists`: o usuário já tem perfil com outro username;
  /// - `unavailable`: sem conexão ou prazo esgotado;
  /// - `unknown`: função indisponível, erro interno ou resposta inesperada.
  Future<CriacaoDePerfil> criarPerfilDoUsuarioAtual({
    required String displayName,
    required String username,
  }) async {
    final usuario = _usuarioAtual();
    final email = usuario.email;
    if (email == null || email.trim().isEmpty) {
      throw const UserProfileException(
        UserProfileErrorCode.invalidData,
        'O usuário autenticado não possui e-mail.',
      );
    }

    final Map<String, dynamic> resposta;
    try {
      resposta = await _functions.call(CallableNames.createUserProfile, {
        'displayName': displayName,
        'username': username,
      });
    } on FunctionsException catch (e) {
      throw _erroDaCriacao(e);
    }
    return CriacaoDePerfil._daResposta(resposta, uid: usuario.uid, email: email);
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

/// Resultado de [UserProfileService.criarPerfilDoUsuarioAtual].
class CriacaoDePerfil {
  /// Perfil do usuário logado. `createdAt`/`updatedAt` ficam nulos: a resposta
  /// da Callable não traz datas; a leitura de `users/{uid}` traz.
  final UserProfile perfil;

  /// `false` quando o perfil já existia com o mesmo username (repetição).
  final bool criado;

  const CriacaoDePerfil({required this.perfil, required this.criado});

  /// Resposta de `createUserProfile` (functions/src/perfil/createUserProfile.ts):
  /// `{ criado, displayName, username, usernameNormalized }`.
  factory CriacaoDePerfil._daResposta(
    Map<String, dynamic> resposta, {
    required String uid,
    required String email,
  }) {
    final criado = resposta['criado'];
    if (criado is! bool) throw _respostaInesperada;
    try {
      return CriacaoDePerfil(
        perfil: UserProfile.fromMap(uid, {...resposta, 'email': email}),
        criado: criado,
      );
    } on FormatException {
      throw _respostaInesperada;
    }
  }

  static const _respostaInesperada = UserProfileException(
    UserProfileErrorCode.unknown,
    'Resposta inesperada do servidor ao criar o perfil.',
  );
}

/// Traduz o erro da Callable sem repassar a mensagem técnica do backend.
UserProfileException _erroDaCriacao(FunctionsException e) {
  switch (e.code) {
    case 'unauthenticated':
      return const UserProfileException(
        UserProfileErrorCode.unauthenticated,
        'É necessário estar autenticado.',
      );
    case 'invalid-argument':
      return UserProfileException(
        UserProfileErrorCode.invalidData,
        e.motivo == 'nome-invalido'
            ? 'O nome deve ter entre 1 e 60 caracteres.'
            : 'O username deve ter de 3 a 20 caracteres: letras sem acento, números ou "_".',
      );
    case 'already-exists':
      return const UserProfileException(
        UserProfileErrorCode.usernameUnavailable,
        'Este username já está em uso.',
      );
    case 'failed-precondition':
      if (e.motivo == 'perfil-existente') {
        return const UserProfileException(
          UserProfileErrorCode.alreadyExists,
          'Esta conta já possui um perfil.',
        );
      }
      if (e.motivo == 'email-ausente') {
        return const UserProfileException(
          UserProfileErrorCode.invalidData,
          'O usuário autenticado não possui e-mail.',
        );
      }
      break;
    case 'unavailable':
    case 'deadline-exceeded':
      return const UserProfileException(
        UserProfileErrorCode.unavailable,
        'Sem confirmação do servidor. Verifique sua conexão e tente novamente.',
      );
  }
  return const UserProfileException(
    UserProfileErrorCode.unknown,
    'Não foi possível criar o perfil agora. Tente novamente mais tarde.',
  );
}
