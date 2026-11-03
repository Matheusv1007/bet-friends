import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/usuario_publico.dart';
import '../../services/functions/functions_service.dart';
import 'firestore_collections.dart';
import 'user_profile_repository.dart';

/// Contrato para busca pública de usuários (RF-004, RN-PROF-002, RN-FRD-002, RN-AUTH-006).
abstract interface class UserSearchRepository {
  /// Busca usuários cadastrados por username ou nome de exibição.
  ///
  /// - Exclui obrigatoriamente o [usuarioAtualUid] dos resultados (RN-FRD-002).
  /// - Retorna apenas objetos [UsuarioPublico] (RN-PROF-002, RN-AUTH-006).
  Future<List<UsuarioPublico>> buscarUsuarios(
    String termo, {
    required String usuarioAtualUid,
    int limite = 20,
  });
}

/// Implementação padrão recomendada via Callable Function do backend.
///
/// Permite que o backend execute a consulta segura contra a coleção `users`,
/// respeitando a Security Rule que proíbe `list` direto no Firestore e
/// garantindo que nenhum e-mail, saldo ou transação chegue ao app.
class FunctionsUserSearchRepository implements UserSearchRepository {
  final FunctionsService? _functionsSobDemanda;

  FunctionsUserSearchRepository({FunctionsService? functions})
      : _functionsSobDemanda = functions;

  FunctionsService get _functions => _functionsSobDemanda ?? FunctionsService();

  @override
  Future<List<UsuarioPublico>> buscarUsuarios(
    String termo, {
    required String usuarioAtualUid,
    int limite = 20,
  }) async {
    final cleanTerm = termo.trim();
    if (cleanTerm.isEmpty) {
      return const <UsuarioPublico>[];
    }

    try {
      final response = await _functions.call(CallableNames.searchUsers, {
        'query': cleanTerm,
        'limit': limite,
      });

      final rawList = response['users'];
      if (rawList is! List) return const <UsuarioPublico>[];

      return <UsuarioPublico>[
        for (final item in rawList)
          if (item is Map)
            UsuarioPublico.fromMap(Map<String, dynamic>.from(item)),
      ]
          .where((user) => user.userId != usuarioAtualUid)
          .toList(growable: false);
    } on FunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        throw const UserProfileException(
          UserProfileErrorCode.unauthenticated,
          'É necessário estar autenticado para buscar usuários.',
        );
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const UserProfileException(
          UserProfileErrorCode.unavailable,
          'Serviço de busca indisponível. Verifique sua conexão e tente novamente.',
        );
      }
      throw UserProfileException(
        UserProfileErrorCode.unknown,
        e.message,
      );
    } catch (_) {
      throw const UserProfileException(
        UserProfileErrorCode.unknown,
        'Não foi possível realizar a busca de usuários. Tente novamente.',
      );
    }
  }
}

/// Implementação direta no Firestore para ambientes de teste e emulador com regras abertas.
class FirestoreUserSearchRepository implements UserSearchRepository {
  final FirebaseFirestore? firestore;

  FirestoreUserSearchRepository({this.firestore});

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<UsuarioPublico>> buscarUsuarios(
    String termo, {
    required String usuarioAtualUid,
    int limite = 20,
  }) async {
    final cleanTerm = termo.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    if (cleanTerm.isEmpty) {
      return const <UsuarioPublico>[];
    }

    try {
      final snapshot = await _db
          .collection(FirestoreCollections.users)
          .orderBy('usernameNormalized')
          .startAt([cleanTerm])
          .endAt(['$cleanTerm\uf8ff'])
          .limit(limite)
          .get();

      return <UsuarioPublico>[
        for (final doc in snapshot.docs)
          if (doc.id != usuarioAtualUid)
            UsuarioPublico(
              userId: doc.id,
              displayName: doc.data()['displayName']?.toString() ?? 'Usuário',
              username: doc.data()['username']?.toString() ?? '',
            ),
      ];
    } on FirebaseException catch (e) {
      throw UserProfileException.fromFirebase(e);
    }
  }
}
