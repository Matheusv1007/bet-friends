import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/campeonato.dart';
import '../../models/partida_model.dart';
import '../../services/registro_de_erros.dart';
import 'firestore_collections.dart';

/// Contrato para obtenção de partidas da aplicação (KAN-42; RF-007, RN-MAT-001).
abstract interface class PartidasRepository {
  /// Retorna as partidas dos campeonatos suportados ([Campeonato.suportados])
  /// sincronizadas no backend/Firestore, ordenadas por horário (`startsAtUtc`).
  ///
  /// Cada liga entra com as próximas partidas e as mais recentes, e o conjunto
  /// completo é devolvido (sem corte global). Sem partidas, a lista é vazia.
  ///
  /// O aplicativo Flutter NÃO chama a Football-Data.org diretamente (RNF-005).
  /// Na indisponibilidade do provedor externo, dados previamente sincronizados continuam disponíveis (RN-CACHE-003).
  Future<List<PartidaModel>> getPartidas();
}

/// Implementação do repositório consumindo a coleção `matches` do Cloud Firestore (docs/firestore-schema.md §3.4).
class FirestorePartidasRepository implements PartidasRepository {
  final FirebaseFirestore? firestore;

  FirestorePartidasRepository({this.firestore});

  /// Partidas futuras (a partir da janela) buscadas por liga.
  static const int partidasFuturasPorLiga = 12;

  /// Partidas já iniciadas, anteriores a agora, buscadas por liga além da janela.
  static const int partidasRecentesPorLiga = 3;

  /// Quanto a janela recua no passado para incluir jogos ao vivo e finalizados recentes.
  static const Duration _recuoDaJanela = Duration(days: 3);

  /// Folga para os jogos do recuo (uma rodada completa de 20 times) não
  /// ocuparem a cota das [partidasFuturasPorLiga] na consulta da janela.
  static const int _folgaDoRecuoPorLiga = 10;

  /// Limite da consulta da janela: recuo mais partidas futuras, por liga.
  static const int limiteDaJanelaPorLiga =
      partidasFuturasPorLiga + _folgaDoRecuoPorLiga;

  // Resolvido sob demanda para permitir testes sem Firebase inicializado
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  /// Busca uma partida fora da janela da Home para descrever desafios antigos.
  Future<PartidaModel?> buscarPorId(String id) async {
    final doc = await _db.collection(FirestoreCollections.matches).doc(id).get();
    return doc.exists ? PartidaModel.fromFirestoreMap(doc.data()!, doc.id) : null;
  }

  @override
  Future<List<PartidaModel>> getPartidas() async {
    final agora = DateTime.now().toUtc();
    final inicioDaJanela = Timestamp.fromDate(
      agora.subtract(_recuoDaJanela),
    );
    final limiteAgora = Timestamp.fromDate(agora);

    // Cada liga é consultada à parte, com limite próprio: uma liga com muitas
    // partidas no calendário não consome a cota das outras.
    Future<List<QuerySnapshot<Map<String, dynamic>>>> consultarLiga(
      String codigo,
      Source source,
    ) {
      final base = _db.collection(FirestoreCollections.matches)
          .where('competitionCode', isEqualTo: codigo);
      final janela = base
          .where('startsAtUtc', isGreaterThanOrEqualTo: inicioDaJanela)
          .orderBy('startsAtUtc')
          .limit(limiteDaJanelaPorLiga);
      final recentes = base
          .where('startsAtUtc', isLessThan: limiteAgora)
          .orderBy('startsAtUtc', descending: true)
          .limit(partidasRecentesPorLiga);
      return Future.wait([
        janela.get(GetOptions(source: source)),
        recentes.get(GetOptions(source: source)),
      ]);
    }

    Future<List<PartidaModel>> consultar(Source source) async {
      // Qualquer consulta que falhe derruba a busca inteira: nunca devolve
      // uma lista parcial sem avisar que faltam ligas.
      final porLiga = await Future.wait([
        for (final codigo in Campeonato.codigosSuportados)
          consultarLiga(codigo, source),
      ]);
      return {
        for (final snapshots in porLiga)
          for (final snapshot in snapshots)
            for (final doc in snapshot.docs)
              doc.id: PartidaModel.fromFirestoreMap(doc.data(), doc.id),
      }.values.toList()
        ..sort((a, b) => a.startsAtUtc!.compareTo(b.startsAtUtc!));
    }

    try {
      return await consultar(Source.serverAndCache);
    } catch (e, s) {
      registrarErro('carregar partidas antes de consultar o cache', e, s);
      // 2. Resiliência (RN-CACHE-001, RN-CACHE-003): em caso de falha de conexão ou indisponibilidade,
      // busca do cache local persistente do Firestore
      try {
        final partidas = await consultar(Source.cache);
        if (partidas.isNotEmpty) return partidas;
      } catch (erroCache, pilhaCache) {
        registrarErro('carregar partidas do cache local', erroCache, pilhaCache);
      }
      rethrow;
    }
  }
}
