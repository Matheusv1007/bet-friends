import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/partida_model.dart';
import 'firestore_collections.dart';

/// Contrato para obtenção de partidas da aplicação (KAN-42; RF-007, RN-MAT-001).
abstract interface class PartidasRepository {
  /// Retorna a lista de partidas do Brasileirão Série A 2026 sincronizadas no backend/Firestore.
  ///
  /// O aplicativo Flutter NÃO chama a Football-Data.org diretamente (RNF-005).
  /// Na indisponibilidade do provedor externo, dados previamente sincronizados continuam disponíveis (RN-CACHE-003).
  Future<List<PartidaModel>> getPartidas({int limit = 15});
}

/// Implementação do repositório consumindo a coleção `matches` do Cloud Firestore (docs/firestore-schema.md §3.4).
class FirestorePartidasRepository implements PartidasRepository {
  final FirebaseFirestore? firestore;

  FirestorePartidasRepository({this.firestore});

  // Resolvido sob demanda para permitir testes sem Firebase inicializado
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    try {
      // 1. Busca partidas do Brasileirão Série A (BSA) sincronizadas pelo backend
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _db
            .collection(FirestoreCollections.matches)
            .where('competitionCode', isEqualTo: 'BSA')
            .orderBy('startsAtUtc', descending: false)
            .limit(limit * 2)
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        // Fallback caso a ordenação/índice ainda não esteja pronto ou sem filtro de competição
        snapshot = await _db
            .collection(FirestoreCollections.matches)
            .limit(limit * 2)
            .get(const GetOptions(source: Source.serverAndCache));
      }

      final docs = snapshot.docs;
      final partidas = docs
          .map((d) => PartidaModel.fromFirestoreMap(d.data(), d.id))
          .toList();

      return _ordenarPartidas(partidas, limit);
    } catch (e) {
      // 2. Resiliência (RN-CACHE-001, RN-CACHE-003): em caso de falha de conexão ou indisponibilidade,
      // busca do cache local persistente do Firestore
      try {
        final cacheSnapshot = await _db
            .collection(FirestoreCollections.matches)
            .limit(limit)
            .get(const GetOptions(source: Source.cache));
        if (cacheSnapshot.docs.isNotEmpty) {
          final partidasCache = cacheSnapshot.docs
              .map((d) => PartidaModel.fromFirestoreMap(d.data(), d.id))
              .toList();
          return _ordenarPartidas(partidasCache, limit);
        }
      } catch (_) {
        // Cache local não disponível
      }
      rethrow;
    }
  }

  /// Ordenação inteligente sem invocar métodos de escrita sintéticos (RNF-009):
  /// 1º Jogos Ao Vivo / Em Andamento
  /// 2º Próximos Jogos Agendados (futuros elegíveis para desafio)
  /// 3º Jogos Finalizados Recentes
  List<PartidaModel> _ordenarPartidas(List<PartidaModel> todas, int limit) {
    final aoVivo = [for (final p in todas) if (p.isAoVivo) p];
    final agendados = [for (final p in todas) if (p.isAgendado) p];
    final finalizados = [for (final p in todas) if (p.isFinalizado) p];
    final outros = [
      for (final p in todas)
        if (!p.isAoVivo && !p.isAgendado && !p.isFinalizado) p
    ];

    final resultado = [
      ...aoVivo,
      ...agendados,
      ...finalizados.reversed,
      ...outros,
    ];

    return resultado.take(limit).toList();
  }
}
