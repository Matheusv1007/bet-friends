import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _Servico extends PartidasService {
  _Servico({this.partidas = const [], this.erro});
  final List<PartidaModel> partidas;
  Object? erro;

  @override
  Future<List<PartidaModel>> getPartidas() async {
    if (erro != null) throw erro!;
    return partidas;
  }
}

final _base = DateTime.now().toUtc();

PartidaModel _partida(
  String liga,
  int i, {
  String status = 'AGENDADA',
  Duration? em,
}) =>
    PartidaModel(
      id: '${liga}_$i',
      timeMandante: 'Casa $i',
      timeVisitante: 'Fora $i',
      status: status,
      competitionCode: liga,
      startsAtUtc: _base.add(em ?? Duration(hours: 24 + i)),
    );

Future<PartidasProvider> _carregar(List<PartidaModel> partidas) async {
  final provider = PartidasProvider(partidasService: _Servico(partidas: partidas));
  await provider.carregarPartidas();
  return provider;
}

Map<String?, int> _porLiga(List<PartidaModel> lista) {
  final r = <String?, int>{};
  for (final p in lista) {
    r[p.competitionCode] = (r[p.competitionCode] ?? 0) + 1;
  }
  return r;
}

void main() {
  const ligas = ['BSA', 'PL', 'SA', 'PD'];

  group('Home com várias ligas', () {
    test('limita a 15 sem uma liga dominar quando há partidas de todas', () async {
      // O Brasileirão tem os jogos mais próximos: sozinho, ocuparia a lista inteira.
      final todas = [
        for (var i = 0; i < 30; i++) _partida('BSA', i),
        for (final liga in ['PL', 'SA', 'PD'])
          for (var i = 0; i < 20; i++) _partida(liga, 100 + i),
      ];

      final provider = await _carregar(todas);

      final home = provider.partidasDaHome;
      expect(home.length, PartidasProvider.limiteDaHome);
      final contagem = _porLiga(home);
      expect(contagem.keys.toSet(), ligas.toSet());
      for (final liga in ligas) {
        expect(contagem[liga], inInclusiveRange(3, 4), reason: liga);
      }
      // Dentro da seleção, os jogos seguem por horário.
      final horarios = [for (final p in home) p.startsAtUtc!];
      expect([...horarios]..sort(), horarios);
    });

    test('liga com poucas partidas deixa o espaço para as outras', () async {
      final provider = await _carregar([
        for (var i = 0; i < 2; i++) _partida('PL', i),
        for (var i = 0; i < 30; i++) _partida('PD', 10 + i),
      ]);

      final contagem = _porLiga(provider.partidasDaHome);
      expect(provider.partidasDaHome.length, 15);
      expect(contagem['PL'], 2);
      expect(contagem['PD'], 13);
    });

    test('mantém ao vivo, agendadas e finalizadas recentes, nessa ordem', () async {
      final provider = await _carregar([
        _partida('PL', 1, status: 'FINALIZADA', em: const Duration(days: -2)),
        _partida('BSA', 2, status: 'FINALIZADA', em: const Duration(days: -1)),
        _partida('SA', 3, em: const Duration(hours: 5)),
        _partida('PD', 4, em: const Duration(hours: 2)),
        _partida('BSA', 5, status: 'EM_ANDAMENTO', em: const Duration(minutes: -30)),
      ]);

      expect(provider.partidasDaHome.map((p) => p.id), [
        'BSA_5', // ao vivo
        'PD_4', 'SA_3', // agendadas por horário
        'BSA_2', 'PL_1', // finalizadas, a mais recente primeiro
      ]);
    });

    test('sem partidas a Home fica vazia', () async {
      final provider = await _carregar([]);
      expect(provider.partidasDaHome, isEmpty);
      expect(provider.partidas, isEmpty);
    });
  });

  group('Criar Desafio com várias ligas', () {
    test('partidas traz o conjunto completo, não só a seleção da Home', () async {
      final todas = [
        for (final liga in ligas)
          for (var i = 0; i < 12; i++) _partida(liga, i),
        _partida('PL', 99, status: 'FINALIZADA', em: const Duration(days: -1)),
      ];

      final provider = await _carregar(todas);

      expect(provider.partidas.length, 49);
      final elegiveis = provider.partidas.where((p) => p.podeCriarDesafio);
      expect(elegiveis.length, 48);
      expect(_porLiga(elegiveis.toList()), {for (final l in ligas) l: 12});
      expect(provider.partidasDaHome.length, 15);
    });
  });

  group('Erro de consulta', () {
    test('vira mensagem de erro, sem lista fictícia', () async {
      final provider = PartidasProvider(
        partidasService: _Servico(
          erro: FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );

      await provider.carregarPartidas();

      expect(provider.errorMessage, isNotNull);
      expect(provider.partidas, isEmpty);
      expect(provider.partidasDaHome, isEmpty);
    });

    test('com dados anteriores, a falha preserva Home e conjunto completo', () async {
      final servico = _Servico(partidas: [_partida('PL', 1)]);
      final provider = PartidasProvider(partidasService: servico);
      await provider.carregarPartidas();

      servico.erro = StateError('falha');
      await provider.carregarPartidas(forcar: true);

      expect(provider.hasRefreshError, isTrue);
      expect(provider.partidas.map((p) => p.id), ['PL_1']);
      expect(provider.partidasDaHome.map((p) => p.id), ['PL_1']);
    });
  });
}
