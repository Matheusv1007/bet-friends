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

  Future<void> signOut() async {
    final db = firestore ?? FirebaseFirestore.instanceFor(app: _auth.app);
    await _auth.signOut();
    // O plugin Android remove o cliente encerrado de seu cache; o próximo
    // login obtém um cliente novo, sem os dados persistidos da sessão anterior.
    await db.terminate();
    await db.clearPersistence();
  }
}