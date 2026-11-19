// ignore_for_file: subtype_of_sealed_class
import 'package:betfriends/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.passos);
  final List<String> passos;
  @override
  Future<void> signOut() async => passos.add('signOut');
}

class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.passos);
  final List<String> passos;
  @override
  Future<void> terminate() async => passos.add('terminate');
  @override
  Future<void> clearPersistence() async => passos.add('clearPersistence');
}

void main() {
  test('N-22: logout encerra cliente antes de apagar persistência', () async {
    final passos = <String>[];
    await AuthService(firebaseAuth: _Auth(passos), firestore: _Firestore(passos)).signOut();
    expect(passos, ['signOut', 'terminate', 'clearPersistence']);
  });
}
