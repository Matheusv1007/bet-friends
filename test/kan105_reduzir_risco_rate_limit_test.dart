// Cache de partidas e redução de consultas redundantes ao Firestore (KAN-105).
// Valida cooldown, navegação sem repetição de consultas e atualização explícita.

import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/data/firestore/partidas_repository.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/telas_principais/homePage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

/// Repositório de partidas com contador de consultas para testes de navegação e cache.
class _ContadorPartidasRepository implements PartidasRepository {
  int chamadasGetPartidas = 0;
  List<PartidaModel> partidasRetorno;
  Object? erroParaLancar;

  _ContadorPartidasRepository({this.partidasRetorno = const [], this.erroParaLancar});

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
    test('Limite de requisições do Firestore é tratado de forma compreensível', () {
      final erro = FirebaseException(plugin: 'cloud_firestore', code: 'resource-exhausted');
      final msg = PartidasService.formatErrorMessage(erro);

      expect(
        msg,
        'Limite de requisições atingido. Aguarde alguns instantes e tente novamente.',
      );
    });

    test('Cooldown após limite do Firestore suspende novas consultas automáticas', () async {
      final contadorService = _ContadorPartidasRepository(
        erroParaLancar: FirebaseException(plugin: 'cloud_firestore', code: 'resource-exhausted'),
      );
      final provider = PartidasProvider(partidasService: PartidasService(repository: contadorService));

      // 1. Primeira consulta falha por limite do Firestore
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
      'Navegação Home → Criar Desafio → Home não duplica requisições (exatamente 1 chamada)',
      (tester) async {
        final contadorService = _ContadorPartidasRepository(
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
        final provider = PartidasProvider(partidasService: PartidasService(repository: contadorService));
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

    test('Puxe para atualizar (forcar: true) ignora cache e executa nova carga', () async {
      final contadorService = _ContadorPartidasRepository(
        partidasRetorno: [
          PartidaModel(id: '1', timeMandante: 'A', timeVisitante: 'B'),
        ],
      );
      final provider = PartidasProvider(partidasService: PartidasService(repository: contadorService));

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

    test('Partidas sem minuto mantêm minuto nulo sem introduzir dados fictícios', () {
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
