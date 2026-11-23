import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:betfriends/data/firestore/extrato_repository.dart';
import 'package:betfriends/models/lancamento_do_extrato.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/services/extrato_service.dart';
import 'package:betfriends/tela_extrato/tela_extrato.dart';
import 'package:betfriends/tela_perfil/dados_do_perfil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

class _Repo implements ExtratoRepository {
  final uids = <String>[];
  @override
  Future<PaginaDoExtrato> buscar(String uid, {int limite = 20, CursorDoExtrato? cursor}) async {
    uids.add(uid);
    return pagina([]);
  }
}

class _Service extends Fake implements ExtratoService {
  final Future<PaginaDoExtrato> Function(int chamada) resposta;
  int chamadas = 0;
  _Service(this.resposta);
  @override
  Future<PaginaDoExtrato> buscarDoUsuarioAtual({int limite = 20, CursorDoExtrato? cursor}) => resposta(chamadas++);
}

PaginaDoExtrato pagina(List<LancamentoDoExtrato> itens, {bool mais = false, bool cache = false}) =>
  PaginaDoExtrato(itens: itens, ignorados: 0, doCache: cache, temMais: mais, proximoCursor: null);

LancamentoDoExtrato item(String id, {String tipo = 'WIN'}) => LancamentoDoExtrato.fromMap(id, {
  'userId': 'ana', 'type': tipo, 'amount': 20,
  'balanceAfter': {'saldoTotal': 1000, 'saldoReservado': 0},
  'challengeId': 'id-interno-nao-exibir',
  'createdAt': Timestamp.fromDate(DateTime(2026, 11, 23, 14, 30)),
});

void main() {
  test('todos os tipos do backend têm rótulo e sinal financeiro correto', () {
    final esperados = {
      'INITIAL_BALANCE': ('Saldo inicial', '+20 BC'),
      'RESERVE': ('Reserva para desafio', '20 BC'),
      'RELEASE': ('Liberação de reserva', '20 BC'),
      'WIN': ('Prêmio por vitória', '+20 BC'),
      'LOSS': ('Perda no desafio', '−20 BC'),
      'REFUND': ('Reembolso por empate', '20 BC'),
      'RECOVERY_BONUS': ('Bônus de recuperação', '+20 BC'),
      'DEV_TOP_UP': ('Reposição de desenvolvimento', '+20 BC'),
    };
    final backend = File('functions/src/betcoins/transacoes.ts').readAsStringSync();
    final bloco = backend.split('export const TIPOS_DE_TRANSACAO = [')[1].split('] as const')[0];
    final tiposBackend = RegExp(r'"([A-Z_]+)"').allMatches(bloco).map((m) => m[1]).toSet();
    expect(esperados.keys.toSet(), tiposBackend);
    expect(TipoDoLancamento.values.length, esperados.length);
    for (final caso in esperados.entries) {
      final lancamento = item('id', tipo: caso.key);
      expect(lancamento.tipo.rotulo, caso.value.$1);
      expect(lancamento.valorFormatado, caso.value.$2);
      if (lancamento.tipo.sinal == 0) expect(lancamento.tipo.explicacao, contains('total não alterado'));
    }
  });

  test('índice publicado no arquivo corresponde à consulta e à tabela', () {
    final indexes = (jsonDecode(File('firestore.indexes.json').readAsStringSync()) as Map)['indexes'] as List;
    final indice = indexes.singleWhere((i) => i['collectionGroup'] == 'betCoinTransactions');
    expect(indice['fields'], [
      {'fieldPath': 'userId', 'order': 'ASCENDING'},
      {'fieldPath': 'createdAt', 'order': 'DESCENDING'},
    ]);
    final doc = File('docs/firestore-schema.md').readAsStringSync().split('## 6 - Índices declarados')[1].split('## 7')[0];
    expect(doc.split('\n').where((l) => l.startsWith('| `')).length, indexes.length);
    expect(doc, contains('`userId ASC`, `createdAt DESC`'));
  });

  test('sessão define o dono; sem sessão não consulta', () async {
    final repo = _Repo();
    final auth = FakeAuthService(usuarioInicial: FakeUser('ana'));
    final service = ExtratoService(authService: auth, repository: repo);
    await service.buscarDoUsuarioAtual();
    expect(repo.uids, ['ana']);
    auth.encerrarSessaoExternamente();
    expect(() => service.buscarDoUsuarioAtual(), throwsA(isA<ExtratoException>()));
    expect(repo.uids, ['ana']);
  });

  testWidgets('carregamento e vazio confirmado', (tester) async {
    final resposta = Completer<PaginaDoExtrato>();
    await tester.pumpWidget(MaterialApp(home: TelaExtrato(extratoService: _Service((_) => resposta.future))));
    expect(find.byKey(const Key('extrato_carregando')), findsOneWidget);
    expect(find.byKey(const Key('extrato_vazio')), findsNothing);
    resposta.complete(pagina([]));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum lançamento ainda.'), findsOneWidget);
  });

  testWidgets('pagina sem duplicar e preserva itens ao falhar página seguinte', (tester) async {
    final service = _Service((n) async {
      if (n == 0) return pagina([item('a')], mais: true);
      if (n == 1) throw const ExtratoException(ExtratoErrorCode.unavailable, 'Sem conexão.');
      return pagina([item('a'), item('b', tipo: 'RESERVE')]);
    });
    await tester.pumpWidget(MaterialApp(home: TelaExtrato(extratoService: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('extrato_item_a')), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('extrato_item_a')), findsOneWidget);
    expect(find.byKey(const Key('extrato_item_b')), findsOneWidget);
    expect(find.text('Desafio 1'), findsNWidgets(2));
    expect(find.textContaining('id-interno'), findsNothing);
    expect(find.text('Fim do extrato.'), findsOneWidget);
    expect(find.textContaining('Reservado;'), findsOneWidget);
  });

  testWidgets('índice ausente mostra orientação e nova tentativa recupera', (tester) async {
    final erro = ExtratoException.fromFirebase(FirebaseException(plugin: 'cloud_firestore', code: 'failed-precondition'));
    expect(erro.code, ExtratoErrorCode.indiceAusente);
    final service = _Service((n) async { if (n == 0) throw erro; return pagina([]); });
    await tester.pumpWidget(MaterialApp(home: TelaExtrato(extratoService: service)));
    await tester.pumpAndSettle();
    expect(find.textContaining('índice ainda não publicado'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('extrato_vazio')), findsOneWidget);
  });

  testWidgets('cache vazio não afirma ausência de lançamentos', (tester) async {
    await tester.pumpWidget(MaterialApp(home: TelaExtrato(extratoService: _Service((_) async => pagina([], cache: true)))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('extrato_vazio')), findsNothing);
    expect(find.textContaining('pode estar incompleto'), findsOneWidget);
  });

  testWidgets('entrada do Perfil injeta serviço e abre extrato próprio', (tester) async {
    final service = _Service((_) async => pagina([]));
    await tester.pumpWidget(Provider<ExtratoService>.value(value: service,
      child: const MaterialApp(home: Scaffold(body: DadosDoPerfil(
        perfil: UserProfile(uid: 'ana', displayName: 'Ana', username: 'ana', usernameNormalized: 'ana', email: 'privado@example.com'),
        semConexao: false,
      ))),
    ));
    await tester.ensureVisible(find.byKey(const Key('perfil_extrato')));
    await tester.tap(find.byKey(const Key('perfil_extrato')));
    await tester.pumpAndSettle();
    expect(find.byType(TelaExtrato), findsOneWidget);
    expect(find.byKey(const Key('extrato_vazio')), findsOneWidget);
    expect(service.chamadas, 1);
  });
}
