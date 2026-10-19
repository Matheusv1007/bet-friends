import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente base para gerenciar requisições HTTP (GET, POST, etc.)
class ApiClient {
  final String baseUrl;
  final Map<String, String>? defaultHeaders;
  final http.Client? httpClient;

  ApiClient({
    this.baseUrl = 'https://api.football-data.org/v4/matches',
    this.defaultHeaders,
    this.httpClient,
  });

  http.Client get _client => httpClient ?? http.Client();

  /// Realiza uma requisição GET genérica
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final response = await _client
        .get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            ...?defaultHeaders,
            ...?headers,
          },
        )
        .timeout(const Duration(seconds: 15));

    return _handleResponse(response);
  }

  /// Realiza uma requisição POST genérica
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            ...?defaultHeaders,
            ...?headers,
          },
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 15));

    return _handleResponse(response);
  }

  /// Trata status HTTP e converte JSON para Map ou List
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        rawBody: response.body,
      );
    }
  }
}

/// Exceção personalizada para erros de API com mensagens amigáveis em português
class ApiException implements Exception {
  final int statusCode;
  final String? rawBody;
  final String? customMessage;

  ApiException({
    required this.statusCode,
    this.rawBody,
    this.customMessage,
  });

  /// Mensagem amigável para exibição ao usuário final (sem dump de JSON/HTTP cru)
  String get friendlyMessage {
    if (customMessage != null && customMessage!.isNotEmpty) {
      return customMessage!;
    }
    switch (statusCode) {
      case 400:
        return 'Requisição inválida. Verifique os dados e tente novamente.';
      case 401:
      case 403:
        return 'Não foi possível autorizar o acesso ao serviço de partidas.';
      case 404:
        return 'Dados de partidas não encontrados no servidor.';
      case 429:
        return 'Limite de requisições atingido. Aguarde alguns instantes e tente novamente.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'O servidor de partidas está temporariamente indisponível. Tente novamente mais tarde.';
      default:
        return 'Falha na comunicação com o servidor ($statusCode). Tente novamente.';
    }
  }

  @override
  String toString() => friendlyMessage;
}
