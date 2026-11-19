import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class MutablePartidasService extends PartidasService {
  List<PartidaModel> matches;
  Object? error;
  MutablePartidasService({this.matches = const [], this.error});

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    if (error != null) {
      throw error!;
    }
    return matches;
  }
}

void main() {
  group('Tratamento de Mensagens de Erro Amigáveis', () {
    test('Permissão negada no Firestore não expõe dados técnicos', () {
      final error = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied', message: '{"error": "forbidden"}');
      final msg = PartidasService.formatErrorMessage(error);
      expect(msg.contains('{"error"'), isFalse);
      expect(msg, 'Não foi possível autorizar o acesso ao serviço de partidas.');
    });

    test('Limite de requisições do Firestore indica espera', () {
      final error = FirebaseException(plugin: 'cloud_firestore', code: 'resource-exhausted');
      final msg = PartidasService.formatErrorMessage(error);
      expect(msg, 'Limite de requisições atingido. Aguarde alguns instantes e tente novamente.');
    });

    test('Firestore indisponível gera mensagem amigável', () {
      final error = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      final msg = PartidasService.formatErrorMessage(error);
      expect(msg, 'Serviço de partidas temporariamente indisponível. Verifique sua conexão e tente novamente.');
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
        partidasService: FakeErrorPartidasService(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')),
      );

      await provider.carregarPartidas();

      expect(provider.isLoading, isFalse);
      expect(provider.partidas, isEmpty);
      expect(provider.errorMessage, 'Serviço de partidas temporariamente indisponível. Verifique sua conexão e tente novamente.');
      expect(provider.hasRefreshError, isFalse);
    });

    test('Falha de refresh com dados antigos preserva cache e sinaliza hasRefreshError', () async {
      final partidasIniciais = [
        PartidaModel(id: '1', timeMandante: 'Time A', timeVisitante: 'Time B', status: 'PRÓXIMO JOGO'),
      ];
      final mutableService = MutablePartidasService(matches: partidasIniciais);
      final provider = PartidasProvider(partidasService: mutableService);

      // 1. Carrega dados válidos com sucesso
      await provider.carregarPartidas();
      expect(provider.partidas.length, 1);
      expect(provider.hasRefreshError, isFalse);
      expect(provider.errorMessage, isNull);

      // 2. Simula falha no refresh subsequente
      mutableService.error = FirebaseException(plugin: 'cloud_firestore', code: 'resource-exhausted');
      await provider.carregarPartidas(silencioso: true);

      // Dados anteriores continuam no cache e erro de refresh é sinalizado
      expect(provider.partidas.length, 1);
      expect(provider.hasRefreshError, isTrue);
      expect(provider.refreshErrorMessage, 'Não foi possível atualizar os dados mais recentes. Exibindo dados anteriores.');
      expect(provider.errorMessage, isNull);
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
