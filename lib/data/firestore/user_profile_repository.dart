import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_profile.dart';
import 'firestore_collections.dart';
import 'gravacao_no_servidor.dart';

enum UserProfileErrorCode {
  unauthenticated,
  alreadyExists,
  permissionDenied,
  unavailable,
  invalidData,
  unknown,
}

/// Erro de acesso ao perfil, sem detalhes internos do Firestore.
class UserProfileException implements Exception {
  final UserProfileErrorCode code;
  final String message;

  const UserProfileException(this.code, this.message);

  /// Traduz os códigos do Firestore para os do perfil.
  factory UserProfileException.fromFirebase(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const UserProfileException(
          UserProfileErrorCode.permissionDenied,
          'Sem permissão para acessar o perfil.',
        );
      case 'unauthenticated':
        return const UserProfileException(
          UserProfileErrorCode.unauthenticated,
          'É necessário estar autenticado.',
        );
      case 'already-exists':
        return const UserProfileException(
          UserProfileErrorCode.alreadyExists,
          'O perfil deste usuário já existe.',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return const UserProfileException(
          UserProfileErrorCode.unavailable,
          'Serviço indisponível. Verifique sua conexão e tente novamente.',
        );
      default:
        return const UserProfileException(
          UserProfileErrorCode.unknown,
          'Não foi possível acessar o perfil. Tente novamente.',
        );
    }
  }

  @override
  String toString() => 'UserProfileException(${code.name}): $message';
}

/// Perfil emitido por [UserProfileRepository.observarPorUid] e a origem do dado.
class PerfilObservado {
  /// `null` enquanto o documento não existir.
  final UserProfile? perfil;

  /// `true` quando o servidor não confirmou o dado, por falta de conexão: é o
  /// último perfil conhecido neste aparelho e pode estar desatualizado.
  final bool doCache;

  const PerfilObservado(this.perfil, {this.doCache = false});
}

/// Acesso ao documento `users/{uid}`.
abstract interface class UserProfileRepository {
  /// Retorna `null` quando o documento não existe.
  Future<UserProfile?> buscarPorUid(String uid);

  /// Emite de novo quando o dado passa a vir do cache (sem conexão) ou volta
  /// a ser confirmado pelo servidor.
  Stream<PerfilObservado> observarPorUid(String uid);

  /// Cria `users/{perfil.uid}`. Falha com [UserProfileErrorCode.alreadyExists]
  /// se o documento já existir: o perfil nunca é sobrescrito.
  Future<void> criar(UserProfile perfil);

  /// Altera somente `displayName` e `updatedAt`, os únicos campos que o app
  /// pode gravar em `users/{uid}` (firestore.rules). UID, username, e-mail e
  /// saldos não mudam.
  Future<void> atualizarDisplayName(String uid, String displayName);
}

class FirestoreUserProfileRepository implements UserProfileRepository {
  final FirebaseFirestore? firestore;

  FirestoreUserProfileRepository({this.firestore});

  // Resolvido sob demanda para permitir testes sem Firebase inicializado
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(FirestoreCollections.users).doc(uid);

  @override
  Future<UserProfile?> buscarPorUid(String uid) async {
    _validarUid(uid);
    try {
      final snapshot = await _doc(uid).get();
      return _converter(snapshot);
    } on FirebaseException catch (e) {
      throw UserProfileException.fromFirebase(e);
    }
  }

  @override
  Stream<PerfilObservado> observarPorUid(String uid) {
    _validarUid(uid);
    // Com as mudanças de metadados, a perda e o retorno da conexão também emitem
    return _doc(uid).snapshots(includeMetadataChanges: true).map((snapshot) {
      // Sem conexão, o listener emite o cache local; a ausência ali não prova
      // que o perfil não existe no servidor. Ao reconectar, chega o snapshot real.
      if (!snapshot.exists && snapshot.metadata.isFromCache) {
        throw const UserProfileException(
          UserProfileErrorCode.unavailable,
          'Sem conexão para carregar o perfil.',
        );
      }
      return PerfilObservado(
        _converter(snapshot),
        doCache: snapshot.metadata.isFromCache,
      );
    }).handleError(
      (Object e) => throw UserProfileException.fromFirebase(e as FirebaseException),
      test: (e) => e is FirebaseException,
    );
  }

  @override
  Future<void> criar(UserProfile perfil) async {
    _validarUid(perfil.uid);
    final ref = _doc(perfil.uid);
    try {
      await gravarNoServidor(_db, (transaction) async {
        final atual = await transaction.get(ref);
        if (atual.exists) {
          throw const UserProfileException(
            UserProfileErrorCode.alreadyExists,
            'O perfil deste usuário já existe.',
          );
        }
        transaction.set(ref, {
          ...perfil.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw UserProfileException.fromFirebase(e);
    }
  }

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {
    _validarUid(uid);
    final ref = _doc(uid);
    try {
      // Sem conexão falha com unavailable e nada fica na fila (gravarNoServidor)
      await gravarNoServidor(_db, (transaction) async {
        await transaction.get(ref);
        transaction.update(ref, {
          'displayName': displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw UserProfileException.fromFirebase(e);
    }
  }

  UserProfile? _converter(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    try {
      return UserProfile.fromMap(snapshot.id, data);
    } on FormatException catch (e) {
      throw UserProfileException(UserProfileErrorCode.invalidData, e.message);
    }
  }

  static void _validarUid(String uid) {
    if (uid.trim().isEmpty) {
      throw const UserProfileException(
        UserProfileErrorCode.invalidData,
        'UID do perfil vazio.',
      );
    }
  }
}
