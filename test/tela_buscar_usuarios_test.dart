import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:betfriends/data/firestore/user_search_repository.dart';
import 'package:betfriends/models/usuario_publico.dart';
import 'package:betfriends/services/user_search_service.dart';
import 'package:betfriends/tela_amigos/tela_buscar_usuarios.dart';

import 'support/fake_auth.dart';

class _FakeSearchRepository implements UserSearchRepository {
  final List<UsuarioPublico> database;
  bool throwError = false;

  _FakeSearchRepository(this.database);

  @override
  Future<List<UsuarioPublico>> buscarUsuarios(
    String termo, {
    required String usuarioAtualUid,
    int limite = 20,
  }) async {
    if (throwError) {
      throw Exception('Falha de conexão com o servidor');
    }
    final lower = termo.toLowerCase().replaceFirst(RegExp(r'^@'), '');
    return database
        .where((u) =>
            u.displayName.toLowerCase().contains(lower) ||
            u.username.toLowerCase().contains(lower))
        .where((u) => u.userId != usuarioAtualUid)
        .toList();
  }
}

void main() {
  group('TelaBuscarUsuarios - Widget Tests (RF-004, RN-PROF-002, RN-FRD-002)', () {
    const meuUid = 'uid-meu-usuario';
    late FakeAuthService authService;
    late _FakeSearchRepository repository;
    late UserSearchService searchService;

    setUp(() {
      authService = FakeAuthService(usuarioInicial: FakeUser(meuUid));
      repository = _FakeSearchRepository([
        const UsuarioPublico(userId: 'uid-amigo-1', displayName: 'Juliana Paes', username: 'jupaes'),
        const UsuarioPublico(userId: 'uid-amigo-2', displayName: 'Lucas Lima', username: 'lucaslima'),
        // O próprio usuário com o mesmo nome que será pesquisado
        const UsuarioPublico(userId: meuUid, displayName: 'Lucas Meu Nome', username: 'lucas_eu'),
      ]);
      searchService = UserSearchService(authService: authService, repository: repository);
    });

    testWidgets('exibe tela inicial com campo de busca e orientações', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(searchService: searchService),
      ));

      expect(find.text('Buscar Usuários'), findsOneWidget);
      expect(find.byKey(const Key('search_users_input')), findsOneWidget);
      expect(find.text('Encontre amigos no BetFriends'), findsOneWidget);
    });

    testWidgets('busca e exibe usuário existente com nome e @username', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(searchService: searchService),
      ));

      // Digita 'Juliana'
      await tester.enterText(find.byKey(const Key('search_users_input')), 'Juliana');
      // Aguarda o debounce de 300ms
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_users_list')), findsOneWidget);
      expect(find.text('Juliana Paes'), findsOneWidget);
      expect(find.text('@jupaes'), findsOneWidget);
      expect(find.text('Convidar'), findsOneWidget);

      // Não exibe e-mail nem dados privados
      expect(find.textContaining('@example.com'), findsNothing);
      expect(find.textContaining('fichas'), findsNothing);
      expect(find.textContaining('saldo'), findsNothing);
    });

    testWidgets('exclusão do próprio usuário: pesquisar nome compartilhado não lista o usuário logado (RN-FRD-002)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(searchService: searchService),
      ));

      // 'Lucas' existe para o outro usuário e para o próprio usuário logado
      await tester.enterText(find.byKey(const Key('search_users_input')), 'Lucas');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Encontra apenas o outro usuário ('Lucas Lima')
      expect(find.text('Lucas Lima'), findsOneWidget);
      expect(find.text('@lucaslima'), findsOneWidget);

      // O próprio usuário logado ('Lucas Meu Nome') NÃO deve ser exibido
      expect(find.text('Lucas Meu Nome'), findsNothing);
      expect(find.text('@lucas_eu'), findsNothing);
    });

    testWidgets('exibe estado vazio quando busca usuário inexistente', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(searchService: searchService),
      ));

      await tester.enterText(find.byKey(const Key('search_users_input')), 'usuario_inexistente_999');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_users_empty')), findsOneWidget);
      expect(find.text('Nenhum usuário encontrado'), findsOneWidget);
    });

    testWidgets('exibe mensagem amigável e botão tentar novamente em caso de erro', (tester) async {
      repository.throwError = true;

      await tester.pumpWidget(MaterialApp(
        home: TelaBuscarUsuarios(searchService: searchService),
      ));

      await tester.enterText(find.byKey(const Key('search_users_input')), 'qualquer');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_users_error')), findsOneWidget);
      expect(find.byKey(const Key('search_users_retry_button')), findsOneWidget);

      // Desliga erro e clica em tentar novamente
      repository.throwError = false;
      await tester.tap(find.byKey(const Key('search_users_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_users_error')), findsNothing);
    });
  });
}
