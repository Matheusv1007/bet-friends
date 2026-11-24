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

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/carteira.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/tema/tema.dart';
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

/// Repositório de perfil que emite um único [PerfilObservado] (ou falha).
class _RepoDePerfil implements UserProfileRepository {
  final PerfilObservado? emissao;
  final bool falhar;
  _RepoDePerfil(this.emissao, {this.falhar = false});

  @override
  Stream<PerfilObservado> observarPorUid(String uid) =>
      falhar ? Stream.error(StateError('sem conexão')) : Stream.value(emissao!);

  @override
  Future<UserProfile?> buscarPorUid(String uid) async => null;

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {}
}

void main() {
  test('todos os tipos do backend têm rótulo e sinal financeiro correto', () {
    final esperados = {
      'INITIAL_BALANCE': ('Saldo inicial', '+20', 1),
      'RESERVE': ('Reserva para desafio', '20', 0),
      'RELEASE': ('Liberação de reserva', '20', 0),
      'WIN': ('Prêmio por vitória', '+20', 1),
      'LOSS': ('Perda no desafio', '−20', -1),
      'REFUND': ('Reembolso por empate', '20', 0),
      'RECOVERY_BONUS': ('Bônus de recuperação', '+20', 1),
      'DEV_TOP_UP': ('Reposição de desenvolvimento', '+20', 1),
    };
    final backend = File('functions/src/betcoins/transacoes.ts').readAsStringSync();
    final bloco = backend.split('export const TIPOS_DE_TRANSACAO = [')[1].split('] as const')[0];
    final tiposBackend = RegExp(r'"([A-Z_]+)"').allMatches(bloco).map((m) => m[1]).toSet();
    expect(esperados.keys.toSet(), tiposBackend);
    expect(TipoDoLancamento.values.length, esperados.length);
    for (final caso in esperados.entries) {
      final lancamento = item('id', tipo: caso.key);
      expect(lancamento.tipo.rotulo, caso.value.$1);
      expect(valorDoLancamento(lancamento), caso.value.$2);
      expect(lancamento.tipo.sinal, caso.value.$3);
      expect(glifoDoLancamento(lancamento.tipo), isA<IconData>());
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
    expect(find.textContaining('Desafio 1'), findsNWidgets(2));
    expect(find.textContaining('id-interno'), findsNothing);
    expect(find.text('Fim do extrato.'), findsOneWidget);
    expect(find.text('Reserva e reembolso não alteram o total.'), findsOneWidget);
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

  group('Layout Evolução', () {
    final todos = [
      for (final tipo in ['INITIAL_BALANCE', 'RESERVE', 'RELEASE', 'WIN', 'LOSS', 'REFUND', 'RECOVERY_BONUS', 'DEV_TOP_UP'])
        item(tipo.toLowerCase(), tipo: tipo),
    ];

    test('cada tipo tem glifo próprio por categoria e cor por sinal', () {
      expect(glifoDoLancamento(TipoDoLancamento.reserva), Icons.lock_outline);
      expect(glifoDoLancamento(TipoDoLancamento.premio), Icons.arrow_upward);
      expect(glifoDoLancamento(TipoDoLancamento.perda), Icons.arrow_downward);
      expect(glifoDoLancamento(TipoDoLancamento.reembolso), Icons.undo);
      expect(glifoDoLancamento(TipoDoLancamento.liberacao), Icons.undo);
      expect(glifoDoLancamento(TipoDoLancamento.saldoInicial), Icons.account_balance_wallet_outlined);
      expect(corDoLancamento(TipoDoLancamento.premio), CoresApp.primario);
      expect(corDoLancamento(TipoDoLancamento.perda), CoresApp.destrutivo);
      expect(corDoLancamento(TipoDoLancamento.reserva), CoresApp.textoSuave);
    });

    testWidgets('mostra glifo, valor com sinal e cor, e o total depois de cada lançamento', (tester) async {
      await tester.pumpWidget(MaterialApp(home: TelaExtrato(extratoService: _Service((_) async => pagina(todos)))));
      await tester.pumpAndSettle();

      Color cor(String id) => tester.widget<Text>(find.byKey(Key('extrato_valor_$id'))).style!.color!;
      expect(tester.widget<Text>(find.byKey(const Key('extrato_valor_win'))).data, '+20');
      expect(cor('win'), CoresApp.primario);
      expect(tester.widget<Text>(find.byKey(const Key('extrato_valor_loss'))).data, '−20');
      expect(cor('loss'), CoresApp.destrutivo);
      expect(tester.widget<Text>(find.byKey(const Key('extrato_valor_reserve'))).data, '20');
      expect(cor('reserve'), isNot(CoresApp.primario));
      expect(cor('reserve'), isNot(CoresApp.destrutivo));
      expect(find.text('total 1.000'), findsNWidgets(todos.length));
      expect(find.textContaining(' BC'), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsNWidgets(2));
      expect(find.byIcon(Icons.card_giftcard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
      expect(find.textContaining('LANÇAMENTOS', findRichText: true), findsOneWidget);
    });

    testWidgets('resumo mostra Disponível, Reservado e Total da carteira', (tester) async {
      final repo = _RepoDePerfil(PerfilObservado(null, carteira: Carteira(saldoTotal: 1000, saldoReservado: 100)));
      final perfis = UserProfileService(
        authService: FakeAuthService(usuarioInicial: FakeUser('ana')),
        repository: repo,
      );
      await tester.pumpWidget(MaterialApp(
        home: TelaExtrato(extratoService: _Service((_) async => pagina([])), perfilService: perfis),
      ));
      await tester.pumpAndSettle();

      final resumo = find.byKey(const Key('extrato_resumo'));
      expect(find.descendant(of: resumo, matching: find.text('Disponível')), findsOneWidget);
      expect(find.descendant(of: resumo, matching: find.text('900')), findsOneWidget);
      expect(find.descendant(of: resumo, matching: find.text('Reservado')), findsOneWidget);
      expect(find.descendant(of: resumo, matching: find.text('100')), findsOneWidget);
      expect(find.descendant(of: resumo, matching: find.text('Total')), findsOneWidget);
      expect(find.descendant(of: resumo, matching: find.text('1.000')), findsOneWidget);
    });

    testWidgets('falha na leitura da carteira omite o resumo, sem erro', (tester) async {
      final repo = _RepoDePerfil(null, falhar: true);
      final perfis = UserProfileService(
        authService: FakeAuthService(usuarioInicial: FakeUser('ana')),
        repository: repo,
      );
      await tester.pumpWidget(MaterialApp(
        home: TelaExtrato(extratoService: _Service((_) async => pagina([item('a')])), perfilService: perfis),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('extrato_resumo')), findsNothing);
      expect(find.byKey(const Key('extrato_item_a')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
