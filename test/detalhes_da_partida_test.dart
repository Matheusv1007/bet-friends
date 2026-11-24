import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/widgets_home_page/card_de_partidas.dart';
import 'package:betfriends/widgets_home_page/detalhes_da_partida_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Visualizar Detalhes de uma Partida (KAN-43; RF-008, RN-MAT-005, RNF-005, RNF-013)', () {
    testWidgets(
      '1. Detalhe de partida agendada exibe mandante, visitante, data/hora local e status de domínio sem placar',
      (tester) async {
        final dataFuturaUtc = DateTime.utc(2026, 12, 1, 19, 30);
        final partidaAgendada = PartidaModel(
          id: 'footballdata_5001',
          timeMandante: 'Palmeiras',
          timeVisitante: 'São Paulo',
          startsAtUtc: dataFuturaUtc,
          status: 'PRÓXIMO JOGO',
          statusDominio: StatusPartida.agendada,
          campeonato: 'Brasileirão Série A',
          matchday: 34,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      DetalhesDaPartidaSheet.exibir(context, partidaAgendada),
                  child: const Text('ABRIR'),
                ),
              ),
            ),
          ),
        );

        // Abre o diálogo de detalhes
        await tester.tap(find.text('ABRIR'));
        await tester.pumpAndSettle();

        // Critério 1: Detalhe mostra mandante e visitante
        expect(
          find.byKey(const Key('detalhes_partida_mandante')),
          findsOneWidget,
        );
        expect(find.text('Palmeiras'), findsOneWidget);
        expect(
          find.byKey(const Key('detalhes_partida_visitante')),
          findsOneWidget,
        );
        expect(find.text('São Paulo'), findsOneWidget);

        // Critério 2: Data/hora é exibida no fuso do dispositivo (RN-MAT-005)
        final local = dataFuturaUtc.toLocal();
        final horaEsperada = local.hour.toString().padLeft(2, '0');
        final minutoEsperado = local.minute.toString().padLeft(2, '0');
        final dataEsperada =
            '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
        expect(find.textContaining(dataEsperada), findsOneWidget);
        expect(find.text('$horaEsperada:$minutoEsperado'), findsOneWidget);

        // Critério 3: Status exibido usa enum/domínio interno (RF-008, RNF-013)
        expect(
          find.byKey(const Key('detalhes_partida_status')),
          findsOneWidget,
        );
        expect(find.text('Agendada'), findsOneWidget);

        // Critério 4: Partida agendada não apresenta placar e indica que ainda não iniciou
        expect(find.byKey(const Key('detalhes_partida_placar')), findsNothing);
        expect(
          find.byKey(const Key('detalhes_partida_sem_placar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('detalhes_partida_resultado')),
          findsNothing,
        );

        // Critério 5: Nenhum enum bruto do Football-Data.org é exposto ao Flutter
        expect(find.text('SCHEDULED'), findsNothing);
        expect(find.text('TIMED'), findsNothing);
        expect(find.text('FINISHED'), findsNothing);
        expect(find.text('IN_PLAY'), findsNothing);

        // Partida futura e elegível apresenta botão de desafiar
        expect(find.byKey(const Key('btn_desafiar_partida')), findsOneWidget);
        expect(
          find.byKey(const Key('btn_fechar_detalhes_partida')),
          findsOneWidget,
        );

        // Fecha o diálogo
        await tester.tap(find.byKey(const Key('btn_fechar_detalhes_partida')));
        await tester.pumpAndSettle();
        expect(find.byType(DetalhesDaPartidaSheet), findsNothing);
      },
    );

    testWidgets(
      '2. Detalhe de partida finalizada exibe mandante, visitante, placar e resultado normalizado',
      (tester) async {
        final dataPassadaUtc = DateTime.utc(2026, 11, 10, 21, 30);
        final partidaFinalizada = PartidaModel(
          id: 'footballdata_5002',
          timeMandante: 'Flamengo',
          timeVisitante: 'Fluminense',
          golsMandante: 3,
          golsVisitante: 1,
          startsAtUtc: dataPassadaUtc,
          status: 'FINALIZADO',
          statusDominio: StatusPartida.finalizada,
          resultado: ResultadoPartida.homeWin,
          campeonato: 'Brasileirão Série A',
          matchday: 33,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      DetalhesDaPartidaSheet.exibir(context, partidaFinalizada),
                  child: const Text('ABRIR'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('ABRIR'));
        await tester.pumpAndSettle();

        // Mandante e Visitante
        expect(
          find.byKey(const Key('detalhes_partida_mandante')),
          findsOneWidget,
        );
        expect(find.text('Flamengo'), findsOneWidget);
        expect(
          find.byKey(const Key('detalhes_partida_visitante')),
          findsOneWidget,
        );
        expect(find.text('Fluminense'), findsOneWidget);

        // Status do domínio interno
        expect(
          find.byKey(const Key('detalhes_partida_status')),
          findsOneWidget,
        );
        expect(find.text('Finalizada'), findsOneWidget);

        // Placar apresentado
        expect(
          find.byKey(const Key('detalhes_partida_placar')),
          findsOneWidget,
        );
        expect(find.text('3 - 1'), findsOneWidget);

        // Resultado normalizado apresentado (RF-008, RNF-013)
        expect(
          find.byKey(const Key('detalhes_partida_resultado')),
          findsOneWidget,
        );
        expect(find.text('Vitória do Mandante (Flamengo)'), findsOneWidget);

        // Nenhum enum bruto do provedor exposto
        expect(find.text('FINISHED'), findsNothing);
        expect(find.text('HOME_TEAM'), findsNothing);
        expect(find.text('AWAY_TEAM'), findsNothing);

        // Partida finalizada não permite novos desafios
        expect(find.byKey(const Key('btn_desafiar_partida')), findsNothing);
      },
    );

    testWidgets(
      '3. Detalhe de partida finalizada com empate apresenta resultado normalizado Empate',
      (tester) async {
        final dataPassadaUtc = DateTime.utc(2026, 11, 12, 19, 0);
        final partidaEmpate = PartidaModel(
          id: 'footballdata_5003',
          timeMandante: 'Corinthians',
          timeVisitante: 'Santos',
          golsMandante: 2,
          golsVisitante: 2,
          startsAtUtc: dataPassadaUtc,
          statusDominio: StatusPartida.finalizada,
          resultado: ResultadoPartida.draw,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      DetalhesDaPartidaSheet.exibir(context, partidaEmpate),
                  child: const Text('ABRIR'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('ABRIR'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('detalhes_partida_placar')),
          findsOneWidget,
        );
        expect(find.text('2 - 2'), findsOneWidget);
        expect(
          find.byKey(const Key('detalhes_partida_resultado')),
          findsOneWidget,
        );
        expect(find.text('Empate'), findsOneWidget);
        expect(find.text('DRAW'), findsNothing);
      },
    );

    testWidgets(
      '4. Detalhe de partida finalizada com vitória do visitante apresenta descrição normalizada',
      (tester) async {
        final dataPassadaUtc = DateTime.utc(2026, 11, 14, 16, 0);
        final partidaVisitante = PartidaModel(
          id: 'footballdata_5004',
          timeMandante: 'Grêmio',
          timeVisitante: 'Internacional',
          golsMandante: 0,
          golsVisitante: 1,
          startsAtUtc: dataPassadaUtc,
          statusDominio: StatusPartida.finalizada,
        );

        // Resultado deduzido automaticamente a partir dos gols quando finalizada
        expect(partidaVisitante.resultado, ResultadoPartida.awayWin);
        expect(
          partidaVisitante.resultadoNormalizadoDescricao,
          'Vitória do Visitante (Internacional)',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      DetalhesDaPartidaSheet.exibir(context, partidaVisitante),
                  child: const Text('ABRIR'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('ABRIR'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('detalhes_partida_resultado')),
          findsOneWidget,
        );
        expect(
          find.text('Vitória do Visitante (Internacional)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '5. Toque no Carddepartidas na listagem abre o diálogo de detalhes da partida',
      (tester) async {
        final partida = PartidaModel(
          id: 'footballdata_5005',
          timeMandante: 'Cruzeiro',
          timeVisitante: 'Atlético-MG',
          startsAtUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
          statusDominio: StatusPartida.agendada,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Carddepartidas(partida: partida)),
          ),
        );

        // Card é renderizado com a chave apropriada
        final cardFinder = find.byKey(
          const Key('card_partida_footballdata_5005'),
        );
        expect(cardFinder, findsOneWidget);

        // Toca no card
        await tester.tap(cardFinder);
        await tester.pumpAndSettle();

        // Diálogo de detalhes deve ser aberto
        expect(find.byType(DetalhesDaPartidaSheet), findsOneWidget);
        expect(find.text('Detalhes da partida'), findsOneWidget);
        expect(find.text('Cruzeiro'), findsAtLeastNWidgets(1));
        expect(find.text('Atlético-MG'), findsAtLeastNWidgets(1));
      },
    );

    test('6. Mapeamento de enums do domínio interno e proteção contra enums brutos (RF-008, RNF-013)', () {
      // Status
      expect(StatusPartida.deCodigo('SCHEDULED'), StatusPartida.agendada);
      expect(StatusPartida.deCodigo('TIMED'), StatusPartida.agendada);
      expect(StatusPartida.deCodigo('AGENDADA'), StatusPartida.agendada);
      expect(StatusPartida.deCodigo('IN_PLAY'), StatusPartida.emAndamento);
      expect(StatusPartida.deCodigo('FINISHED'), StatusPartida.finalizada);
      expect(StatusPartida.deCodigo('FINALIZADA'), StatusPartida.finalizada);
      expect(StatusPartida.deCodigo('POSTPONED'), StatusPartida.adiada);
      expect(StatusPartida.deCodigo('CANCELLED'), StatusPartida.cancelada);
      expect(StatusPartida.deCodigo('SUSPENDED'), StatusPartida.suspensa);
      expect(
        StatusPartida.deCodigo('AWARDED'),
        StatusPartida.revisaoNecessaria,
      );

      // Resultados
      expect(ResultadoPartida.deCodigo('HOME_WIN'), ResultadoPartida.homeWin);
      expect(ResultadoPartida.deCodigo('HOME_TEAM'), ResultadoPartida.homeWin);
      expect(ResultadoPartida.deCodigo('DRAW'), ResultadoPartida.draw);
      expect(ResultadoPartida.deCodigo('AWAY_WIN'), ResultadoPartida.awayWin);
      expect(ResultadoPartida.deCodigo('AWAY_TEAM'), ResultadoPartida.awayWin);
      expect(ResultadoPartida.deCodigo(null), isNull);
    });

    test('7. Conversão de data/hora oficial UTC para fuso horário local do dispositivo (RN-MAT-005)', () {
      final utc = DateTime.utc(2026, 10, 25, 23, 0); // 23:00 UTC
      final partida = PartidaModel(
        id: 'footballdata_5006',
        timeMandante: 'Bahia',
        timeVisitante: 'Vitória',
        startsAtUtc: utc,
        statusDominio: StatusPartida.agendada,
      );

      final localEsperado = utc.toLocal();
      final dia = localEsperado.day.toString().padLeft(2, '0');
      final mes = localEsperado.month.toString().padLeft(2, '0');
      final ano = localEsperado.year.toString();
      final hora = localEsperado.hour.toString().padLeft(2, '0');
      final minuto = localEsperado.minute.toString().padLeft(2, '0');

      expect(partida.dataHoraLocalFormatada, '$dia/$mes/$ano às $hora:$minuto');
    });

    test('8. Serialização e desserialização a partir do Firestore preservam statusDominio e resultado', () {
      final docMap = {
        'id': 'footballdata_5007',
        'status': 'FINALIZADA',
        'result': 'AWAY_WIN',
        'homeScore': 1,
        'awayScore': 2,
        'startsAtUtc': '2026-11-05T20:00:00.000Z',
        'homeTeam': {
          'name': 'Vasco da Gama',
          'shortName': 'Vasco',
          'externalId': '1780',
        },
        'awayTeam': {
          'name': 'Botafogo',
          'shortName': 'Botafogo',
          'externalId': '1783',
        },
      };

      final partida = PartidaModel.fromFirestoreMap(
        docMap,
        'footballdata_5007',
      );

      expect(partida.statusDominio, StatusPartida.finalizada);
      expect(partida.resultado, ResultadoPartida.awayWin);
      expect(
        partida.resultadoNormalizadoDescricao,
        'Vitória do Visitante (Botafogo)',
      );
      expect(partida.isFinalizado, isTrue);
      expect(partida.podeCriarDesafio, isFalse);

      final json = partida.toJson();
      expect(json['statusDominio'], 'FINALIZADA');
      expect(json['resultado'], 'AWAY_WIN');
    });
  });

  group('Identificação do campeonato nos cards e nos detalhes', () {
    PartidaModel partida(String id, String? codigo, {String? campeonato}) =>
        PartidaModel(
          id: id,
          timeMandante: 'Casa $id',
          timeVisitante: 'Fora $id',
          startsAtUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
          statusDominio: StatusPartida.agendada,
          competitionCode: codigo,
          campeonato: campeonato,
        );

    testWidgets('card da Home mostra o nome da liga das 4 ligas', (
      tester,
    ) async {
      final esperado = {
        'BSA': 'Brasileirão Série A',
        'PL': 'Premier League',
        'SA': 'Serie A',
        'PD': 'La Liga',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final e in esperado.entries)
                  Carddepartidas(partida: partida(e.key, e.key)),
              ],
            ),
          ),
        ),
      );
      for (final e in esperado.entries) {
        final rotulo = find.byKey(Key('partida_campeonato_${e.key}'));
        expect(rotulo, findsOneWidget, reason: e.key);
        expect((tester.widget<Text>(rotulo)).data, e.value, reason: e.key);
      }
      // O código cru não aparece como texto de liga conhecida.
      expect(find.text('PL'), findsNothing);
      expect(find.text('PD'), findsNothing);
    });

    testWidgets('card com código desconhecido mostra o código e não quebra', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Carddepartidas(partida: partida('x1', 'XYZ'))),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('partida_campeonato_x1')))
            .data,
        'XYZ',
      );
    });

    testWidgets(
      'card de partida antiga (sem código) mostra Brasileirão Série A',
      (tester) async {
        final antiga = PartidaModel.fromFirestoreMap({
          'homeTeam': 'Santos',
          'awayTeam': 'Bahia',
          'status': 'SCHEDULED',
        }, 'antiga_1');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Carddepartidas(partida: antiga)),
          ),
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('partida_campeonato_antiga_1')),
              )
              .data,
          'Brasileirão Série A',
        );
      },
    );

    testWidgets('nome longo da liga não estoura o card em tela estreita', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Carddepartidas(
              partida: partida(
                'longo',
                'ZZZ',
                campeonato:
                    'Campeonato Muito Longo da Liga Internacional de Futebol',
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('detalhes mostram o nome da liga, não o código', (
      tester,
    ) async {
      final pl = PartidaModel(
        id: 'pl_1',
        timeMandante: 'Arsenal',
        timeVisitante: 'Chelsea',
        startsAtUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
        statusDominio: StatusPartida.agendada,
        campeonato: 'PL',
        competitionCode: 'PL',
        matchday: 12,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DetalhesDaPartidaSheet.exibir(context, pl),
                child: const Text('ABRIR'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Premier League'), findsOneWidget);
      expect(find.textContaining('PL · Rodada 12'), findsNothing);
    });
  });
}
