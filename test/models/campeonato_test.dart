import 'package:betfriends/models/campeonato.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Campeonato', () {
    test('lista as quatro ligas na ordem de exibição', () {
      expect(Campeonato.codigosSuportados, ['BSA', 'PL', 'SA', 'PD']);
      expect(
        [for (final c in Campeonato.suportados) c.nome],
        ['Brasileirão Série A', 'Premier League', 'Serie A', 'La Liga'],
      );
    });

    test('nome por código, sem diferenciar caixa', () {
      expect(Campeonato.nomeDoCodigo('BSA'), 'Brasileirão Série A');
      expect(Campeonato.nomeDoCodigo('PL'), 'Premier League');
      expect(Campeonato.nomeDoCodigo('SA'), 'Serie A');
      expect(Campeonato.nomeDoCodigo('PD'), 'La Liga');
      expect(Campeonato.nomeDoCodigo('pl'), 'Premier League');
    });

    test('código desconhecido cai no próprio código', () {
      expect(Campeonato.nomeDoCodigo('XYZ'), 'XYZ');
      expect(Campeonato.deCodigo('XYZ'), isNull);
      expect(Campeonato.deCodigo(null), isNull);
    });
  });

  group('PartidaModel.nomeDoCampeonato', () {
    Map<String, dynamic> doc(Map<String, dynamic> extra) => {
          'status': 'SCHEDULED',
          'homeTeam': {'name': 'A'},
          'awayTeam': {'name': 'B'},
          'startsAtUtc': '2026-12-01T18:00:00Z',
          ...extra,
        };

    test('usa o competitionCode dos documentos das quatro ligas', () {
      final nomes = {
        for (final c in Campeonato.codigosSuportados)
          c: PartidaModel.fromFirestoreMap(doc({'competitionCode': c}), 'x')
              .nomeDoCampeonato,
      };
      expect(nomes, {
        'BSA': 'Brasileirão Série A',
        'PL': 'Premier League',
        'SA': 'Serie A',
        'PD': 'La Liga',
      });
    });

    test('código desconhecido não quebra e aparece como está', () {
      final p = PartidaModel.fromFirestoreMap(
        doc({'competitionCode': 'ELC'}), 'x',
      );
      expect(p.nomeDoCampeonato, 'ELC');
    });

    test('documento antigo sem competitionCode nem season segue válido como BSA', () {
      final p = PartidaModel.fromFirestoreMap(doc({}), 'antigo');
      expect(p.competitionCode, 'BSA');
      expect(p.season, 2026);
      expect(p.nomeDoCampeonato, 'Brasileirão Série A');
    });

    test('ignora o campo legado quando ele é o código cru', () {
      final p = PartidaModel(
        id: 'x', timeMandante: 'A', timeVisitante: 'B',
        competitionCode: 'PL', campeonato: 'PL',
      );
      expect(p.nomeDoCampeonato, 'Premier League');
    });
  });
}
