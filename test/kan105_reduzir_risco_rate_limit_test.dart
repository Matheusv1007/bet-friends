// Reduzir risco de limite de taxa na integração de partidas (KAN-105)
//
// Critérios de Aceitação:
// - Polling é ajustado para reduzir o consumo durante o uso normal e demonstração;
// - Fallback não repete chamada de forma inconveniente após HTTP 429 ou Timeout;
// - Consulta utiliza filtros/escopo menor quando possível;
// - Erro de limite de requisições é tratado de forma compreensível;
// - Puxe para atualizar (Pull-to-refresh) continua funcional;
// - Mudança não introduz dados fictícios;
// - Solução é temporária até KAN-49/KAN-50.
//
// Validação:
// - Simular resposta 429;
// - Validar quantidade de requisições na navegação Home → Criar Desafio → Home;
// - Validar carga normal e tentar novamente (retry).

import 'dart:async';

import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/api/api_client.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/telas_principais/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

/// Cliente HTTP espião para contar requisições e validar URLs e parâmetros chamados
class _SpyHttpClient extends http.BaseClient {
  final List<http.Request> chamadas = [];
  int statusCodeRetorno = 200;
  String bodyRetorno = '{"matches": []}';
  bool simularTimeout = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      chamadas.add(request);
    }
    if (simularTimeout) {
      throw TimeoutException('Tempo esgotado');
    }
    final stream = Stream.value(bodyRetorno.codeUnits);
    return http.StreamedResponse(stream, statusCodeRetorno);
  }
}

/// Serviço de partidas com contador de chamadas para testes de navegação e cache
class _ContadorPartidasService extends PartidasService {
  int chamadasGetPartidas = 0;
  List<PartidaModel> partidasRetorno;
  Object? erroParaLancar;

  _ContadorPartidasService({this.partidasRetorno = const [], this.erroParaLancar});

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    chamadasGetPartidas++;
    if (erroParaLancar != null) {
      throw erroParaLancar!;
    }
    return partidasRetorno;
  }
}

void main() {
  group('KAN-105: Redução de Risco de Limite de Taxa (Rate Limit)', () {
    test('1. Consulta direta via ApiClient utiliza filtros/escopo menor', () async {
      final spyHttp = _SpyHttpClient();
      spyHttp.bodyRetorno = '''
      {
        "matches": [
          {
            "id": 101,
            "status": "TIMED",
            "homeTeam": {"name": "Flamengo"},
            "awayTeam": {"name": "Vasco"}
          }
        ]
      }
      ''';

      final apiClient = ApiClient(
        baseUrl: 'https://api.football-data.org/v4',
        httpClient: spyHttp,
      );
      final service = PartidasService(client: apiClient);

      final partidas = await service.getPartidas();

      expect(partidas.length, 1);
      expect(spyHttp.chamadas.length, 1);

      final url = spyHttp.chamadas.first.url.toString();
      // Não consulta a temporada inteira desnecessariamente; aplica filtro de status
      expect(url, contains('/competitions/BSA/matches'));
      expect(url, contains('status='));
      expect(url, contains('IN_PLAY'));
      expect(url, contains('SCHEDULED'));
    });

    test('2. Fallback NÃO repete chamada após HTTP 429 (Too Many Requests)', () async {
      final spyHttp = _SpyHttpClient();
      spyHttp.statusCodeRetorno = 429;
      spyHttp.bodyRetorno = '{"message": "API rate limit exceeded"}';

      final apiClient = ApiClient(
        baseUrl: 'https://api.football-data.org/v4',
        httpClient: spyHttp,
      );
      final service = PartidasService(client: apiClient);

      // Deve falhar e NÃO realizar chamada adicional para /matches
      expect(
        () => service.getPartidas(),
        throwsA(isA<Exception>()),
      );

      // Apenas 1 chamada foi feita! O fallback foi suprimido após 429
      expect(spyHttp.chamadas.length, 1);
      expect(spyHttp.chamadas.first.url.path, contains('/competitions/BSA/matches'));
    });

    test('3. Fallback NÃO repete chamada após TimeoutException', () async {
      final spyHttp = _SpyHttpClient();
      spyHttp.simularTimeout = true;

      final apiClient = ApiClient(
        baseUrl: 'https://api.football-data.org/v4',
        httpClient: spyHttp,
      );
      final service = PartidasService(client: apiClient);

      expect(
        () => service.getPartidas(),
        throwsA(isA<Exception>()),
      );

      // Apenas 1 chamada foi feita; não bombardeia /matches após timeout
      expect(spyHttp.chamadas.length, 1);
    });

    test('4. Erro de limite de requisições 429 é tratado de forma compreensível', () {
      final erro429 = ApiException(statusCode: 429, rawBody: 'Too Many Requests');
      final msg = PartidasService.formatErrorMessage(erro429);

      expect(
        msg,
        'Limite de requisições atingido. Aguarde alguns instantes e tente novamente.',
      );
    });

    test('5. Cooldown após 429 suspende novas requisições de polling automático', () async {
      final contadorService = _ContadorPartidasService(
        erroParaLancar: ApiException(statusCode: 429),
      );
      final provider = PartidasProvider(partidasService: contadorService);

      // 1. Primeira chamada falha com 429
      await provider.carregarPartidas();
      expect(contadorService.chamadasGetPartidas, 1);
      expect(provider.isRateLimited, isTrue);
      expect(
        provider.errorMessage,
        'Limite de requisições atingido. Aguarde alguns instantes e tente novamente.',
      );

      // 2. Polling silencioso enquanto rate limited não dispara nova requisição
      await provider.carregarPartidas(silencioso: true);
      expect(contadorService.chamadasGetPartidas, 1); // Continua 1, não chamou o backend!

      // 3. Usuário força retry explicitamente (forcar: true): a chamada é executada
      await provider.carregarPartidas(forcar: true);
      expect(contadorService.chamadasGetPartidas, 2); // Disparou pois foi forçado
    });

    testWidgets(
      '6. Navegação Home → Criar Desafio → Home não duplica requisições (exatamente 1 chamada)',
      (tester) async {
        final contadorService = _ContadorPartidasService(
          partidasRetorno: [
            PartidaModel(
              id: '1',
              timeMandante: 'Flamengo',
              timeVisitante: 'Vasco',
              status: 'PRÓXIMO JOGO',
              horario: 'Amanhã 19:00',
            ),
          ],
        );
        final provider = PartidasProvider(partidasService: contadorService);
        final auth = FakeAuthService(usuarioInicial: FakeUser('uid-teste'));

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PartidasProvider>.value(value: provider),
            ],
            child: MaterialApp(
              home: Homepage(authService: auth),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Ao abrir a Home, executa a primeira carga (1 chamada)
        expect(contadorService.chamadasGetPartidas, 1);
        expect(find.text('Flamengo'), findsOneWidget);

        // 2. Navega para a tela CriarDesafioScreen
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PartidasProvider>.value(value: provider),
            ],
            child: const MaterialApp(
              home: CriarDesafioScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Partidas em cache foram reutilizadas; nenhuma requisição adicional!
        expect(contadorService.chamadasGetPartidas, 1);
        expect(find.text('Flamengo'), findsOneWidget);

        // 3. Retorna para a Home
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PartidasProvider>.value(value: provider),
            ],
            child: MaterialApp(
              home: Homepage(authService: auth),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // O total de chamadas continua exatamente 1!
        expect(contadorService.chamadasGetPartidas, 1);
      },
    );

    test('7. Puxe para atualizar (forcar: true) ignora cache e executa nova carga', () async {
      final contadorService = _ContadorPartidasService(
        partidasRetorno: [
          PartidaModel(id: '1', timeMandante: 'A', timeVisitante: 'B'),
        ],
      );
      final provider = PartidasProvider(partidasService: contadorService);

      // Carga inicial
      await provider.carregarPartidas();
      expect(contadorService.chamadasGetPartidas, 1);

      // Carga imediata sem forcar (dentro da janela de frescor)
      await provider.carregarPartidas();
      expect(contadorService.chamadasGetPartidas, 1); // Reutilizou cache

      // Puxe para atualizar / refresh explícito
      await provider.carregarPartidas(forcar: true);
      expect(contadorService.chamadasGetPartidas, 2); // Executou re-fetch com sucesso
    });

    test('8. Partidas sem minuto mantêm minuto nulo sem introduzir dados fictícios', () {
      final json = {
        'id': '99',
        'status': 'IN_PLAY',
        'homeTeam': {'name': 'Palmeiras'},
        'awayTeam': {'name': 'Santos'},
      };
      final partida = PartidaModel.fromJson(json);

      expect(partida.minuto, isNull);
      expect(partida.isAoVivo, isTrue);
    });
  });
}
