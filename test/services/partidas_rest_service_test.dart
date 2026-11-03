import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:betfriends/services/api/partidas_rest_service.dart';

void main() {
  group('PartidasRestService - Consumo REST GET Acadêmico (RF-007, RF-008, RN-SEC-003, RNF-004, RNF-013)', () {
    test('realiza requisição GET para /getMatchesRest e converte JSON para List<PartidaModel>', () async {
      final mockData = {
        'success': true,
        'total': 2,
        'competition': 'BSA',
        'matches': [
          {
            'id': 'match-101',
            'competitionCode': 'BSA',
            'season': 2026,
            'matchday': 1,
            'startsAtUtc': '2026-06-01T19:00:00.000Z',
            'status': 'AGENDADA',
            'homeTeam': {'name': 'Flamengo', 'shortName': 'Flamengo'},
            'awayTeam': {'name': 'Palmeiras', 'shortName': 'Palmeiras'},
            'homeScore': null,
            'awayScore': null,
            'result': null,
          },
          {
            'id': 'match-102',
            'competitionCode': 'BSA',
            'season': 2026,
            'matchday': 1,
            'startsAtUtc': '2026-06-01T21:30:00.000Z',
            'status': 'FINALIZADA',
            'homeTeam': {'name': 'Corinthians', 'shortName': 'Corinthians'},
            'awayTeam': {'name': 'São Paulo', 'shortName': 'São Paulo'},
            'homeScore': 2,
            'awayScore': 1,
            'result': 'HOME_TEAM',
          },
        ],
      };

      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, contains('getMatchesRest'));
        expect(request.url.queryParameters['limit'], '15');
        expect(request.url.queryParameters['competition'], 'BSA');

        // Não chama a Football-Data.org
        expect(request.url.host, isNot(contains('football-data.org')));

        // Não expõe nenhum token de provedor externo nos headers
        expect(request.headers.containsKey('X-Auth-Token'), isFalse);
        expect(request.headers.containsKey('Authorization'), isFalse);

        return http.Response(
          jsonEncode(mockData),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = PartidasRestService(
        baseUrl: 'https://southamerica-east1-betfriends.cloudfunctions.net',
        httpClient: client,
      );

      final partidas = await service.getPartidasRest();

      expect(partidas.length, 2);
      expect(partidas[0].id, 'match-101');
      expect(partidas[0].timeMandante, 'Flamengo');
      expect(partidas[0].timeVisitante, 'Palmeiras');
      expect(partidas[0].status, 'PRÓXIMO JOGO');

      expect(partidas[1].id, 'match-102');
      expect(partidas[1].timeMandante, 'Corinthians');
      expect(partidas[1].timeVisitante, 'São Paulo');
      expect(partidas[1].golsMandante, 2);
      expect(partidas[1].golsVisitante, 1);
      expect(partidas[1].status, 'FINALIZADO');
    });

    test('trata resposta HTTP com lista direta de partidas', () async {
      final mockData = [
        {
          'id': 'match-201',
          'timeMandante': 'Grêmio',
          'timeVisitante': 'Internacional',
          'status': 'EM_ANDAMENTO',
          'startsAtUtc': '2026-06-02T19:00:00.000Z',
        }
      ];

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockData), 200);
      });

      final service = PartidasRestService(
        baseUrl: 'http://localhost:5001',
        httpClient: client,
      );

      final partidas = await service.getPartidasRest();
      expect(partidas.length, 1);
      expect(partidas.first.timeMandante, 'Grêmio');
      expect(partidas.first.timeVisitante, 'Internacional');
      expect(partidas.first.status, 'EM ANDAMENTO');
    });

    test('trata erro 500 do servidor sem travar e formata mensagem amigável', () async {
      final client = MockClient((request) async {
        return http.Response('{"error": "Internal Server Error"}', 500);
      });

      final service = PartidasRestService(httpClient: client);

      expect(
        () => service.getPartidasRest(),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('temporariamente indisponível') &&
              !e.toString().contains('Internal Server Error')),
        ),
      );
    });

    test('trata erro 405 Method Not Allowed sem travar', () async {
      final client = MockClient((request) async {
        return http.Response('{"error": "Método não permitido"}', 405);
      });

      final service = PartidasRestService(httpClient: client);

      expect(
        () => service.getPartidasRest(),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('405')),
        ),
      );
    });

    test('trata timeout na comunicação HTTP sem travar', () async {
      final client = MockClient((request) async {
        throw TimeoutException('Request timeout');
      });

      final service = PartidasRestService(httpClient: client);

      expect(
        () => service.getPartidasRest(),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('Tempo de conexão esgotado')),
        ),
      );
    });
  });
}
