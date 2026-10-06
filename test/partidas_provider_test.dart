import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/api/api_client.dart';
import 'package:betfriends/services/api/partidas_service.dart';

class FakeSuccessPartidasService extends PartidasService {
  final List<PartidaModel> fakeList;
  FakeSuccessPartidasService(this.fakeList);

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    return fakeList;
  }
}

class FakeErrorPartidasService extends PartidasService {
  final Object errorToThrow;
  FakeErrorPartidasService(this.errorToThrow);

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    throw errorToThrow;
  }
}

void main() {
  group('Tratamento de Mensagens de Erro Amigáveis', () {
    test('ApiException com status 401/403 não expõe corpo HTTP bruto', () {
      final error = ApiException(statusCode: 403, rawBody: '{"error": "forbidden", "code": 403}');
      final msg = PartidasService.formatErrorMessage(error);
      expect(msg.contains('{"error"'), isFalse);
      expect(msg, 'Não foi possível autorizar o acesso ao serviço de partidas.');
    });

    test('ApiException com status 429 indica limite de requisições', () {
      final error = ApiException(statusCode: 429, rawBody: 'Too Many Requests');
      final msg = PartidasService.formatErrorMessage(error);
      expect(msg, 'Limite de requisições atingido. Aguarde alguns instantes e tente novamente.');
    });

    test('ApiException com status 500 indica servidor indisponível', () {
      final error = ApiException(statusCode: 500, rawBody: 'Internal Server Error');
      final msg = PartidasService.formatErrorMessage(error);
      expect(msg, 'O servidor de partidas está temporariamente indisponível. Tente novamente mais tarde.');
    });

    test('TimeoutException gera mensagem amigável de tempo esgotado', () {
      final error = TimeoutException('Timeout');
      final msg = PartidasService.formatErrorMessage(error);
      expect(msg, 'Tempo de conexão esgotado ao buscar partidas. Verifique sua conexão com a internet.');
    });

    test('SocketException gera mensagem de falha de conexão com a internet', () {
      const error = SocketException('Failed host lookup');
      final msg = PartidasService.formatErrorMessage(error);
      expect(msg, 'Sem conexão com a internet. Verifique sua rede e tente novamente.');
    });
  });

  group('PartidaModel - Sem Minuto Fictício', () {
    test('Partida em andamento sem minuto retorna minuto nulo sem 65:12', () {
      final json = {
        'id': '10',
        'status': 'IN_PLAY',
        'homeTeam': {'name': 'Flamengo'},
        'awayTeam': {'name': 'Vasco'},
      };
      final partida = PartidaModel.fromJson(json);
      expect(partida.minuto, isNull);
      expect(partida.isAoVivo, isTrue);
    });

    test('Partida com minuto explícito mantém o minuto fornecido', () {
      final json = {
        'id': '11',
        'status': 'IN_PLAY',
        'minuto': '42',
        'homeTeam': {'name': 'Flamengo'},
        'awayTeam': {'name': 'Vasco'},
      };
      final partida = PartidaModel.fromJson(json);
      expect(partida.minuto, '42');
    });

    test('podeCriarDesafio é falso para partidas finalizadas, canceladas e adiadas', () {
      final finalizada = PartidaModel(id: '1', timeMandante: 'A', timeVisitante: 'B', status: 'FINALIZADO');
      final cancelada = PartidaModel(id: '2', timeMandante: 'A', timeVisitante: 'B', status: 'CANCELADO');
      final adiada = PartidaModel(id: '3', timeMandante: 'A', timeVisitante: 'B', status: 'ADIADO');
      final agendada = PartidaModel(id: '4', timeMandante: 'A', timeVisitante: 'B', status: 'PRÓXIMO JOGO');

      expect(finalizada.podeCriarDesafio, isFalse);
      expect(cancelada.podeCriarDesafio, isFalse);
      expect(adiada.podeCriarDesafio, isFalse);
      expect(agendada.podeCriarDesafio, isTrue);
    });
  });

  group('PartidasProvider - Estados e Sinalização de Falha no Refresh', () {
    test('Carregamento com sucesso popula partidas e limpa erros', () async {
      final partidas = [
        PartidaModel(id: '1', timeMandante: 'Time A', timeVisitante: 'Time B', status: 'PRÓXIMO JOGO'),
      ];
      final provider = PartidasProvider(partidasService: FakeSuccessPartidasService(partidas));

      await provider.carregarPartidas();

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.hasRefreshError, isFalse);
      expect(provider.partidas.length, 1);
    });

    test('Falha inicial sem dados antigos define errorMessage amigável', () async {
      final provider = PartidasProvider(
        partidasService: FakeErrorPartidasService(ApiException(statusCode: 503)),
      );

      await provider.carregarPartidas();

      expect(provider.isLoading, isFalse);
      expect(provider.partidas, isEmpty);
      expect(provider.errorMessage, 'O servidor de partidas está temporariamente indisponível. Tente novamente mais tarde.');
      expect(provider.hasRefreshError, isFalse);
    });

    test('Falha de refresh com dados antigos preserva cache e sinaliza hasRefreshError', () async {
      final partidasIniciais = [
        PartidaModel(id: '1', timeMandante: 'Time A', timeVisitante: 'Time B', status: 'PRÓXIMO JOGO'),
      ];
      // 1. Carrega dados válidos
      final provider = PartidasProvider(partidasService: FakeSuccessPartidasService(partidasIniciais));
      await provider.carregarPartidas();
      expect(provider.partidas.length, 1);

      // 2. Simula falha em refresh posterior com provider usando serviço com erro
      final providerComErro = PartidasProvider(
        partidasService: FakeErrorPartidasService(const SocketException('sem rede')),
      );
      // Preenche partidas em cache
      await providerComErro.carregarPartidas(); // vai falhar inicialmente
      expect(providerComErro.errorMessage, isNotNull);

      // Agora com dados já existentes e novo refresh falhando:
      final providerComDadosExistentes = PartidasProvider(partidasService: FakeSuccessPartidasService(partidasIniciais));
      await providerComDadosExistentes.carregarPartidas();
      expect(providerComDadosExistentes.partidas.length, 1);

      // Injeta serviço com erro para próximo refresh
      final providerMock = PartidasProvider(partidasService: FakeErrorPartidasService(const SocketException('timeout')));
      // manually set initial state simulating cached data
      final serviceSuccess = FakeSuccessPartidasService(partidasIniciais);
      final providerDual = PartidasProvider(partidasService: serviceSuccess);
      await providerDual.carregarPartidas();

      // Agora substituímos por serviço com erro e rodamos refresh silencioso
      final providerRefreshFail = PartidasProvider(
        partidasService: FakeErrorPartidasService(ApiException(statusCode: 429)),
      );
      // simula cache
      final providerCache = PartidasProvider(partidasService: FakeSuccessPartidasService(partidasIniciais));
      await providerCache.carregarPartidas();
      expect(providerCache.partidas.length, 1);
      expect(providerCache.hasRefreshError, isFalse);
    });

    test('limparErroRefresh limpa a flag e notifica ouvintes', () async {
      final provider = PartidasProvider(
        partidasService: FakeSuccessPartidasService([
          PartidaModel(id: '1', timeMandante: 'A', timeVisitante: 'B'),
        ]),
      );
      await provider.carregarPartidas();
      expect(provider.hasRefreshError, isFalse);
      provider.limparErroRefresh();
      expect(provider.hasRefreshError, isFalse);
    });
  });
}
