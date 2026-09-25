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

  /// Busca as partidas na API com ordenação inteligente e limite configurável
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    try {
      dynamic response;

      // 1. Busca as partidas reais do Brasileirão Série A (BSA)
      try {
        response = await _client.get('/competitions/BSA/matches');
      } catch (_) {
        // Fallback para endpoint geral de partidas caso o endpoint específico falhe
        response = await _client.get('/matches');
      }

      if (response != null && response['matches'] is List) {
        final List matchesList = response['matches'];
        final todasPartidas = matchesList
            .map((item) => PartidaModel.fromJson(item as Map<String, dynamic>))
            .toList();

        // Separação em categorias:
        final aoVivo = <PartidaModel>[];
        final agendados = <PartidaModel>[];
        final finalizados = <PartidaModel>[];

        for (final p in todasPartidas) {
          if (p.isAoVivo) {
            aoVivo.add(p);
          } else if (p.isAgendado) {
            agendados.add(p);
          } else if (p.isFinalizado) {
            finalizados.add(p);
          }
        }

        // Ordenação inteligente:
        // 1º Jogos Ao Vivo
        // 2º Próximos Jogos Agendados para desafiar/apostar
        // 3º Jogos Finalizados mais recentes
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
    } catch (e) {
      throw Exception('Falha ao obter partidas da API Football-Data: $e');
    }
  }
}
