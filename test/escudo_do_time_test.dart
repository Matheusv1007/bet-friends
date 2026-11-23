import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/widgets_home_page/card_de_partidas.dart';
import 'package:betfriends/widgets_home_page/escudo_do_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget filho) => MaterialApp(home: Scaffold(body: Center(child: filho)));

void main() {
  group('EscudoDoTime', () {
    testWidgets('sem URL mostra o ícone de escudo, sem tentar carregar imagem', (tester) async {
      await tester.pumpWidget(_app(const EscudoDoTime(url: null, nome: 'Flamengo')));

      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('URL de PNG usa Image.network e URL de SVG usa SvgPicture, mesmo com parâmetros', (tester) async {
      await tester.pumpWidget(_app(
        const EscudoDoTime(url: 'https://crests.football-data.org/1765.png', nome: 'Fluminense'),
      ));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);

      await tester.pumpWidget(_app(
        const EscudoDoTime(url: 'https://crests.football-data.org/6684.SVG?v=2', nome: 'Internacional'),
      ));
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('imagem que não carrega cai no ícone de escudo, sem exceção', (tester) async {
      // O ambiente de teste responde 400 a qualquer requisição de rede.
      await tester.pumpWidget(_app(
        const EscudoDoTime(url: 'https://crests.football-data.org/1765.png', nome: 'Fluminense'),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('o escudo do documento de partida chega ao card (homeTeam.crest -> logoMandante)', (tester) async {
    final partida = PartidaModel.fromFirestoreMap({
      'status': 'AGENDADA',
      'startsAtUtc': '2026-12-01T19:30:00.000Z',
      'homeTeam': {
        'externalId': '1765',
        'name': 'Fluminense FC',
        'shortName': 'Fluminense',
        'crest': 'https://crests.football-data.org/1765.svg',
      },
      'awayTeam': {'externalId': '6684', 'name': 'SC Internacional', 'shortName': 'Internacional'},
    }, 'footballdata_1');

    expect(partida.logoMandante, 'https://crests.football-data.org/1765.svg');
    expect(partida.logoVisitante, isNull);

    await tester.pumpWidget(_app(Carddepartidas(partida: partida)));

    expect(find.byType(SvgPicture), findsOneWidget);
    // O visitante, sem escudo informado, não tenta carregar imagem.
    expect(find.byType(Image), findsNothing);
  });
}
