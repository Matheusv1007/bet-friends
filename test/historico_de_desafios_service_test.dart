import 'package:betfriends/data/firestore/historico_de_desafios_repository.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/historico_de_desafios_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _Usuario extends Fake implements User {
  @override
  final String uid;
  _Usuario(this.uid);
}

class _Auth extends Fake implements AuthService {
  @override
  final User? currentUser;
  _Auth(this.currentUser);
}

class _Repositorio implements HistoricoDeDesafiosRepository {
  final uids = <String>[];
  final limites = <int>[];

  @override
  Future<PaginaDoHistorico> buscar(String uid, {int limite = 20, CursorDoHistorico? cursor}) async {
    uids.add(uid);
    limites.add(limite);
    return const PaginaDoHistorico(itens: [], ignorados: 0, doCache: false, temMais: false, proximoCursor: null);
  }
}

void main() {
  test('consulta sempre com o UID da sessão', () async {
    final repo = _Repositorio();
    final service = HistoricoDeDesafiosService(authService: _Auth(_Usuario('uidSessao')), repository: repo);
    final pagina = await service.buscarDoUsuarioAtual(limite: 5);
    expect(repo.uids, ['uidSessao']);
    expect(repo.limites, [5]);
    expect(pagina.itens, isEmpty);
    expect(pagina.temMais, isFalse);
  });

  test('sem sessão: unauthenticated, sem consultar', () {
    final repo = _Repositorio();
    final service = HistoricoDeDesafiosService(authService: _Auth(null), repository: repo);
    expect(
      () => service.buscarDoUsuarioAtual(),
      throwsA(isA<HistoricoException>().having((e) => e.code, 'code', HistoricoErrorCode.unauthenticated)),
    );
    expect(repo.uids, isEmpty);
  });

  test('erros do Firestore viram códigos do histórico', () {
    final casos = {
      'permission-denied': HistoricoErrorCode.permissionDenied,
      'unauthenticated': HistoricoErrorCode.unauthenticated,
      'unavailable': HistoricoErrorCode.unavailable,
      'deadline-exceeded': HistoricoErrorCode.unavailable,
      'failed-precondition': HistoricoErrorCode.indiceAusente,
      'outro': HistoricoErrorCode.unknown,
    };
    casos.forEach((codigo, esperado) {
      final e = HistoricoException.fromFirebase(FirebaseException(plugin: 'cloud_firestore', code: codigo, message: 'detalhe interno'));
      expect(e.code, esperado, reason: codigo);
      expect(e.message, isNot(contains('detalhe interno')));
    });
  });
}
