import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/desafio_encerrado.dart';
import 'firestore_collections.dart';

enum HistoricoErrorCode {
  unauthenticated,
  permissionDenied,
  unavailable,

  /// Índice composto ausente no projeto (`firestore.indexes.json`).
  indiceAusente,
  unknown,
}

/// Erro de consulta ao histórico, sem detalhes internos do Firestore.
class HistoricoException implements Exception {
  final HistoricoErrorCode code;
  final String message;

  const HistoricoException(this.code, this.message);

  factory HistoricoException.fromFirebase(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const HistoricoException(
          HistoricoErrorCode.permissionDenied,
          'Sem permissão para consultar o histórico.',
        );
      case 'unauthenticated':
        return const HistoricoException(
          HistoricoErrorCode.unauthenticated,
          'É necessário estar autenticado.',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return const HistoricoException(
          HistoricoErrorCode.unavailable,
          'Serviço indisponível. Verifique sua conexão e tente novamente.',
        );
      case 'failed-precondition':
        return const HistoricoException(
          HistoricoErrorCode.indiceAusente,
          'O histórico ainda não está disponível neste ambiente.',
        );
      default:
        return const HistoricoException(
          HistoricoErrorCode.unknown,
          'Não foi possível consultar o histórico. Tente novamente.',
        );
    }
  }

  @override
  String toString() => 'HistoricoException(${code.name}): $message';
}

/// Posição opaca para buscar a página seguinte.
class CursorDoHistorico {
  final DocumentSnapshot<Map<String, dynamic>> _documento;

  const CursorDoHistorico._(this._documento);
}

class PaginaDoHistorico {
  /// Do encerramento mais recente para o mais antigo.
  final List<DesafioEncerrado> itens;

  /// Documentos fora do contrato ou sem o usuário como participante. Não entram
  /// em [itens] nem interrompem a consulta, e nada é corrigido.
  final int ignorados;

  /// `true` quando o servidor não confirmou o dado, por falta de conexão.
  /// Nesse caso, uma página vazia não significa "sem histórico".
  final bool doCache;

  final bool temMais;
  final CursorDoHistorico? proximoCursor;

  const PaginaDoHistorico({
    required this.itens,
    required this.ignorados,
    required this.doCache,
    required this.temMais,
    required this.proximoCursor,
  });
}

abstract interface class HistoricoDeDesafiosRepository {
  Future<PaginaDoHistorico> buscar(String uid, {int limite, CursorDoHistorico? cursor});
}

/// Consulta `challenges` do cliente (KAN-89). As Security Rules só permitem a
/// consulta filtrada pelo próprio UID em `participants`, e o índice está em
/// `firestore.indexes.json`. O desempate por ID mantém a ordem estável e evita
/// repetir ou pular documentos na paginação.
class FirestoreHistoricoDeDesafiosRepository implements HistoricoDeDesafiosRepository {
  static const limitePadrao = 20;
  static const limiteMaximo = 100;

  final FirebaseFirestore _firestore;

  FirestoreHistoricoDeDesafiosRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<PaginaDoHistorico> buscar(
    String uid, {
    int limite = limitePadrao,
    CursorDoHistorico? cursor,
  }) async {
    if (limite < 1 || limite > limiteMaximo) {
      throw ArgumentError.value(limite, 'limite', 'Use de 1 a $limiteMaximo.');
    }

    var consulta = _firestore
        .collection(FirestoreCollections.challenges)
        .where('participants', arrayContains: uid)
        .where('status', whereIn: [for (final s in StatusEncerrado.values) s.valor])
        .orderBy('finishedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        // Um a mais, para saber se existe outra página
        .limit(limite + 1);
    if (cursor != null) consulta = consulta.startAfterDocument(cursor._documento);

    final QuerySnapshot<Map<String, dynamic>> resposta;
    try {
      resposta = await consulta.get();
    } on FirebaseException catch (e) {
      throw HistoricoException.fromFirebase(e);
    }

    final temMais = resposta.docs.length > limite;
    final docs = temMais ? resposta.docs.sublist(0, limite) : resposta.docs;
    final itens = [
      for (final doc in docs) _lerDoUsuario(doc, uid),
    ].whereType<DesafioEncerrado>().toList(growable: false);

    return PaginaDoHistorico(
      itens: itens,
      ignorados: docs.length - itens.length,
      doCache: resposta.metadata.isFromCache,
      temMais: temMais,
      proximoCursor: temMais ? CursorDoHistorico._(docs.last) : null,
    );
  }

  /// `null` se o documento estiver fora do contrato ou sem o usuário como participante.
  DesafioEncerrado? _lerDoUsuario(QueryDocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    try {
      final desafio = DesafioEncerrado.fromMap(doc.id, doc.data());
      return desafio.temParticipante(uid) ? desafio : null;
    } on FormatException {
      return null;
    }
  }
}
