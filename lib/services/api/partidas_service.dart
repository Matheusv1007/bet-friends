import '../../models/partida_model.dart';
import 'api_client.dart';

/// Serviço responsável por buscar os dados de partidas na API
class PartidasService {
  final ApiClient _client;

  // Chave de API configurada
  static const String apiKey = '9294186c0e964542a6661b69665bd315';

  PartidasService({ApiClient? client})
    : _client =
          client ??
          ApiClient(
            baseUrl: 'https://api.football-data.org/v4',
            defaultHeaders: {'X-Auth-Token': apiKey},
          );

  ApiClient get client => _client;

  /// Busca as partidas na API com limite configurável (padrão: 5 jogos)
  Future<List<PartidaModel>> getPartidas({int limit = 5}) async {
    try {
      // Pega a data de hoje e dos próximos 7 dias para ter jogos suficientes
      final now = DateTime.now();
      final dateFrom =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final future = now.add(const Duration(days: 7));
      final dateTo =
          '${future.year}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}';

      // Faz a requisição buscando os jogos da semana
      final response = await _client.get(
        '/matches?dateFrom=$dateFrom&dateTo=$dateTo',
      );

      if (response != null && response['matches'] is List) {
        final List matchesList = response['matches'];

        // Pega exatamente a quantidade desejada (ex: 5 jogos)
        return matchesList
            .take(4)
            .map((item) => PartidaModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      throw Exception('Falha ao obter partidas da API Football-Data: $e');
    }
  }
}
