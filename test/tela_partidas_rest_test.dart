import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:betfriends/services/api/partidas_rest_service.dart';
import 'package:betfriends/tela_academica/tela_partidas_rest.dart';
import 'package:betfriends/widgets_homePage/cardDePartidas.dart';

void main() {
  group('TelaPartidasRest - Widget Tests (Consumo REST GET Acadêmico)', () {
    testWidgets('exibe partidas em lista ao obter sucesso via GET', (tester) async {
      final mockData = {
        'success': true,
        'total': 2,
        'matches': [
          {
            'id': 'rest-1',
            'startsAtUtc': '2026-07-01T19:00:00.000Z',
            'status': 'AGENDADA',
            'homeTeam': {'name': 'Cruzeiro', 'shortName': 'Cruzeiro'},
            'awayTeam': {'name': 'Atlético-MG', 'shortName': 'Atlético-MG'},
          },
          {
            'id': 'rest-2',
            'startsAtUtc': '2026-07-01T21:30:00.000Z',
            'status': 'FINALIZADA',
            'homeTeam': {'name': 'Bahia', 'shortName': 'Bahia'},
            'awayTeam': {'name': 'Vitória', 'shortName': 'Vitória'},
            'homeScore': 1,
            'awayScore': 0,
          },
        ],
      };

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockData), 200);
      });

      final service = PartidasRestService(httpClient: client);

      await tester.pumpWidget(MaterialApp(
        home: TelaPartidasRest(restService: service),
      ));

      // Enquanto carrega
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Encontra a lista e os cards das partidas
      expect(find.byKey(const Key('rest_matches_list')), findsOneWidget);
      expect(find.byType(Carddepartidas), findsNWidgets(2));
      expect(find.text('Cruzeiro'), findsOneWidget);
      expect(find.text('Atlético-MG'), findsOneWidget);
      expect(find.text('Bahia'), findsOneWidget);
      expect(find.text('Vitória'), findsOneWidget);
    });

    testWidgets('exibe container vazio quando endpoint retorna lista vazia', (tester) async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'matches': []}), 200);
      });

      final service = PartidasRestService(httpClient: client);

      await tester.pumpWidget(MaterialApp(
        home: TelaPartidasRest(restService: service),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rest_empty_container')), findsOneWidget);
      expect(find.text('Nenhuma partida retornada pelo endpoint REST'), findsOneWidget);
    });

    testWidgets('exibe mensagem amigável e botão tentar novamente quando ocorre erro', (tester) async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'matches': [
              {
                'id': 'rest-success',
                'startsAtUtc': '2026-07-01T19:00:00.000Z',
                'status': 'AGENDADA',
                'homeTeam': {'name': 'Santos', 'shortName': 'Santos'},
                'awayTeam': {'name': 'Vasco', 'shortName': 'Vasco'},
              }
            ],
          }),
          200,
        );
      });

      final service = PartidasRestService(httpClient: client);

      await tester.pumpWidget(MaterialApp(
        home: TelaPartidasRest(restService: service),
      ));
      await tester.pumpAndSettle();

      // Exibe estado de erro amigável sem quebrar a tela
      expect(find.byKey(const Key('rest_error_container')), findsOneWidget);
      expect(find.text('Falha na comunicação REST'), findsOneWidget);
      expect(find.byKey(const Key('rest_retry_button')), findsOneWidget);

      // Clica em tentar novamente
      await tester.tap(find.byKey(const Key('rest_retry_button')));
      await tester.pumpAndSettle();

      // Agora recupera com sucesso
      expect(find.byKey(const Key('rest_matches_list')), findsOneWidget);
      expect(find.text('Santos'), findsOneWidget);
      expect(find.text('Vasco'), findsOneWidget);
    });
  });
}
