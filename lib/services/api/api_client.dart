import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente base para gerenciar requisições HTTP (GET, POST, etc.)
class ApiClient {
  // Altere para a URL base da sua API real
  // Exemplo: 'https://api.football-data.org/v4' ou sua API própria
  final String baseUrl;
  final Map<String, String>? defaultHeaders;

  ApiClient({
    this.baseUrl = 'https://api.football-data.org/v4/matches',
    this.defaultHeaders,
  });

  /// Realiza uma requisição GET genérica
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final response = await http
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

    final response = await http
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
        message:
            'Erro na requisição: ${response.statusCode} - ${response.body}',
      );
    }
  }
}

/// Exceção personalizada para erros de API
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException ($statusCode): $message';
}
