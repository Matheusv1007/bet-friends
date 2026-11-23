// Visualizar informações e créditos do aplicativo (KAN-54; RNF-011, RNF-012, D-015)
//
// Critérios de Aceitação:
// - Existe tela acessível de informações/créditos;
// - Texto visível contém exatamente: Dados fornecidos por football-data.org;
// - A atribuição permanece disponível independentemente do estado atual do provedor;
// - Tela não adiciona funcionalidades além das informações e créditos necessários;
// - MVP não depende de escudos, logotipos ou outras imagens cujo licenciamento não está confirmado.
//
// Testes / Validação:
// - Abrir tela;
// - Validar texto de atribuição;
// - Validar que ausência de imagens licenciadas não quebra a tela.

import 'dart:async';

import 'package:betfriends/data/firestore/friendship_repository.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:betfriends/models/friendship_model.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/models/usuario_publico.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/services/friendship_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:betfriends/tela_sobre/tela_informacoes_creditos.dart';
import 'package:betfriends/telas_principais/home_page.dart';
import 'package:betfriends/widgets_home_page/card_de_partidas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

class _FakeUserProfileRepository implements UserProfileRepository {
  final _controller = StreamController<PerfilObservado>.broadcast();

  void emitir(UserProfile? perfil) =>
      _controller.add(PerfilObservado(perfil));

  @override
  Stream<PerfilObservado> observarPorUid(String uid) => _controller.stream;

  @override
  Future<UserProfile?> buscarPorUid(String uid) async => null;

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {}
}

class _FakeChallengeService implements ChallengeService {
  final _desafiosController = StreamController<List<ChallengeModel>>.broadcast();

  @override
  Stream<List<ChallengeModel>> observarDesafios() async* {
    yield const [];
    yield* _desafiosController.stream;
  }

  @override
  Future<List<ChallengeModel>> listarDesafios() async => [];

  @override
  Future<int?> buscarSaldoDisponivel() async => 1000;

  @override
  Future<List<AmigoItem>> listarAmigosAceitos() async => [];

  @override
  Future<CriarDesafioResponse> criarDesafio({
    required String challengedId,
    required String matchId,
    required Palpite challengerPrediction,
    required int amount,
  }) async =>
      throw UnimplementedError();

  @override
  Future<AceitarDesafioResponse> aceitarDesafio({
    required String challengeId,
    required Palpite challengedPrediction,
  }) async =>
      throw UnimplementedError();

  @override
  Future<EncerrarDesafioResponse> recusarDesafio({required String challengeId}) async =>
      throw UnimplementedError();

  @override
  Future<EncerrarDesafioResponse> cancelarDesafio({required String challengeId}) async =>
      throw UnimplementedError();
}

class _FakePartidasService extends PartidasService {
  _FakePartidasService() : super(firestore: null);

  @override
  Future<List<PartidaModel>> getPartidas({int limit = 15}) async => [];
}

class _FakeFriendshipRepository implements FriendshipRepository {
  @override
  Future<List<UsuarioPublico>> listarAmigosAceitos() async => [];

  @override
  Future<List<SolicitacaoAmizade>> listarSolicitacoesPendentes() async => [];

  @override
  Future<ResultadoAceiteAmizade> aceitarSolicitacaoAmizade(String id) async =>
      throw UnimplementedError();

  @override
  Future<ResultadoEnvioAmizade> enviarSolicitacaoAmizade(String to) async =>
      throw UnimplementedError();

  @override
  Future<ResultadoRecusaAmizade> recusarSolicitacaoAmizade(String id) async =>
      throw UnimplementedError();
}

void main() {
  group('TelaInformacoesCreditos (KAN-54)', () {
    testWidgets('exibe tela de informações e créditos com dados mínimos do app', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TelaInformacoesCreditos(),
        ),
      );
      await tester.pumpAndSettle();

      // AppBar e título
      expect(find.byKey(const Key('appbar_informacoes_creditos')), findsOneWidget);
      expect(find.text('Informações e Créditos'), findsOneWidget);
      expect(find.byTooltip('Voltar'), findsOneWidget);

      // Nome do app e versão mínima do MVP
      expect(find.byKey(const Key('app_nome')), findsOneWidget);
      expect(find.text('BetFriends'), findsOneWidget);
      expect(find.byKey(const Key('app_versao')), findsOneWidget);
      expect(find.text('Versão 1.0.0 (MVP)'), findsOneWidget);
    });

    testWidgets(
      'texto visível contém exatamente: Dados fornecidos por football-data.org (RNF-011)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TelaInformacoesCreditos(),
          ),
        );
        await tester.pumpAndSettle();

        // Critério exato: "Dados fornecidos por football-data.org"
        expect(
          find.text('Dados fornecidos por football-data.org'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('texto_atribuicao_football_data')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('card_atribuicao_provedor')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'atribuição permanece disponível independentemente do estado do provedor',
      (tester) async {
        // A tela é puramente estática e não efetua chamadas à rede ou API externa
        await tester.pumpWidget(
          const MaterialApp(
            home: TelaInformacoesCreditos(),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('nota_disponibilidade_atribuicao')),
          findsOneWidget,
        );
        expect(
          find.text('Dados fornecidos por football-data.org'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tela não adiciona funcionalidades além das informações e créditos necessários (D-015)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TelaInformacoesCreditos(),
          ),
        );
        await tester.pumpAndSettle();

        // Não há campos de compra de moedas, links promocionais externos, feed ou ranking
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Comprar BetCoins'), findsNothing);
        expect(find.text('Ranking'), findsNothing);
        expect(find.text('Feed'), findsNothing);

        // Cards informativos legítimos
        expect(find.byKey(const Key('card_propriedade_intelectual')), findsOneWidget);
        expect(find.byKey(const Key('card_escopo_mvp')), findsOneWidget);
      },
    );

    testWidgets(
      'a tela de créditos não carrega imagens e informa que os escudos vêm do provedor (RNF-012)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TelaInformacoesCreditos(),
          ),
        );
        await tester.pumpAndSettle();

        // A tela não carrega Image.network nem imagens externas não confirmadas
        expect(find.byType(Image), findsNothing);

        // O texto sobre licenciamento e escudos está presente
        expect(find.byKey(const Key('texto_licenciamento_escudos')), findsOneWidget);
      },
    );

    testWidgets(
      'ausência de imagens/escudos licenciados não quebra a renderização das partidas',
      (tester) async {
        // Cenário em que a partida não possui escudos (logos null ou inexistentes)
        final partidaSemEscudos = PartidaModel(
          id: 'partida-sem-escudo',
          timeMandante: 'Flamengo',
          timeVisitante: 'Fluminense',
          golsMandante: 2,
          golsVisitante: 1,
          status: 'FINALIZADO',
          logoMandante: null,
          logoVisitante: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Carddepartidas(partida: partidaSemEscudos),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Renderiza os nomes dos clubes e placar normalmente
        expect(find.text('Flamengo'), findsOneWidget);
        expect(find.text('Fluminense'), findsOneWidget);
        expect(find.text('2 - 1'), findsOneWidget);

        // Utiliza ícones de escudo estilizados de fallback sem estourar exceções
        expect(find.byIcon(Icons.shield), findsNWidgets(2));
      },
    );

    testWidgets('pode ser acessada a partir da tela de Perfil (PerfilScreen)', (
      tester,
    ) async {
      final fakeRepo = _FakeUserProfileRepository();
      final auth = FakeAuthService(
        usuarioInicial: FakeUser('user-teste'),
      );
      final profileService = UserProfileService(
        repository: fakeRepo,
        authService: auth,
      );
      final friendshipService = FriendshipService(
        repository: _FakeFriendshipRepository(),
        authService: auth,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserProfileService>.value(value: profileService),
            Provider<FriendshipService>.value(value: friendshipService),
          ],
          child: const MaterialApp(
            home: PerfilScreen(),
          ),
        ),
      );

      fakeRepo.emitir(
        const UserProfile(
          uid: 'user-teste',
          displayName: 'Test User',
          username: 'testuser',
          usernameNormalized: 'testuser',
          email: 'test@example.com',
        ),
      );
      await tester.pump();
      await tester.pump();

      final btnCreditos = find.byKey(const Key('perfil_informacoes_creditos'));
      await tester.scrollUntilVisible(btnCreditos, 200);
      expect(btnCreditos, findsOneWidget);

      await tester.tap(btnCreditos);
      await tester.pumpAndSettle();

      // Navegou até TelaInformacoesCreditos
      expect(find.byType(TelaInformacoesCreditos), findsOneWidget);
      expect(
        find.text('Dados fornecidos por football-data.org'),
        findsOneWidget,
      );
    });

    testWidgets('pode ser acessada a partir do menu da conta na Homepage', (
      tester,
    ) async {
      final fakeRepo = _FakeUserProfileRepository();
      final auth = FakeAuthService(
        usuarioInicial: FakeUser('user-teste'),
      );
      final profileService = UserProfileService(
        repository: fakeRepo,
        authService: auth,
      );
      final challengeService = _FakeChallengeService();
      final partidasService = _FakePartidasService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserProfileService>.value(value: profileService),
            ChangeNotifierProvider<PartidasProvider>(
              create: (_) => PartidasProvider(partidasService: partidasService),
            ),
          ],
          child: MaterialApp(
            home: Homepage(
              authService: auth,
              challengeService: challengeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abre menu da conta
      final menuConta = find.byKey(const Key('menu_conta'));
      expect(menuConta, findsOneWidget);
      await tester.tap(menuConta);
      await tester.pumpAndSettle();

      // Item "Informações e Créditos" no menu
      final itemSobre = find.byKey(const Key('menu_item_sobre'));
      expect(itemSobre, findsOneWidget);

      await tester.tap(itemSobre);
      await tester.pumpAndSettle();

      // Navegou até TelaInformacoesCreditos
      expect(find.byType(TelaInformacoesCreditos), findsOneWidget);
      expect(
        find.text('Dados fornecidos por football-data.org'),
        findsOneWidget,
      );
    });
  });
}
