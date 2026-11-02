import 'package:flutter_test/flutter_test.dart';
import 'package:betfriends/data/firestore/partidas_repository.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/api/partidas_service.dart';

class FakePartidasRepository implements PartidasRepository {
  List<PartidaModel> matches;
  Object? error;

  FakePartidasRepository({this.matches = const [], this.error});

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    if (error != null) throw error!;
    return matches;
  }
}

void main() {
  group('Visualizar Partidas Futuras (KAN-42; RF-007, RN-MAT-001, RN-MAT-002, RN-MAT-005)', () {
    test('1. Lista exibe partidas futuras da competição ajustada para o MVP (Brasileirão Série A / BSA)', () async {
      final dataFutura = DateTime.now().toUtc().add(const Duration(days: 2));
      final partidaFutura = PartidaModel(
        id: 'footballdata_1001',
        timeMandante: 'Flamengo',
        timeVisitante: 'Fluminense',
        competitionCode: 'BSA',
        season: 2026,
        status: 'PRÓXIMO JOGO',
        startsAtUtc: dataFutura,
      );

      final repo = FakePartidasRepository(matches: [partidaFutura]);
      final service = PartidasService(repository: repo);
      final partidas = await service.getPartidas();

      expect(partidas.length, 1);
      expect(partidas.first.timeMandante, 'Flamengo');
      expect(partidas.first.timeVisitante, 'Fluminense');
      expect(partidas.first.competitionCode, 'BSA');
      expect(partidas.first.season, 2026);
      expect(partidas.first.isAgendado, isTrue);
      expect(partidas.first.podeCriarDesafio, isTrue);
    });

    test('2. Cada item apresenta horários, data/hora e status de domínio', () {
      final docMap = {
        'id': 'footballdata_1002',
        'competitionCode': 'BSA',
        'season': 2026,
        'status': 'AGENDADA', // Enum do Firestore
        'startsAtUtc': '2026-11-10T19:00:00.000Z',
        'homeTeam': {'name': 'Palmeiras', 'shortName': 'Palmeiras', 'externalId': '1765'},
        'awayTeam': {'name': 'São Paulo FC', 'shortName': 'São Paulo', 'externalId': '1766'},
      };

      final partida = PartidaModel.fromFirestoreMap(docMap, 'footballdata_1002');

      expect(partida.id, 'footballdata_1002');
      expect(partida.timeMandante, 'Palmeiras');
      expect(partida.timeVisitante, 'São Paulo');
      // Status de domínio em português:
      expect(partida.status, 'PRÓXIMO JOGO');
      expect(partida.horario, isNotNull);
      expect(partida.horario!.contains('10/11'), isTrue);
    });

    test('3. Conversão de horário do UTC para o fuso local do dispositivo ocorre apenas na exibição (RN-MAT-005)', () {
      // 2026-11-15 às 20:00 UTC
      final utcDate = DateTime.utc(2026, 11, 15, 20, 0);
      final partida = PartidaModel(
        id: 'footballdata_1003',
        timeMandante: 'Cruzeiro',
        timeVisitante: 'Atlético-MG',
        startsAtUtc: utcDate,
        status: 'PRÓXIMO JOGO',
      );

      // O dado armazenado é estritamente UTC
      expect(partida.startsAtUtc!.isUtc, isTrue);
      expect(partida.startsAtUtc!.hour, 20);

      // Na exibição, converte para o horário local do dispositivo
      final localEsperado = utcDate.toLocal();
      final horaEsperada = localEsperado.hour.toString().padLeft(2, '0');
      final minutoEsperado = localEsperado.minute.toString().padLeft(2, '0');

      expect(partida.horario, contains('$horaEsperada:$minutoEsperado'));
      expect(partida.horario, contains('15/11'));
    });

    test('4. Interface não exibe enums brutos do provedor (RN-MAT-002)', () {
      final statusesProvedor = [
        'SCHEDULED',
        'TIMED',
        'IN_PLAY',
        'PAUSED',
        'FINISHED',
        'POSTPONED',
        'CANCELLED',
        'SUSPENDED',
        'AWARDED',
      ];

      for (final raw in statusesProvedor) {
        final statusDominio = PartidaModel.mapearStatusDominio(raw);
        // Nenhum enum bruto do provedor é retornado:
        expect(statusDominio, isNot(equals(raw)));
        expect(
          ['PRÓXIMO JOGO', 'EM ANDAMENTO', 'FINALIZADO', 'ADIADO', 'CANCELADO', 'SUSPENSO', 'REVISÃO NECESSÁRIA'],
          contains(statusDominio),
        );
      }
    });

    test('5. Flutter não chama diretamente a Football-Data.org (RNF-005)', () {
      // O PartidasService é alimentado exclusivamente pelo repositório Firestore
      final service = PartidasService();
      expect(service.repository, isA<FirestorePartidasRepository>());
      // O repositório aponta para a coleção Firestore 'matches'
      expect(FirestorePartidasRepository, isNotNull);
    });

    test('6. Na indisponibilidade externa, dados já sincronizados continuam disponíveis no cache (RN-CACHE-001, RN-CACHE-003)', () async {
      final partidasIniciais = [
        PartidaModel(
          id: 'footballdata_1',
          timeMandante: 'Grêmio',
          timeVisitante: 'Internacional',
          status: 'PRÓXIMO JOGO',
          syncedAt: DateTime.utc(2026, 11, 2, 17, 30),
        ),
      ];

      final fakeRepo = FakePartidasRepository(matches: partidasIniciais);
      final service = PartidasService(repository: fakeRepo);
      final provider = PartidasProvider(partidasService: service);

      // 1. Carregamento inicial com sucesso dos dados sincronizados no Firestore
      await provider.carregarPartidas();
      expect(provider.partidas.length, 1);
      expect(provider.hasRefreshError, isFalse);
      expect(provider.partidas.first.timeMandante, 'Grêmio');

      // 2. Provedor externo ou rede fica indisponível
      fakeRepo.error = Exception('Serviço indisponível');
      await provider.carregarPartidas(silencioso: true);

      // Os dados anteriores permanecem disponíveis na interface
      expect(provider.partidas.length, 1);
      expect(provider.hasRefreshError, isTrue);
      expect(provider.partidas.first.timeMandante, 'Grêmio');
      expect(provider.refreshErrorMessage, 'Não foi possível atualizar os dados mais recentes. Exibindo dados anteriores.');
    });

    test('7. Interface exibe a data/hora da última atualização dos dados de partidas (RN-CACHE-002)', () async {
      final agora = DateTime.now();
      final partidasComSync = [
        PartidaModel(
          id: 'footballdata_1',
          timeMandante: 'Corinthians',
          timeVisitante: 'Santos',
          status: 'PRÓXIMO JOGO',
          syncedAt: agora,
        ),
      ];

      final repo = FakePartidasRepository(matches: partidasComSync);
      final provider = PartidasProvider(partidasService: PartidasService(repository: repo));

      expect(provider.ultimaAtualizacaoFormatada, isNull);

      await provider.carregarPartidas();

      final hora = agora.toLocal().hour.toString().padLeft(2, '0');
      final minuto = agora.toLocal().minute.toString().padLeft(2, '0');

      expect(provider.ultimaAtualizacao, isNotNull);
      expect(provider.ultimaAtualizacaoFormatada, 'Atualizado às $hora:$minuto');
    });

    test('8. Corte de 5 minutos antes do início para partidas futuras (RN-MAT-003, RN-MAT-004)', () {
      final agora = DateTime.now().toUtc();

      // Partida daqui a 10 minutos: elegível para desafio
      final partidaElegivel = PartidaModel(
        id: 'p1',
        timeMandante: 'A',
        timeVisitante: 'B',
        status: 'PRÓXIMO JOGO',
        startsAtUtc: agora.add(const Duration(minutes: 10)),
      );
      expect(partidaElegivel.podeCriarDesafio, isTrue);

      // Partida daqui a 3 minutos: NÃO elegível (corte de 5 min)
      final partidaExpirada = PartidaModel(
        id: 'p2',
        timeMandante: 'A',
        timeVisitante: 'B',
        status: 'PRÓXIMO JOGO',
        startsAtUtc: agora.add(const Duration(minutes: 3)),
      );
      expect(partidaExpirada.podeCriarDesafio, isFalse);
    });
  });
}
