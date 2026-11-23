import 'package:betfriends/data/firestore/friendship_repository.dart';
import 'package:betfriends/models/friendship_model.dart';
import 'package:betfriends/services/friendship_service.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth.dart';

class _Functions implements FunctionsService {
  int chamadas = 0;
  String? nome;
  Map<String, dynamic>? payload;
  Map<String, dynamic> resposta = {
    'friendshipId': 'a_uid_z_uid',
    'status': 'REMOVED',
  };
  FunctionsException? erro;

  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
    chamadas++;
    nome = name;
    payload = data;
    if (erro != null) throw erro!;
    return resposta;
  }

  @override
  Future<PingResult> ping() => throw UnimplementedError();
}

void main() {
  late _Functions functions;
  late FriendshipService service;

  setUp(() {
    functions = _Functions();
    service = FriendshipService(
      authService: FakeAuthService(usuarioInicial: FakeUser('z_uid')),
      functionsService: functions,
    );
  });

  test('envia somente friendshipId ordenado e aceita replay REMOVED', () async {
    await service.removerAmizade('a_uid');
    expect(FriendshipStatus.fromString('REMOVED'), FriendshipStatus.removed);
    expect(FriendshipStatus.removed.valor, 'REMOVED');
    await service.removerAmizade('a_uid');
    expect(functions.nome, CallableNames.removeFriend);
    expect(functions.payload, {'friendshipId': 'a_uid_z_uid'});
    expect(functions.chamadas, 2);
  });

  test('não confirma resposta sem status REMOVED', () async {
    functions.resposta = {'friendshipId': 'a_uid_z_uid', 'status': 'ACCEPTED'};
    await expectLater(service.removerAmizade('a_uid'),
        throwsA(isA<FriendshipException>()));
  });

  for (final motivo in ['solicitacao-inexistente', 'desafio-ativo']) {
    test('traduz erro remoto $motivo', () async {
      functions.erro = FunctionsException(
        code: motivo == 'desafio-ativo' ? 'failed-precondition' : 'not-found',
        message: 'Backend',
        motivo: motivo,
      );
      await expectLater(service.removerAmizade('a_uid'),
          throwsA(isA<FriendshipException>().having(
            (e) => e.code,
            'code',
            motivo == 'desafio-ativo'
                ? FriendshipErrorCode.activeChallenge
                : FriendshipErrorCode.requestNotFound,
          )));
      expect(functions.chamadas, 1);
    });
  }

  test('offline não retorna sucesso e não agenda reenvio', () async {
    functions.erro = FunctionsException(code: 'unavailable', message: 'offline');
    await expectLater(service.removerAmizade('a_uid'),
        throwsA(isA<FriendshipException>().having(
          (e) => e.code, 'code', FriendshipErrorCode.unavailable,
        )));
    functions.erro = null;
    await Future<void>.delayed(Duration.zero);
    expect(functions.chamadas, 1);
  });
}
