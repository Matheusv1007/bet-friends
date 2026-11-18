import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../data/firestore/partidas_repository.dart';
import '../../models/partida_model.dart';
import 'api_client.dart';

/// Serviço responsável por buscar os dados de partidas sincronizados no Firestore.
///
/// Diretrizes Arquiteturais (KAN-42, KAN-105; RF-007, RN-MAT-001, RN-MAT-005, RN-CACHE-001, RNF-005):
/// - O aplicativo Flutter consome dados sincronizados via Firestore (`matches`).
/// - Na integração direta via [ApiClient] (fluxo de contingência temporário KAN-105):
///   - Consulta utiliza filtros e escopo menor para evitar trazer a temporada inteira (reduz taxa).
///   - Fallback NUNCA repete chamada de forma inconveniente após HTTP 429 ou Timeout.
///   - Erro de limite de requisições (429) é tratado de forma amigável e compreensível.
class PartidasService {
  final PartidasRepository _repository;
  final ApiClient? client;

  PartidasService({
    PartidasRepository? repository,
    FirebaseFirestore? firestore,
    this.client,
    @Deprecated('Credenciais ficam exclusivamente no backend (RN-SEC-003, RNF-005).')
    String? apiKey,
  })  : _repository = repository ??
            FirestorePartidasRepository(firestore: firestore);

  PartidasRepository get repository => _repository;

  /// Converte exceções técnicas em mensagens amigáveis em português sem corpo JSON cru
  static String formatErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'resource-exhausted':
          return 'Limite de requisições atingido. Aguarde alguns instantes e tente novamente.';
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

  /// Busca as partidas do Brasileirão Série A 2026.
  /// Se um [ApiClient] foi configurado, executa consulta com proteção contra limite de taxa (KAN-105).
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    try {
      if (client != null) {
        return await _getPartidasFromClient(limit: limit);
      }
      return await _repository.getPartidas(limit: limit);
    } catch (e) {
      throw Exception(formatErrorMessage(e));
    }
  }

  /// Busca partidas diretamente via [ApiClient] aplicando as diretrizes de KAN-105:
  /// 1. Consulta com escopo/filtros reduzidos (não traz temporada inteira).
  /// 2. Fallback NÃO repete chamada após HTTP 429 ou Timeout.
  Future<List<PartidaModel>> _getPartidasFromClient({int limit = 15}) async {
    dynamic response;

    // 1. Escopo reduzido com filtros de status (evita carregar os 380 jogos da temporada inteira):
    try {
      response = await client!.get(
        '/competitions/BSA/matches?status=IN_PLAY,PAUSED,SCHEDULED,TIMED,FINISHED',
      );
    } catch (e) {
      // 2. Proteção contra repetição indevida (KAN-105):
      // Após 429 (Too Many Requests) ou Timeout, NÃO chama o fallback geral /matches!
      if (e is ApiException && e.statusCode == 429) {
        rethrow;
      }
      if (e is TimeoutException) {
        rethrow;
      }

      // Se falhou por outro motivo (ex.: erro de rota da competição), tenta fallback com escopo reduzido:
      response = await client!.get(
        '/matches?status=IN_PLAY,PAUSED,SCHEDULED',
      );
    }

    if (response != null && response['matches'] is List) {
      final List matchesList = response['matches'];
      final todasPartidas = matchesList
          .map((item) => PartidaModel.fromJson(item as Map<String, dynamic>))
          .toList();

      final aoVivo = [for (final p in todasPartidas) if (p.isAoVivo) p];
      final agendados = [for (final p in todasPartidas) if (p.isAgendado) p];
      final finalizados = [for (final p in todasPartidas) if (p.isFinalizado) p];

      final finalizadosRecentes = finalizados.reversed.take(6).toList();
      final agendadosProximos = agendados.take(10).toList();

      final resultadoFinal = [
        ...aoVivo,
        ...agendadosProximos,
        ...finalizadosRecentes,
      ];

      return resultadoFinal.take(limit).toList();
    }

    return [];
  }
}
