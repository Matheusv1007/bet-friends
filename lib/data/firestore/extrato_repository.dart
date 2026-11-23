import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/lancamento_do_extrato.dart';
import 'firestore_collections.dart';

enum ExtratoErrorCode {
  unauthenticated,
  permissionDenied,
  unavailable,

  /// Índice composto ausente no projeto (`firestore.indexes.json`).
  indiceAusente,
  unknown,
}

/// Erro de consulta ao extrato, sem detalhes internos do Firestore.
class ExtratoException implements Exception {
  final ExtratoErrorCode code;
  final String message;

  const ExtratoException(this.code, this.message);

  factory ExtratoException.fromFirebase(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const ExtratoException(
          ExtratoErrorCode.permissionDenied,
          'Sem permissão para consultar o extrato.',
        );
      case 'unauthenticated':
        return const ExtratoException(
          ExtratoErrorCode.unauthenticated,
          'É necessário estar autenticado.',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return const ExtratoException(
          ExtratoErrorCode.unavailable,
          'Serviço indisponível. Verifique sua conexão e tente novamente.',
        );
      case 'failed-precondition':
        return const ExtratoException(
          ExtratoErrorCode.indiceAusente,
          'O extrato depende de um índice ainda não publicado. Aguarde a configuração do ambiente.',
        );
      default:
        return const ExtratoException(
          ExtratoErrorCode.unknown,
          'Não foi possível consultar o extrato. Tente novamente.',
        );
    }
  }

  @override
  String toString() => 'ExtratoException(${code.name}): $message';
}

/// Posição opaca para buscar a página seguinte.
class CursorDoExtrato {
  final DocumentSnapshot<Map<String, dynamic>> _documento;

  const CursorDoExtrato._(this._documento);
}

class PaginaDoExtrato {
  /// Do lançamento mais recente para o mais antigo.
  final List<LancamentoDoExtrato> itens;

  /// Documentos fora do contrato ou de outro usuário. Não entram
  /// em [itens] nem interrompem a consulta, e nada é corrigido.
  final int ignorados;

  /// `true` quando o servidor não confirmou o dado, por falta de conexão.
  /// Nesse caso, uma página vazia não significa "sem extrato".
  final bool doCache;

  final bool temMais;
  final CursorDoExtrato? proximoCursor;

  const PaginaDoExtrato({
    required this.itens,
    required this.ignorados,
    required this.doCache,
    required this.temMais,
    required this.proximoCursor,
  });
}

abstract interface class ExtratoRepository {
  Future<PaginaDoExtrato> buscar(String uid, {int limite, CursorDoExtrato? cursor});
}

/// Consulta o ledger somente do dono autenticado (RF-019). O índice está em
/// `firestore.indexes.json`. O desempate por ID mantém a ordem estável e evita
/// repetir ou pular documentos na paginação.
class FirestoreExtratoRepository implements ExtratoRepository {
  static const limitePadrao = 20;
  static const limiteMaximo = 100;

  final FirebaseFirestore _firestore;

  FirestoreExtratoRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<PaginaDoExtrato> buscar(
    String uid, {
    int limite = limitePadrao,
    CursorDoExtrato? cursor,
  }) async {
    if (limite < 1 || limite > limiteMaximo) {
      throw ArgumentError.value(limite, 'limite', 'Use de 1 a $limiteMaximo.');
    }

    var consulta = _firestore
        .collection(FirestoreCollections.betCoinTransactions)
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        // Um a mais, para saber se existe outra página
        .limit(limite + 1);
    if (cursor != null) consulta = consulta.startAfterDocument(cursor._documento);

    final QuerySnapshot<Map<String, dynamic>> resposta;
    try {
      resposta = await consulta.get();
    } on FirebaseException catch (e) {
      throw ExtratoException.fromFirebase(e);
    }

    final temMais = resposta.docs.length > limite;
    final docs = temMais ? resposta.docs.sublist(0, limite) : resposta.docs;
    final itens = [
      for (final doc in docs) _lerDoUsuario(doc, uid),
    ].whereType<LancamentoDoExtrato>().toList(growable: false);

    return PaginaDoExtrato(
      itens: itens,
      ignorados: docs.length - itens.length,
      doCache: resposta.metadata.isFromCache,
      temMais: temMais,
      proximoCursor: temMais ? CursorDoExtrato._(docs.last) : null,
    );
  }

  /// `null` se o documento estiver fora do contrato ou de outro usuário.
  LancamentoDoExtrato? _lerDoUsuario(QueryDocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    try {
      final desafio = LancamentoDoExtrato.fromMap(doc.id, doc.data());
      return desafio.userId == uid ? desafio : null;
    } on FormatException {
      return null;
    }
  }
}
