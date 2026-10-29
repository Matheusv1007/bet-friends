// Home no escopo do MVP: navegação sem Ranking (D-002), saudação com o nome
// do perfil e nenhum dado fictício apresentado como real.

import 'dart:async';

import 'package:betfriends/app.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:betfriends/telas_principais/homePage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

/// Repositório controlado pelo teste: cada `observarPorUid` recebe as mesmas emissões.
class _RepositorioControlado implements UserProfileRepository {
  final _emissoes = StreamController<PerfilObservado>.broadcast();

  void emitir(UserProfile? perfil) => _emissoes.add(PerfilObservado(perfil));

  void falhar(UserProfileException erro) => _emissoes.addError(erro);

  @override
  Stream<PerfilObservado> observarPorUid(String uid) => _emissoes.stream;

  @override
  Future<UserProfile?> buscarPorUid(String uid) => throw UnimplementedError();

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) =>
      throw UnimplementedError();
}

UserProfile _perfil(String displayName) => UserProfile(
      uid: 'uid-ana',
      displayName: displayName,
      username: 'AnaL',
      usernameNormalized: 'anal',
      email: 'ana@example.com',
    );

String _saudacao(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('home_saudacao'))).data!;

void main() {
  late _RepositorioControlado repositorio;

  setUp(() => repositorio = _RepositorioControlado());

  // A emissão chega durante o primeiro quadro e a saudação é reconstruída no seguinte
  Future<void> entregar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> abrirHome(WidgetTester tester) async {
    final auth = FakeAuthService(usuarioInicial: FakeUser('uid-ana'));
    await tester.pumpWidget(App(
      authService: auth,
      partidasService: CountingPartidasService(),
      userProfileService: UserProfileService(authService: auth, repository: repositorio),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Homepage), findsOneWidget);
  }

  // Descarta a Home e o timer de atualização das partidas
  Future<void> encerrar(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  group('barra de navegação', () {
    testWidgets('tem só Home, Desafios e Perfil, sem Ranking', (tester) async {
      await abrirHome(tester);

      final barra = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(barra.items.map((i) => i.label), ['Home', 'Desafios', 'Perfil']);
      expect(find.text('Ranking'), findsNothing);

      await encerrar(tester);
    });

    testWidgets('Desafios abre Criar Desafio e Voltar retorna à Home', (tester) async {
      await abrirHome(tester);

      await tester.tap(find.text('Desafios'));
      await tester.pumpAndSettle();
      expect(find.byType(CriarDesafioScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CriarDesafioScreen), findsNothing);
      expect(find.text('PARTIDAS'), findsOneWidget);

      await encerrar(tester);
    });

    testWidgets('Perfil (índice 2) abre a tela de Perfil', (tester) async {
      await abrirHome(tester);

      await tester.tap(find.text('Perfil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PerfilScreen), findsOneWidget);
      expect(find.byType(CriarDesafioScreen), findsNothing);

      await encerrar(tester);
    });

    testWidgets('Home mantém a tela e fica selecionada', (tester) async {
      await abrirHome(tester);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(Homepage), findsOneWidget);
      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 0);

      await encerrar(tester);
    });
  });

  group('cabeçalho', () {
    testWidgets('sem valores fixos: nada de "Olá, Pedro" nem "1.500 fichas"', (tester) async {
      await abrirHome(tester);

      expect(find.text('Olá, Pedro'), findsNothing);
      expect(find.textContaining('1.500'), findsNothing);
      expect(find.textContaining('1.000'), findsNothing);
      expect(find.textContaining('fichas'), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('home_saldo'))).data, 'Saldo indisponível');

      await encerrar(tester);
    });

    testWidgets('mostra o nome de exibição do perfil quando disponível', (tester) async {
      await abrirHome(tester);
      expect(_saudacao(tester), 'Olá!', reason: 'neutra enquanto carrega');

      repositorio.emitir(_perfil('Ana Lima'));
      await entregar(tester);
      expect(_saudacao(tester), 'Olá, Ana Lima');

      // Nome alterado no Perfil (KAN-29) chega pelo mesmo stream
      repositorio.emitir(_perfil('Ana Souza'));
      await entregar(tester);
      expect(_saudacao(tester), 'Olá, Ana Souza');

      await encerrar(tester);
    });

    testWidgets('perfil inexistente: saudação neutra, sem criar perfil', (tester) async {
      await abrirHome(tester);
      repositorio.emitir(null);
      await entregar(tester);

      expect(_saudacao(tester), 'Olá!');
      expect(find.textContaining('Perfil ainda não criado'), findsNothing);

      await encerrar(tester);
    });

    testWidgets('perfil indisponível (sem conexão): saudação neutra, sem erro na Home', (tester) async {
      await abrirHome(tester);
      repositorio.emitir(_perfil('Ana Lima'));
      await entregar(tester);
      repositorio.falhar(const UserProfileException(UserProfileErrorCode.unavailable, 'x'));
      await entregar(tester);

      expect(_saudacao(tester), 'Olá!');
      expect(find.text('PARTIDAS'), findsOneWidget);

      await encerrar(tester);
    });

    testWidgets('sem o serviço de perfil, a Home funciona com saudação neutra', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => PartidasProvider(partidasService: CountingPartidasService()),
          child: const Homepage(),
        ),
      ));
      await tester.pump();

      expect(_saudacao(tester), 'Olá!');
      expect(tester.widget<Text>(find.byKey(const Key('home_saldo'))).data, 'Saldo indisponível');

      await encerrar(tester);
    });

    testWidgets('nome longo não estoura o cabeçalho', (tester) async {
      await abrirHome(tester);
      repositorio.emitir(_perfil('N' * 60));
      await entregar(tester);

      expect(tester.takeException(), isNull);
      expect(_saudacao(tester), 'Olá, ${'N' * 60}');

      await encerrar(tester);
    });
  });

  testWidgets('desafios ativos fixos aparecem marcados como demonstrativos', (tester) async {
    await abrirHome(tester);

    await tester.scrollUntilVisible(find.text('DESAFIOS ATIVOS'), 300);
    expect(find.byKey(const Key('desafios_ativos_demonstrativo')), findsOneWidget);

    await encerrar(tester);
  });
}
