import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth? firebaseAuth;

  final FirebaseFirestore? firestore;

  AuthService({this.firebaseAuth, this.firestore});

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

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
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