import 'package:flutter_test/flutter_test.dart';

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/data/firestore/user_search_repository.dart';
import 'package:betfriends/models/usuario_publico.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:betfriends/services/user_search_service.dart';

import '../support/fake_auth.dart';

class _FakeFunctionsService implements FunctionsService {
  final Map<String, dynamic> responseData;
  final List<(String, Map<String, dynamic>?)> calls = [];
  bool shouldThrow = false;

  _FakeFunctionsService({this.responseData = const {}});

  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
    calls.add((name, data));
    if (shouldThrow) {
      throw FunctionsException(code: 'unavailable', message: 'Servidor indisponível');
    }
    return responseData;
  }

  @override
  Future<PingResult> ping() => throw UnimplementedError();
}

class _InMemorySearchRepository implements UserSearchRepository {
  final List<UsuarioPublico> database;

  _InMemorySearchRepository(this.database);

  @override
  Future<List<UsuarioPublico>> buscarUsuarios(
    String termo, {
    required String usuarioAtualUid,
    int limite = 20,
  }) async {
    final lower = termo.toLowerCase().replaceFirst(RegExp(r'^@'), '');
    return database
        .where((u) =>
            u.displayName.toLowerCase().contains(lower) ||
            u.username.toLowerCase().contains(lower))
        .where((u) => u.userId != usuarioAtualUid)
        .take(limite)
        .toList();
  }
}

void main() {
  group('UserSearchService - Busca de outros usuários (RF-004, RN-PROF-002, RN-FRD-002, RN-AUTH-006)', () {
    const usuarioLogadoUid = 'uid-logado-123';
    late FakeAuthService authService;

    setUp(() {
      authService = FakeAuthService(usuarioInicial: FakeUser(usuarioLogadoUid));
    });

    test('usuário autenticado consegue buscar outros usuários existentes', () async {
      final repo = _InMemorySearchRepository([
        const UsuarioPublico(userId: 'uid-pedro', displayName: 'Pedro Alcantara', username: 'pedro_a'),
        const UsuarioPublico(userId: 'uid-paulo', displayName: 'Paulo Freire', username: 'pfreire'),
        const UsuarioPublico(userId: 'uid-mariana', displayName: 'Mariana Silva', username: 'mari_silva'),
      ]);

      final service = UserSearchService(authService: authService, repository: repo);

      final resultados = await service.buscarUsuarios('pedro');

      expect(resultados.length, 1);
      expect(resultados.first.userId, 'uid-pedro');
      expect(resultados.first.displayName, 'Pedro Alcantara');
      expect(resultados.first.username, 'pedro_a');
      expect(resultados.first.usernameComArroba, '@pedro_a');
    });

    test('buscar usuário inexistente retorna lista vazia', () async {
      final repo = _InMemorySearchRepository([
        const UsuarioPublico(userId: 'uid-pedro', displayName: 'Pedro', username: 'pedro'),
      ]);

      final service = UserSearchService(authService: authService, repository: repo);

      final resultados = await service.buscarUsuarios('ze_ninguem_inexistente');

      expect(resultados, isEmpty);
    });

    test('termo em branco retorna lista vazia sem consultar o repositório', () async {
      final repo = _InMemorySearchRepository([
        const UsuarioPublico(userId: 'uid-pedro', displayName: 'Pedro', username: 'pedro'),
      ]);

      final service = UserSearchService(authService: authService, repository: repo);

      final resultados = await service.buscarUsuarios('   ');

      expect(resultados, isEmpty);
    });

    test('garante exclusão do próprio usuário (RN-FRD-002: auto-amizade proibida)', () async {
      final repo = _InMemorySearchRepository([
        // O próprio usuário logado tem o mesmo username 'pedro'
        const UsuarioPublico(userId: usuarioLogadoUid, displayName: 'Eu Mesmo', username: 'pedro_me'),
        const UsuarioPublico(userId: 'uid-outro-pedro', displayName: 'Pedro Outro', username: 'pedro_outro'),
      ]);

      final service = UserSearchService(authService: authService, repository: repo);

      final resultados = await service.buscarUsuarios('pedro');

      // O próprio usuário logado NÃO é retornado
      expect(resultados.any((u) => u.userId == usuarioLogadoUid), isFalse);
      expect(resultados.length, 1);
      expect(resultados.first.userId, 'uid-outro-pedro');
    });

    test('validar ausência de dados privados nos resultados retornados (RN-PROF-002)', () async {
      final functions = _FakeFunctionsService(responseData: {
        'users': [
          {
            'userId': 'uid-alvo-1',
            'displayName': 'Alvo Amigo',
            'username': 'alvoamigo',
            'email': 'secreto@empresa.com',
            'saldoTotal': 99999,
            'saldoReservado': 5000,
          }
        ]
      });

      final repo = FunctionsUserSearchRepository(functions: functions);
      final service = UserSearchService(authService: authService, repository: repo);

      final resultados = await service.buscarUsuarios('alvo');

      expect(resultados.length, 1);
      final usuarioEncontrado = resultados.first;
      expect(usuarioEncontrado.userId, 'uid-alvo-1');
      expect(usuarioEncontrado.displayName, 'Alvo Amigo');
      expect(usuarioEncontrado.username, 'alvoamigo');

      // O modelo público não contém nem serializa dados privados
      final mapa = usuarioEncontrado.toMap();
      expect(mapa.containsKey('email'), isFalse);
      expect(mapa.containsKey('saldoTotal'), isFalse);
      expect(mapa.containsKey('saldoReservado'), isFalse);
    });

    test('usuário deslogado lança unauthenticated (RN-AUTH-006)', () {
      final authDeslogado = FakeAuthService(usuarioInicial: null);
      final service = UserSearchService(authService: authDeslogado);

      expect(
        () => service.buscarUsuarios('teste'),
        throwsA(isA<UserProfileException>().having(
          (e) => e.code,
          'code',
          UserProfileErrorCode.unauthenticated,
        )),
      );
    });
  });
}
