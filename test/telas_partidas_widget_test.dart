import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/api/api_client.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/telas_principais/homePage.dart';

class FakeTestPartidasService extends PartidasService {
  List<PartidaModel> matches;
  Object? error;

  FakeTestPartidasService({this.matches = const [], this.error});

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async {
    if (error != null) {
      throw error!;
    }
    return matches;
  }
}

Widget buildTestableWidget({
  required Widget child,
  required PartidasProvider provider,
}) {
  return MaterialApp(
    home: ChangeNotifierProvider<PartidasProvider>.value(
      value: provider,
      child: child,
    ),
  );
}

void main() {
  group('HomePage - Cenários de Interface', () {
    testWidgets('Exibe mensagem amigável de erro e botão Tentar novamente quando ocorre falha', (tester) async {
      final fakeService = FakeTestPartidasService(
        error: ApiException(statusCode: 403),
      );
      final provider = PartidasProvider(partidasService: fakeService);
      await provider.carregarPartidas();

      await tester.pumpWidget(
        buildTestableWidget(child: const Homepage(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Erro ao carregar partidas'), findsOneWidget);
      expect(
        find.text('Não foi possível autorizar o acesso ao serviço de partidas.'),
        findsOneWidget,
      );
      expect(find.text('TENTAR NOVAMENTE'), findsOneWidget);
    });

    testWidgets('Exibe estado vazio com botão Atualizar quando lista vem vazia', (tester) async {
      final fakeService = FakeTestPartidasService(matches: []);
      final provider = PartidasProvider(partidasService: fakeService);
      await provider.carregarPartidas();

      await tester.pumpWidget(
        buildTestableWidget(child: const Homepage(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma partida disponível'), findsOneWidget);
      expect(find.text('ATUALIZAR'), findsOneWidget);
    });

    testWidgets('Exibe lista de partidas quando a resposta é válida', (tester) async {
      final fakeService = FakeTestPartidasService(
        matches: [
          PartidaModel(
            id: '1',
            timeMandante: 'Flamengo',
            timeVisitante: 'Vasco',
            status: 'PRÓXIMO JOGO',
            horario: 'Amanhã 19:00',
          ),
        ],
      );
      final provider = PartidasProvider(partidasService: fakeService);
      await provider.carregarPartidas();

      await tester.pumpWidget(
        buildTestableWidget(child: const Homepage(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Flamengo'), findsOneWidget);
      expect(find.text('Vasco'), findsOneWidget);
      expect(find.text('PRÓXIMO JOGO'), findsOneWidget);
    });
  });

  group('CriarDesafioScreen - Cenários de Interface', () {
    testWidgets('Exibe erro amigável e botão de tentar novamente em CriarDesafioScreen', (tester) async {
      final fakeService = FakeTestPartidasService(
        error: ApiException(statusCode: 500),
      );
      final provider = PartidasProvider(partidasService: fakeService);
      await provider.carregarPartidas();

      await tester.pumpWidget(
        buildTestableWidget(child: const CriarDesafioScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Erro ao carregar partidas'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('Exibe estado vazio quando não há partidas em CriarDesafioScreen', (tester) async {
      final fakeService = FakeTestPartidasService(matches: []);
      final provider = PartidasProvider(partidasService: fakeService);
      await provider.carregarPartidas();

      await tester.pumpWidget(
        buildTestableWidget(child: const CriarDesafioScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma partida encontrada no momento'), findsOneWidget);
      expect(find.text('Carregar partidas'), findsOneWidget);
    });

    testWidgets('Exibe partidas elegíveis para desafio em CriarDesafioScreen', (tester) async {
      final fakeService = FakeTestPartidasService(
        matches: [
          PartidaModel(
            id: '10',
            timeMandante: 'Corinthians',
            timeVisitante: 'Palmeiras',
            status: 'PRÓXIMO JOGO',
            horario: 'Hoje 20:00',
          ),
          PartidaModel(
            id: '11',
            timeMandante: 'Santos',
            timeVisitante: 'São Paulo',
            status: 'FINALIZADO',
          ),
        ],
      );
      final provider = PartidasProvider(partidasService: fakeService);
      await provider.carregarPartidas();

      await tester.pumpWidget(
        buildTestableWidget(child: const CriarDesafioScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      // Jogo agendado elegível aparece
      expect(find.text('Corinthians'), findsOneWidget);
      expect(find.text('Palmeiras'), findsOneWidget);
      // Jogo finalizado não é listado para criar novo desafio
      expect(find.text('Santos'), findsNothing);
    });
  });
}
