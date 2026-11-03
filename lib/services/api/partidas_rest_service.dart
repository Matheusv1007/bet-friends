import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/partida_model.dart';
import 'api_client.dart';

/// Serviço acadêmico responsável por demonstrar o consumo de API REST via HTTP GET.
///
/// Atividade Prática - Consumo de API REST GET:
/// - Consome um endpoint HTTP GET disponibilizado pelo próprio backend BetFriends.
/// - Converte a resposta JSON em objetos do domínio ([PartidaModel]).
/// - Trata falhas de comunicação sem travar a aplicação.
/// - Não chama o provedor externo Football-Data.org diretamente e não expõe credenciais (RN-SEC-003, RNF-004, RNF-013).
/// - Não substitui o Firebase SDK / Callable Functions como arquitetura principal do produto.
class PartidasRestService {
  final String baseUrl;
  final http.Client _httpClient;

  static const String defaultBaseUrl =
      'https://southamerica-east1-betfriends-unirv-2026.cloudfunctions.net';

  PartidasRestService({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = (baseUrl != null && baseUrl.isNotEmpty)
            ? baseUrl
            : defaultBaseUrl,
        _httpClient = httpClient ?? http.Client();

  /// Converte erros técnicos em mensagens amigáveis em português sem expor corpo JSON cru
  static String formatErrorMessage(Object error) {
    if (error is ApiException) {
      return error.friendlyMessage;
    }
    if (error is TimeoutException) {
      return 'Tempo de conexão esgotado ao buscar partidas via REST. Verifique sua conexão com a internet.';
    }
    if (error is SocketException || error is http.ClientException) {
      return 'Sem conexão com o servidor REST. Verifique sua rede e tente novamente.';
    }
    if (error is FormatException) {
      return 'Formato de resposta inválido retornado pelo endpoint REST.';
    }
    final errStr = error.toString();
    if (errStr.startsWith('Exception: ')) {
      return errStr.substring(11);
    }
    return 'Não foi possível carregar as partidas via REST no momento. Tente novamente.';
  }

  /// Realiza requisição HTTP GET para o endpoint REST de partidas
  Future<List<PartidaModel>> getPartidasRest({
    int limit = 15,
    String competition = 'BSA',
  }) async {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$cleanBase/getMatchesRest').replace(
      queryParameters: {
        'limit': limit.toString(),
        'competition': competition,
      },
    );

    try {
      final response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String bodyString;
        try {
          bodyString = utf8.decode(response.bodyBytes);
        } catch (_) {
          bodyString = response.body;
        }

        if (bodyString.trim().isEmpty) {
          return const <PartidaModel>[];
        }

        final decoded = jsonDecode(bodyString);
        final List<dynamic> rawMatches;

        if (decoded is Map && decoded['matches'] is List) {
          rawMatches = decoded['matches'] as List<dynamic>;
        } else if (decoded is List) {
          rawMatches = decoded;
        } else {
          return const <PartidaModel>[];
        }

        return <PartidaModel>[
          for (final item in rawMatches)
            if (item is Map)
              PartidaModel.fromJson(Map<String, dynamic>.from(item)),
        ];
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          rawBody: response.body,
        );
      }
    } catch (e) {
      throw Exception(formatErrorMessage(e));
    }
  }
}
