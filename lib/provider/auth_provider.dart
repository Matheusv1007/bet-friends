import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  bool _isSigningOut = false;
  bool _cadastroEmAndamento = false;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  User? get currentUser => _authService.currentUser;

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  bool get isSigningOut => _isSigningOut;

  /// `true` desde a criação da conta até a tela de cadastro terminar (com o
  /// perfil criado ou não). Enquanto isso, o AuthGate não descarta o cadastro
  /// ao receber a nova sessão: o perfil ainda é criado nessa tela (KAN-25).
  bool get cadastroEmAndamento => _cadastroEmAndamento;

  /// Cria a conta no Firebase Auth e já entra com ela. Erros do Auth
  /// (ex.: `email-already-in-use`) são repassados para a tela.
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    _cadastroEmAndamento = true;
    try {
      await _authService.signUp(email: email, password: password);
    } catch (_) {
      _cadastroEmAndamento = false;
      rethrow;
    }
  }

  /// Chamado pela tela de cadastro ao sair. Não altera a sessão.
  void encerrarCadastro() {
    _cadastroEmAndamento = false;
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _authService.signIn(
      email: email,
      password: password,
    );
  }

  /// Encerra a sessão no Firebase. A navegação para o Login é feita pelo
  /// AuthGate ao receber o novo estado de `authStateChanges`.
  /// Erros são repassados para a tela informar a falha ao usuário.
  Future<void> signOut() async {
    if (_isSigningOut) return;

    _isSigningOut = true;
    notifyListeners();

    try {
      await _authService.signOut();
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }
  }
}
