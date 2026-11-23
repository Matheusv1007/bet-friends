import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'functions/functions_service.dart';

class AuthService {
  final FirebaseAuth? firebaseAuth;

  final FirebaseFirestore? firestore;

  final FunctionsService? _functionsSobDemanda;

  AuthService({
    this.firebaseAuth,
    this.firestore,
    FunctionsService? functionsService,
  }) : _functionsSobDemanda = functionsService;

  // Resolvido sob demanda para permitir fakes em testes sem Firebase inicializado
  FirebaseAuth get _auth => firebaseAuth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Entra com e-mail ou username (imutável) e senha. O Firebase Auth só
  /// autentica por e-mail, então o username é convertido antes pelo backend.
  ///
  /// Username inexistente falha com `invalid-credential`, o mesmo erro de senha
  /// errada, para a tela não revelar quais usernames existem.
  Future<UserCredential> signIn({
    required String identifier,
    required String password,
  }) async {
    final email = await _emailDe(identifier.trim());
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Username não tem `@` (só letras, números e `_`); o `@` inicial é apenas
  /// o estilo de exibição (`@teste_b`).
  Future<String> _emailDe(String identificador) async {
    if (identificador.contains('@') && !identificador.startsWith('@')) {
      return identificador;
    }

    final String? email;
    try {
      final resposta = await (_functionsSobDemanda ?? FunctionsService()).call(
        CallableNames.resolveLoginEmail,
        {'username': identificador},
      );
      email = resposta['email'] as String?;
    } on FunctionsException catch (e) {
      if (e.semConfirmacaoDoServidor) {
        throw FirebaseAuthException(code: 'network-request-failed');
      }
      if (e.code == 'resource-exhausted') {
        throw FirebaseAuthException(code: 'too-many-requests');
      }
      rethrow;
    }

    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    return email;
  }

  /// A senha só é usada no Firebase Auth; nunca é enviada à callable.
  /// A sessão só sai após confirmação do servidor (ou se já foi invalidada).
  Future<void> deleteAccount({required String password}) async {
    final user = currentUser;
    if (user == null) {
      await signOut();
      throw const DeleteAccountException(
        'unauthenticated',
        'Sua sessão expirou. Entre novamente para excluir a conta.',
      );
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const DeleteAccountException(
        'login-recente-necessario',
        'Entre novamente com seu e-mail e senha para excluir a conta.',
      );
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      // Atualiza auth_time no token que acompanha a callable.
      await user.getIdToken(true);
      final response = await (_functionsSobDemanda ?? FunctionsService()).call(
        CallableNames.deleteAccount,
        <String, dynamic>{},
      );
      if (response['deleted'] != true) {
        throw const DeleteAccountException(
          'unknown',
          'O servidor não confirmou a exclusão. Tente novamente.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'unauthenticated') {
        await signOut();
      }
      throw DeleteAccountException.fromCode(e.code);
    } on FunctionsException catch (e) {
      if (e.isUnauthenticated) await signOut();
      throw DeleteAccountException.fromCode(e.motivo ?? e.code);
    }
    await signOut();
  }

  Future<void> signOut() async {
    final db = firestore ?? FirebaseFirestore.instanceFor(app: _auth.app);
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      // A exclusão pode invalidar a sessão antes do logout local.
      if (e.code != 'user-not-found' && e.code != 'unauthenticated') rethrow;
    } finally {
      // O plugin Android remove o cliente encerrado de seu cache; o próximo
      // login obtém um cliente novo, sem dados persistidos da sessão anterior.
      await db.terminate();
      await db.clearPersistence();
    }
  }
}

/// Falha de exclusão exibível, sem credenciais nem detalhes internos.
class DeleteAccountException implements Exception {
  final String code;
  final String message;

  const DeleteAccountException(this.code, this.message);

  factory DeleteAccountException.fromCode(String code) {
    final message = switch (code) {
      'desafio-ativo' =>
        'Conclua ou cancele seus desafios em andamento antes de excluir a conta.',
      'saldo-reservado' =>
        'Você possui saldo reservado. Aguarde a liberação antes de excluir a conta.',
      'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' =>
        'Senha incorreta. Confira sua senha e tente novamente.',
      'login-recente-necessario' || 'requires-recent-login' =>
        'Por segurança, entre novamente e confirme sua senha para excluir a conta.',
      'unauthenticated' || 'user-not-found' || 'user-token-expired' =>
        'Sua sessão expirou. Entre novamente para excluir a conta.',
      'network-request-failed' || 'unavailable' || 'deadline-exceeded' =>
        'Sem conexão com o servidor. A exclusão não foi confirmada. Tente novamente online.',
      'too-many-requests' || 'resource-exhausted' =>
        'Muitas tentativas. Aguarde um pouco antes de tentar excluir a conta novamente.',
      _ => 'Não foi possível excluir a conta. Tente novamente.',
    };
    return DeleteAccountException(code, message);
  }

  @override
  String toString() => 'DeleteAccountException ($code): $message';
}