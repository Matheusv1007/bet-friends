import '../../models/partida_model.dart';
import 'api_client.dart';

/// Serviço responsável por buscar os dados de partidas na API em tempo real
class PartidasService {
  final ApiClient _client;

  // Chave de API Football-Data configurada
  static const String apiKey = '9294186c0e964542a6661b69665bd315';

  PartidasService({ApiClient? client})
      : _client = client ??
            ApiClient(
              baseUrl: 'https://api.football-data.org/v4',
              defaultHeaders: {'X-Auth-Token': apiKey},
            );

  ApiClient get client => _client;

  /// Busca as partidas na API com ordenação e limite configurável
  Future<List<PartidaModel>> getPartidas({int limit = 10}) async {
    try {
      final now = DateTime.now();

      // Busca um intervalo de datas (2 dias atrás até 7 dias adiante) para capturar:
      // 1. Jogos finalizados recentes
      // 2. Jogos em andamento / ao vivo
      // 3. Próximos jogos agendados
      final past = now.subtract(const Duration(days: 2));
      final dateFrom =
          '${past.year}-${past.month.toString().padLeft(2, '0')}-${past.day.toString().padLeft(2, '0')}';
      final future = now.add(const Duration(days: 7));
      final dateTo =
          '${future.year}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}';

      final response = await _client.get(
        '/matches?dateFrom=$dateFrom&dateTo=$dateTo',
      );

      if (response != null && response['matches'] is List) {
        final List matchesList = response['matches'];
        final partidas = matchesList
            .map((item) => PartidaModel.fromJson(item as Map<String, dynamic>))
            .toList();

        // Ordenação inteligente:
        // 1º Jogos Ao Vivo / Em Andamento
        // 2º Próximos Jogos
        // 3º Jogos Finalizados
        partidas.sort((a, b) {
          if (a.isAoVivo && !b.isAoVivo) return -1;
          if (!a.isAoVivo && b.isAoVivo) return 1;
          if (a.isAgendado && b.isFinalizado) return -1;
          if (a.isFinalizado && b.isAgendado) return 1;
          return 0;
        });

        return partidas.take(limit).toList();
      }

      return [];
    } catch (e) {
      throw Exception('Falha ao obter partidas da API Football-Data: $e');
    }
  }
}
