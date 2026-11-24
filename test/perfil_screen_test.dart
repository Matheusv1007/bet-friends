import 'dart:async';

import 'package:betfriends/app.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

/// Repositório em que cada `observarPorUid` abre um stream controlado pelo teste.
class _RepositorioControlado implements UserProfileRepository {
  final uidsObservados = <String>[];
  final _streams = <StreamController<UserProfile?>>[];

  StreamController<UserProfile?> get atual => _streams.last;

  @override
  Stream<PerfilObservado> observarPorUid(String uid) {
    uidsObservados.add(uid);
    final controller = StreamController<UserProfile?>();
    _streams.add(controller);
    return controller.stream.map(PerfilObservado.new);
  }

  @override
  Future<UserProfile?> buscarPorUid(String uid) => throw UnimplementedError();

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) =>
      throw UnimplementedError();
}

const _ana = UserProfile(
  uid: 'uid-ana',
  displayName: 'Ana Lima',
  username: 'AnaL',
  usernameNormalized: 'anal',
  email: 'ana@example.com',
);

UserProfileException _erro(UserProfileErrorCode code) =>
    UserProfileException(code, 'erro de teste');

void main() {
  late _RepositorioControlado repositorio;

  setUp(() => repositorio = _RepositorioControlado());

  Future<void> abrirPerfil(
    WidgetTester tester, {
    String? uid = 'uid-ana',
  }) async {
    final service = UserProfileService(
      authService: FakeAuthService(
        usuarioInicial: uid == null ? null : FakeUser(uid),
      ),
      repository: repositorio,
    );
    await tester.pumpWidget(
      Provider<UserProfileService>.value(
        value: service,
        child: const MaterialApp(home: PerfilScreen()),
      ),
    );
  }

  group('Estados da tela', () {
    testWidgets('mostra carregamento até o perfil chegar', (tester) async {
      await abrirPerfil(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('perfil_display_name')), findsNothing);
    });

    testWidgets('exibe nome e username reais do perfil', (tester) async {
      await abrirPerfil(tester);
      repositorio.atual.add(_ana);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('perfil_display_name'))).data,
        'Ana Lima',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('perfil_username'))).data,
        '@AnaL',
      );
      expect(find.text('A'), findsOneWidget); // inicial no avatar
    });

    testWidgets('observa somente o UID da sessão autenticada', (tester) async {
      await abrirPerfil(tester, uid: 'uid-ana');

      expect(repositorio.uidsObservados, ['uid-ana']);
    });

    testWidgets('não exibe e-mail, UID, saldos nem dados financeiros', (
      tester,
    ) async {
      await abrirPerfil(tester);
      repositorio.atual.add(_ana);
      await tester.pump();

      for (final texto in [
        'ana@example.com',
        'uid-ana',
        'anal',
        'saldo',
        'Saldo',
        'fichas',
        '1000',
        '1.000',
      ]) {
        expect(find.textContaining(texto), findsNothing, reason: texto);
      }
      expect(find.text('Extrato de BetCoins'), findsOneWidget);
    });

    testWidgets('acompanha alterações do perfil em tempo real', (tester) async {
      await abrirPerfil(tester);
      repositorio.atual.add(_ana);
      await tester.pump();

      repositorio.atual.add(
        const UserProfile(
          uid: 'uid-ana',
          displayName: 'Ana Souza',
          username: 'AnaL',
          usernameNormalized: 'anal',
          email: 'ana@example.com',
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const Key('perfil_display_name'))).data,
        'Ana Souza',
      );
    });

    testWidgets(
      'perfil inexistente mostra aviso, sem criar perfil nem oferecer nova tentativa',
      (tester) async {
        await abrirPerfil(tester);
        repositorio.atual.add(null);
        await tester.pump();

        expect(find.text('Perfil ainda não criado'), findsOneWidget);
        expect(find.text('Tentar novamente'), findsNothing);
        expect(repositorio.uidsObservados, ['uid-ana']);
      },
    );
  });

  group('Erros', () {
    testWidgets('falha de conexão mostra mensagem e permite tentar novamente', (
      tester,
    ) async {
      await abrirPerfil(tester);
      repositorio.atual.addError(_erro(UserProfileErrorCode.unavailable));
      await tester.pump();

      expect(find.text('Não foi possível carregar o perfil'), findsOneWidget);
      expect(find.textContaining('Sem conexão'), findsOneWidget);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(repositorio.uidsObservados, ['uid-ana', 'uid-ana']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repositorio.atual.add(_ana);
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('perfil_display_name'))).data,
        'Ana Lima',
      );
    });

    testWidgets('permissão negada mostra mensagem própria', (tester) async {
      await abrirPerfil(tester);
      repositorio.atual.addError(_erro(UserProfileErrorCode.permissionDenied));
      await tester.pump();

      expect(find.textContaining('não tem permissão'), findsOneWidget);
    });

    testWidgets('dados inválidos mostram mensagem própria', (tester) async {
      await abrirPerfil(tester);
      repositorio.atual.addError(_erro(UserProfileErrorCode.invalidData));
      await tester.pump();

      expect(find.textContaining('incompletos'), findsOneWidget);
    });

    testWidgets('sem sessão mostra aviso sem consultar o repositório', (
      tester,
    ) async {
      await abrirPerfil(tester, uid: null);
      await tester.pump();

      expect(find.textContaining('sessão expirou'), findsOneWidget);
      expect(repositorio.uidsObservados, isEmpty);
    });
  });

  group('Navegação a partir da Home', () {
    late FakeAuthService auth;

    Future<void> abrirApp(WidgetTester tester) async {
      auth = FakeAuthService(usuarioInicial: FakeUser('uid-ana'));
      await tester.pumpWidget(
        App(
          authService: auth,
          partidasService: CountingPartidasService(),
          userProfileService: UserProfileService(
            authService: auth,
            repository: repositorio,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // O perfil começa carregando (animação contínua): não usar pumpAndSettle aqui
    Future<void> abrirAbaPerfil(WidgetTester tester) async {
      await tester.tap(find.text('Perfil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Descarta a Home e o timer de atualização das partidas
    Future<void> encerrar(WidgetTester tester) =>
        tester.pumpWidget(const SizedBox());

    testWidgets(
      'aba Perfil abre o perfil do usuário logado e Voltar retorna à Home',
      (tester) async {
        await abrirApp(tester);

        await abrirAbaPerfil(tester);
        expect(find.byType(PerfilScreen), findsOneWidget);
        // A Home (saudação) e a tela de Perfil observam só o perfil do usuário logado
        expect(repositorio.uidsObservados, ['uid-ana', 'uid-ana']);

        repositorio.atual.add(_ana);
        await tester.pump();
        expect(find.text('@AnaL'), findsNWidgets(2)); // cabeçalho e grupo Dados

        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();
        expect(find.byType(PerfilScreen), findsNothing);
        expect(find.text('PARTIDAS'), findsOneWidget);

        await encerrar(tester);
      },
    );

    testWidgets('botão Voltar do sistema também retorna à Home', (
      tester,
    ) async {
      await abrirApp(tester);
      await abrirAbaPerfil(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PerfilScreen), findsNothing);
      expect(find.text('PARTIDAS'), findsOneWidget);

      await encerrar(tester);
    });

    testWidgets(
      'sessão encerrada com o perfil aberto volta ao Login (AuthGate)',
      (tester) async {
        await abrirApp(tester);
        await abrirAbaPerfil(tester);

        auth.encerrarSessaoExternamente();
        await tester.pumpAndSettle();

        expect(find.byType(PerfilScreen), findsNothing);
        expect(find.byKey(const Key('login_entrar')), findsOneWidget);
      },
    );
  });

  group('Layout em grupos', () {
    Future<void> perfilAberto(WidgetTester tester) async {
      await abrirPerfil(tester);
      repositorio.atual.add(_ana);
      await tester.pump();
    }

    testWidgets(
      'mostra os grupos DADOS, ATIVIDADE, INFORMAÇÕES e a zona de risco no fim',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await perfilAberto(tester);

        for (final titulo in [
          'DADOS',
          'ATIVIDADE',
          'INFORMAÇÕES',
          'ZONA DE RISCO',
        ]) {
          expect(find.text(titulo), findsOneWidget, reason: titulo);
        }
        double y(String t) => tester.getTopLeft(find.text(t)).dy;
        expect(y('DADOS'), lessThan(y('ATIVIDADE')));
        expect(y('ATIVIDADE'), lessThan(y('INFORMAÇÕES')));
        expect(y('INFORMAÇÕES'), lessThan(y('ZONA DE RISCO')));
        for (final linha in [
          'Extrato de BetCoins',
          'Meus amigos',
          'Buscar amigos',
          'Solicitações de amizade',
          'Informações e créditos',
        ]) {
          expect(find.text(linha), findsOneWidget, reason: linha);
        }
        expect(find.byIcon(Icons.chevron_right), findsNWidgets(5));
        expect(
          find.text('Ação permanente: apaga seu perfil e suas amizades.'),
          findsOneWidget,
        );
        expect(y('Excluir conta'), greaterThan(y('ZONA DE RISCO')));
        // Só uma ação destrutiva e nenhum botão em caixa alta
        expect(find.text('EDITAR NOME'), findsNothing);
        expect(find.text('EXCLUIR CONTA'), findsNothing);
      },
    );

    testWidgets('grupo Dados mostra o nome e o username com @', (tester) async {
      await perfilAberto(tester);

      expect(find.text('Nome de exibição'), findsOneWidget);
      expect(find.text('Nome de usuário'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('perfil_dados_nome'))).data,
        'Ana Lima',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('perfil_dados_usuario'))).data,
        '@AnaL',
      );
    });

    testWidgets(
      '"Editar" abre o diálogo do nome de exibição com o nome atual',
      (tester) async {
        await perfilAberto(tester);

        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();

        expect(find.text('Editar nome de exibição'), findsOneWidget);
        final campo = tester.widget<TextFormField>(
          find.descendant(
            of: find.byKey(const Key('editar_nome_campo')),
            matching: find.byType(TextFormField),
          ),
        );
        expect(campo.controller!.text, 'Ana Lima');
      },
    );
  });
}
