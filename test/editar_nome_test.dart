import 'dart:async';

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

/// Repositório em memória: grava o nome e emite o perfil atualizado pelo
/// stream, como o Firestore. [gravacao] permite segurar a gravação em curso.
class _RepositorioEditavel implements UserProfileRepository {
  _RepositorioEditavel(this._perfil);

  UserProfile _perfil;
  final _stream = StreamController<UserProfile?>.broadcast();
  final gravacoes = <({String uid, String nome})>[];
  Completer<void>? gravacao;
  UserProfileException? erro;

  UserProfile get perfil => _perfil;

  @override
  Stream<PerfilObservado> observarPorUid(String uid) async* {
    yield PerfilObservado(_perfil);
    yield* _stream.stream.map(PerfilObservado.new);
  }

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {
    gravacoes.add((uid: uid, nome: displayName));
    if (gravacao != null) await gravacao!.future;
    if (erro != null) throw erro!;
    _perfil = UserProfile(
      uid: _perfil.uid,
      displayName: displayName,
      username: _perfil.username,
      usernameNormalized: _perfil.usernameNormalized,
      email: _perfil.email,
    );
    _stream.add(_perfil);
  }

  @override
  Future<UserProfile?> buscarPorUid(String uid) => throw UnimplementedError();

  @override
  Future<void> criar(UserProfile perfil) => throw UnimplementedError();
}

const _ana = UserProfile(
  uid: 'uid-ana',
  displayName: 'Ana Lima',
  username: 'AnaL',
  usernameNormalized: 'anal',
  email: 'ana@example.com',
);

void main() {
  late _RepositorioEditavel repositorio;
  late FakeAuthService auth;

  setUp(() {
    repositorio = _RepositorioEditavel(_ana);
    auth = FakeAuthService(usuarioInicial: FakeUser('uid-ana'));
  });

  String nomeNaTela(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('perfil_display_name'))).data!;

  Future<void> abrirEdicao(WidgetTester tester) async {
    await tester.pumpWidget(
      Provider<UserProfileService>.value(
        value: UserProfileService(authService: auth, repository: repositorio),
        child: const MaterialApp(home: PerfilScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('perfil_editar_nome')));
    await tester.pumpAndSettle();
  }

  Future<void> digitarESalvar(WidgetTester tester, String nome) async {
    await tester.enterText(find.byKey(const Key('editar_nome_campo')), nome);
    await tester.tap(find.byKey(const Key('editar_nome_salvar')));
    await tester.pump();
  }

  testWidgets('formulário abre com o nome atual', (tester) async {
    await abrirEdicao(tester);

    expect(find.text('Editar nome de exibição'), findsOneWidget);
    final campo = tester.widget<TextFormField>(find.byKey(const Key('editar_nome_campo')));
    expect(campo.controller!.text, 'Ana Lima');
  });

  testWidgets('edição válida grava, fecha, confirma e atualiza a tela', (tester) async {
    await abrirEdicao(tester);
    await digitarESalvar(tester, 'Ana Souza');
    await tester.pumpAndSettle();

    expect(repositorio.gravacoes, [(uid: 'uid-ana', nome: 'Ana Souza')]);
    expect(find.text('Editar nome de exibição'), findsNothing);
    expect(find.text('Nome de exibição atualizado.'), findsOneWidget);
    expect(nomeNaTela(tester), 'Ana Souza');
  });

  testWidgets('remove espaços das extremidades antes de salvar', (tester) async {
    await abrirEdicao(tester);
    await digitarESalvar(tester, '   Ana Souza  ');
    await tester.pumpAndSettle();

    expect(repositorio.gravacoes.single.nome, 'Ana Souza');
    expect(nomeNaTela(tester), 'Ana Souza');
  });

  for (final (caso, valor, mensagem) in [
    ('vazio', '', 'Informe um nome de exibição.'),
    ('só com espaços', '    ', 'Informe um nome de exibição.'),
    ('com 61 caracteres', 'a' * 61, 'Use no máximo 60 caracteres.'),
  ]) {
    testWidgets('nome $caso mostra erro de validação e não grava', (tester) async {
      await abrirEdicao(tester);
      await digitarESalvar(tester, valor);

      expect(find.text(mensagem), findsOneWidget);
      expect(repositorio.gravacoes, isEmpty);
      expect(find.text('Editar nome de exibição'), findsOneWidget);
    });
  }

  testWidgets('aceita exatamente 60 caracteres', (tester) async {
    await abrirEdicao(tester);
    await digitarESalvar(tester, 'a' * 60);
    await tester.pumpAndSettle();

    expect(repositorio.gravacoes.single.nome, hasLength(60));
  });

  testWidgets('nome igual ao atual fecha sem gravar nem confirmar', (tester) async {
    await abrirEdicao(tester);
    await digitarESalvar(tester, ' Ana Lima ');
    await tester.pumpAndSettle();

    expect(repositorio.gravacoes, isEmpty);
    expect(find.text('Nome de exibição atualizado.'), findsNothing);
  });

  testWidgets('cancelar fecha sem alterar nada', (tester) async {
    await abrirEdicao(tester);
    await tester.enterText(find.byKey(const Key('editar_nome_campo')), 'Outro Nome');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repositorio.gravacoes, isEmpty);
    expect(nomeNaTela(tester), 'Ana Lima');
    expect(find.text('Nome de exibição atualizado.'), findsNothing);
  });

  testWidgets('durante a gravação mostra indicador e bloqueia novas tentativas e o cancelamento',
      (tester) async {
    repositorio.gravacao = Completer<void>();
    await abrirEdicao(tester);
    await digitarESalvar(tester, 'Ana Souza');

    final salvar = find.byKey(const Key('editar_nome_salvar'));
    expect(find.descendant(of: salvar, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(tester.widget<ElevatedButton>(salvar).onPressed, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar')).onPressed, isNull);

    // Toques repetidos e Enter no campo não disparam outra gravação
    await tester.tap(salvar, warnIfMissed: false);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // Voltar do sistema também não fecha o diálogo
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(repositorio.gravacoes, hasLength(1));
    expect(find.text('Editar nome de exibição'), findsOneWidget);
    expect(find.text('Nome de exibição atualizado.'), findsNothing);

    repositorio.gravacao!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nome de exibição atualizado.'), findsOneWidget);
    expect(nomeNaTela(tester), 'Ana Souza');
  });

  for (final (caso, codigo, mensagem) in [
    ('falha de conexão', UserProfileErrorCode.unavailable, 'Sem conexão com o servidor. O nome não foi alterado.'),
    ('permissão negada', UserProfileErrorCode.permissionDenied, 'Você não tem permissão para alterar este perfil.'),
  ]) {
    testWidgets('$caso mantém o diálogo aberto com o erro e permite tentar de novo', (tester) async {
      repositorio.erro = UserProfileException(codigo, 'erro de teste');
      await abrirEdicao(tester);
      await digitarESalvar(tester, 'Ana Souza');
      await tester.pumpAndSettle();

      expect(find.text(mensagem), findsOneWidget);
      expect(find.text('Nome de exibição atualizado.'), findsNothing);
      expect(nomeNaTela(tester), 'Ana Lima');

      repositorio.erro = null;
      await tester.tap(find.byKey(const Key('editar_nome_salvar')));
      await tester.pumpAndSettle();
      expect(find.text('Nome de exibição atualizado.'), findsOneWidget);
      expect(repositorio.gravacoes, hasLength(2));
    });
  }

  testWidgets('sessão expirada informa o erro sem gravar', (tester) async {
    await abrirEdicao(tester);
    auth.encerrarSessaoExternamente();
    await digitarESalvar(tester, 'Ana Souza');
    await tester.pumpAndSettle();

    expect(find.text('Sua sessão expirou. Entre novamente para alterar o nome.'), findsOneWidget);
    expect(repositorio.gravacoes, isEmpty);
  });

  testWidgets('UID, username e e-mail permanecem iguais após salvar', (tester) async {
    await abrirEdicao(tester);
    await digitarESalvar(tester, 'Ana Souza');
    await tester.pumpAndSettle();

    expect(repositorio.gravacoes.single.uid, 'uid-ana');
    expect(repositorio.perfil.uid, 'uid-ana');
    expect(repositorio.perfil.username, 'AnaL');
    expect(repositorio.perfil.email, 'ana@example.com');
    expect(find.text('@AnaL'), findsOneWidget);
  });
}
