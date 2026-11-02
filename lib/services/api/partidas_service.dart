import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../data/firestore/partidas_repository.dart';
import '../../models/partida_model.dart';
import 'api_client.dart';

/// Serviço responsável por buscar os dados de partidas sincronizados no Firestore.
///
/// Diretrizes Arquiteturais (KAN-42; RF-007, RN-MAT-001, RN-MAT-005, RN-CACHE-001, RNF-005):
/// - O aplicativo Flutter NÃO chama a Football-Data.org diretamente (RNF-005).
/// - Todas as partidas são consumidas do backend/Firestore (coleção `matches`).
/// - Na indisponibilidade do provedor externo, dados previamente sincronizados continuam disponíveis (RN-CACHE-003).
class PartidasService {
  final PartidasRepository _repository;

  PartidasService({
    PartidasRepository? repository,
    FirebaseFirestore? firestore,
    @Deprecated('Flutter não acessa Football-Data.org diretamente (RNF-005). Usar Firestore.')
    ApiClient? client,
    @Deprecated('Credenciais ficam exclusivamente no backend (RN-SEC-003, RNF-005).')
    String? apiKey,
  }) : _repository = repository ??
            FirestorePartidasRepository(firestore: firestore);

  PartidasRepository get repository => _repository;

  /// Converte exceções técnicas em mensagens amigáveis em português sem corpo JSON cru
  static String formatErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Serviço de partidas temporariamente indisponível. Verifique sua conexão e tente novamente.';
        case 'permission-denied':
          return 'Não foi possível autorizar o acesso ao serviço de partidas.';
        default:
          return 'Não foi possível carregar as partidas no momento. Tente novamente.';
      }
    }
    if (error is ApiException) {
      return error.friendlyMessage;
    }
    if (error is TimeoutException) {
      return 'Tempo de conexão esgotado ao buscar partidas. Verifique sua conexão com a internet.';
    }
    if (error is SocketException || error is http.ClientException) {
      return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
    }
    if (error is FormatException) {
      return 'Erro ao processar os dados recebidos das partidas. Tente novamente.';
    }
    final errStr = error.toString();
    if (errStr.startsWith('Exception: ')) {
      return errStr.substring(11);
    }
    return 'Não foi possível carregar as partidas no momento. Tente novamente.';
  }

  /// Busca as partidas do Brasileirão Série A 2026 sincronizadas no Firestore
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    try {
      return await _repository.getPartidas(limit: limit);
    } catch (e) {
      throw Exception(formatErrorMessage(e));
    }
  }
}
