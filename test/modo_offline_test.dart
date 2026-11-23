// Comportamento da tela de Perfil sem conexão (KAN-24; RN-OFF-001 a 003,
// RNF-009). O repositório simula o Firestore: o teste decide quando o dado
// vem do cache e quando uma gravação falha por falta de conexão.

import 'dart:async';

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

const _semConexao = UserProfileException(
  UserProfileErrorCode.unavailable,
  'Serviço indisponível.',
);

class _RepositorioComConexao implements UserProfileRepository {
  _RepositorioComConexao(this._perfil);

  UserProfile _perfil;
  final _emissoes = StreamController<PerfilObservado>.broadcast();
  final gravacoes = <String>[];

  /// Sem conexão, gravar falha como a transação do Firestore.
  bool online = true;

  UserProfile get perfil => _perfil;

  /// Emite o perfil atual como confirmado pelo servidor ou vindo do cache.
  void emitir({required bool doCache}) =>
      _emissoes.add(PerfilObservado(_perfil, doCache: doCache));

  void falharLeitura(UserProfileException erro) => _emissoes.addError(erro);

  @override
  Stream<PerfilObservado> observarPorUid(String uid) => _emissoes.stream;

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {
    gravacoes.add(displayName);
    if (!online) throw _semConexao;
    _perfil = UserProfile(
      uid: _perfil.uid,
      displayName: displayName,
      username: _perfil.username,
      usernameNormalized: _perfil.usernameNormalized,
      email: _perfil.email,
    );
    emitir(doCache: false);
  }

  @override
  Future<UserProfile?> buscarPorUid(String uid) => throw UnimplementedError();
}

const _ana = UserProfile(
  uid: 'uid-ana',
  displayName: 'Ana Lima',
  username: 'AnaL',
  usernameNormalized: 'anal',
  email: 'ana@example.com',
);

final _banner = find.byKey(const Key('perfil_sem_conexao'));
final _editar = find.byKey(const Key('perfil_editar_nome'));
final _campo = find.byKey(const Key('editar_nome_campo'));
final _salvar = find.byKey(const Key('editar_nome_salvar'));
final _erroDialogo = find.byKey(const Key('editar_nome_erro'));

String _nomeExibido(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('perfil_display_name'))).data!;

void main() {
  late _RepositorioComConexao repositorio;

  setUp(() => repositorio = _RepositorioComConexao(_ana));

  Future<void> abrirPerfil(WidgetTester tester, {required bool doCache}) async {
    await tester.pumpWidget(
      Provider<UserProfileService>.value(
        value: UserProfileService(
          authService: FakeAuthService(usuarioInicial: FakeUser('uid-ana')),
          repository: repositorio,
        ),
        child: const MaterialApp(home: PerfilScreen()),
      ),
    );
    repositorio.emitir(doCache: doCache);
    await tester.pumpAndSettle();
  }

  Future<void> tentarSalvar(WidgetTester tester, String nome) async {
    await tester.tap(_editar);
    await tester.pumpAndSettle();
    await tester.enterText(_campo, nome);
    await tester.tap(_salvar);
    await tester.pumpAndSettle();
  }

  testWidgets('online: perfil confirmado pelo servidor, sem aviso e com edição', (tester) async {
    await abrirPerfil(tester, doCache: false);

    expect(_nomeExibido(tester), 'Ana Lima');
    expect(_banner, findsNothing);

    await tentarSalvar(tester, 'Ana Souza');
    expect(repositorio.gravacoes, ['Ana Souza']);
    expect(find.text('Nome de exibição atualizado.'), findsOneWidget);
  });

  testWidgets('offline com cache: exibe o último perfil conhecido e avisa', (tester) async {
    await abrirPerfil(tester, doCache: true);

    expect(_nomeExibido(tester), 'Ana Lima');
    expect(find.text('@AnaL'), findsOneWidget);
    expect(_banner, findsOneWidget);
    expect(find.textContaining('Sem conexão. Exibindo os últimos dados salvos'), findsOneWidget);
  });

  testWidgets('offline com cache: editar pede conexão e não abre o diálogo nem grava', (tester) async {
    await abrirPerfil(tester, doCache: true);

    await tester.tap(_editar);
    await tester.pumpAndSettle();

    expect(find.text('Sem conexão. Conecte-se à internet para alterar o nome.'), findsOneWidget);
    expect(_campo, findsNothing);
    expect(repositorio.gravacoes, isEmpty);
  });

  testWidgets('offline sem cache: informa a falta de conexão e oferece tentar de novo', (tester) async {
    await tester.pumpWidget(
      Provider<UserProfileService>.value(
        value: UserProfileService(
          authService: FakeAuthService(usuarioInicial: FakeUser('uid-ana')),
          repository: repositorio,
        ),
        child: const MaterialApp(home: PerfilScreen()),
      ),
    );
    repositorio.falharLeitura(_semConexao);
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar o perfil'), findsOneWidget);
    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('TENTAR NOVAMENTE'), findsOneWidget);
    expect(find.text('Perfil ainda não criado'), findsNothing);
  });

  testWidgets('retorno da conexão: o aviso some e a edição volta a funcionar', (tester) async {
    await abrirPerfil(tester, doCache: true);
    expect(_banner, findsOneWidget);

    repositorio.emitir(doCache: false);
    await tester.pumpAndSettle();
    expect(_banner, findsNothing);

    await tentarSalvar(tester, 'Ana Souza');
    expect(repositorio.gravacoes, ['Ana Souza']);
    expect(_nomeExibido(tester), 'Ana Souza');
  });

  testWidgets('conexão perdida durante a edição: falha clara, nome anterior preservado', (tester) async {
    await abrirPerfil(tester, doCache: false);
    await tester.tap(_editar);
    await tester.pumpAndSettle();

    // A conexão cai com o diálogo aberto; a tela ainda não sabe disso
    repositorio.online = false;
    await tester.enterText(_campo, 'Ana Souza');
    await tester.tap(_salvar);
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(_erroDialogo).data, 'Sem conexão com o servidor. O nome não foi alterado.');
    expect(_campo, findsOneWidget, reason: 'o diálogo continua aberto para nova tentativa');
    expect(find.text('Nome de exibição atualizado.'), findsNothing);
    expect(repositorio.perfil.displayName, 'Ana Lima');

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(_nomeExibido(tester), 'Ana Lima');
  });

  testWidgets('sem gravação posterior silenciosa: só uma nova ação do usuário grava', (tester) async {
    await abrirPerfil(tester, doCache: false);
    repositorio.online = false;
    await tentarSalvar(tester, 'Ana Souza');
    expect(repositorio.gravacoes, ['Ana Souza']);

    // A conexão volta: nada é reenviado sozinho
    repositorio.online = true;
    repositorio.emitir(doCache: false);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(repositorio.gravacoes, ['Ana Souza']);
    expect(repositorio.perfil.displayName, 'Ana Lima');
    expect(tester.widget<Text>(_erroDialogo).data, contains('O nome não foi alterado'));

    // Nova ação válida do usuário
    await tester.tap(_salvar);
    await tester.pumpAndSettle();
    expect(repositorio.gravacoes, ['Ana Souza', 'Ana Souza']);
    expect(find.text('Nome de exibição atualizado.'), findsOneWidget);
    expect(_nomeExibido(tester), 'Ana Souza');
  });
}
