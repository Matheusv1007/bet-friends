import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  bool _isSigningOut = false;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  User? get currentUser => _authService.currentUser;

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  bool get isSigningOut => _isSigningOut;

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
