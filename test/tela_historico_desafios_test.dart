import 'dart:async';

import 'package:betfriends/data/firestore/historico_de_desafios_repository.dart';
import 'package:betfriends/data/firestore/partidas_repository.dart';
import 'package:betfriends/models/desafio_encerrado.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/services/historico_de_desafios_service.dart';
import 'package:betfriends/tema/tema.dart';
import 'package:betfriends/tela_historico/tela_historico_desafios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

class _Cursor extends Fake implements CursorDoHistorico {}

class _Repositorio implements HistoricoDeDesafiosRepository {
  final respostas = <Future<PaginaDoHistorico> Function()>[];
  final cursores = <CursorDoHistorico?>[];

  @override
  Future<PaginaDoHistorico> buscar(String uid, {
    int limite = 20, CursorDoHistorico? cursor,
  }) {
    cursores.add(cursor);
    return respostas.removeAt(0)();
  }
}

class _Partidas extends Fake implements FirestorePartidasRepository {
  final consultadas = <String>[];
  int? golsMandante;
  int? golsVisitante;

  @override
  Future<PartidaModel?> buscarPorId(String id) async {
    consultadas.add(id);
    return PartidaModel(
      id: id, timeMandante: 'Flamengo', timeVisitante: 'Bahia',
      golsMandante: golsMandante, golsVisitante: golsVisitante,
      competitionCode: 'BSA',
    );
  }
}

DesafioEncerrado _desafio(String id, {String? vencedor = 'eu', int dia = 20}) =>
    DesafioEncerrado(
      id: id, challengerId: 'eu', challengedId: 'amigo', matchId: 'partida',
      challengerPrediction: 'HOME_WIN', challengedPrediction: 'AWAY_WIN',
      amount: 50, status: StatusEncerrado.finished, winnerId: vencedor,
      settledResult: 'HOME_WIN', cancelReason: null,
      createdAt: DateTime(2026, 11, 1), acceptedAt: null, startedAt: null,
      finishedAt: DateTime(2026, 11, dia),
    );

PaginaDoHistorico _pagina(List<DesafioEncerrado> itens, {
  CursorDoHistorico? cursor, bool doCache = false,
}) => PaginaDoHistorico(
  itens: itens, ignorados: 0, doCache: doCache,
  temMais: cursor != null, proximoCursor: cursor,
);

void main() {
  late _Repositorio repo;
  late _Partidas partidas;

  setUp(() {
    repo = _Repositorio();
    partidas = _Partidas();
  });

  Future<void> abrir(WidgetTester tester) => tester.pumpWidget(MaterialApp(
    home: TelaHistoricoDesafios(
      currentUserId: 'eu', nomes: const {'amigo': 'João'},
      partidasRepository: partidas,
      historicoService: HistoricoDeDesafiosService(
        authService: FakeAuthService(usuarioInicial: FakeUser('eu')),
        repository: repo,
      ),
    ),
  ));

  testWidgets('primeira página mostra carregamento, partida, adversário e detalhe oficial', (tester) async {
    final pendente = Completer<PaginaDoHistorico>();
    repo.respostas.add(() => pendente.future);
    await abrir(tester);
    expect(find.byKey(const Key('historico_carregando')), findsOneWidget);
    pendente.complete(_pagina([_desafio('recente')]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Flamengo x Bahia'), findsOneWidget);
    expect(find.textContaining('João'), findsOneWidget);
    expect(find.text('Você venceu'), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);
    expect(find.text('Fim do histórico'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_detalhes_desafio_finalizado_recente')));
    await tester.pumpAndSettle();
    expect(find.text('Resultado oficial: Vitória Mandante'), findsOneWidget);
    expect(find.text('BetCoins: +50 BetCoins'), findsOneWidget);
    expect(find.text('Vencedor: Você'), findsOneWidget);
  });

  testWidgets('Carregar mais usa cursor, anexa em ordem e não duplica desafios', (tester) async {
    final cursor = _Cursor();
    final pendente = Completer<PaginaDoHistorico>();
    repo.respostas.addAll([
      () async => _pagina([_desafio('recente')], cursor: cursor),
      () => pendente.future,
    ]);
    await abrir(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais'));
    await tester.pump();
    expect(find.byKey(const Key('card_desafio_finalizado_recente')), findsOneWidget);
    expect(find.text('Carregar mais'), findsNothing);
    pendente.complete(_pagina([
      _desafio('recente'), _desafio('antigo', vencedor: 'amigo', dia: 19),
    ]));
    await tester.pumpAndSettle();
    expect(repo.cursores, [null, same(cursor)]);
    expect(find.byKey(const Key('card_desafio_finalizado_recente')), findsOneWidget);
    expect(find.byKey(const Key('card_desafio_finalizado_antigo')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('card_desafio_finalizado_recente'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('card_desafio_finalizado_antigo'))).dy));
    expect(find.text('−50'), findsOneWidget);
    expect(find.text('Carregar mais'), findsNothing);
    expect(find.text('Fim do histórico'), findsOneWidget);
    expect(partidas.consultadas, ['partida']);
  });

  testWidgets('histórico vazio não oferece paginação', (tester) async {
    repo.respostas.add(() async => _pagina([]));
    await abrir(tester);
    await tester.pumpAndSettle();
    expect(find.text('Você ainda não tem desafios encerrados'), findsOneWidget);
    expect(find.text('Carregar mais'), findsNothing);
    expect(find.text('Fim do histórico'), findsNothing);
  });

  testWidgets('índice ausente tem mensagem clara e nova tentativa recupera', (tester) async {
    repo.respostas.addAll([
      () async => throw const HistoricoException(
        HistoricoErrorCode.indiceAusente, 'Ambiente indisponível.'),
      () async => _pagina([_desafio('recuperado')]),
    ]);
    await abrir(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('configurar o índice de consulta'), findsOneWidget);
    expect(find.text('Você ainda não tem desafios encerrados'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('historico_erro')), findsNothing);
    expect(find.byKey(const Key('card_desafio_finalizado_recuperado')), findsOneWidget);
    expect(repo.cursores, [null, null]);
  });

  testWidgets('erro na próxima página preserva itens e repete o mesmo cursor', (tester) async {
    final cursor = _Cursor();
    repo.respostas.addAll([
      () async => _pagina([_desafio('recente')], cursor: cursor),
      () async => throw const HistoricoException(
        HistoricoErrorCode.unavailable, 'Verifique sua conexão.'),
      () async => _pagina([_desafio('antigo', dia: 19)]),
    ]);
    await abrir(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    expect(find.text('Verifique sua conexão.'), findsOneWidget);
    expect(find.byKey(const Key('card_desafio_finalizado_recente')), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(repo.cursores, [null, same(cursor), same(cursor)]);
    expect(find.byKey(const Key('card_desafio_finalizado_antigo')), findsOneWidget);
  });

  testWidgets('cache vazio não é apresentado como histórico vazio confirmado', (tester) async {
    repo.respostas.add(() async => _pagina([], doCache: true));
    await abrir(tester);
    await tester.pumpAndSettle();
    expect(find.text('Você ainda não tem desafios encerrados'), findsNothing);
    expect(find.textContaining('Verifique sua conexão'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  DesafioEncerrado desfecho(String id, StatusEncerrado status, {String? vencedor, String? motivo}) =>
      DesafioEncerrado(
        id: id, challengerId: 'eu', challengedId: 'amigo', matchId: 'partida',
        challengerPrediction: 'HOME_WIN', challengedPrediction: 'AWAY_WIN',
        amount: 50, status: status, winnerId: vencedor,
        settledResult: null, cancelReason: motivo,
        createdAt: DateTime(2026, 11, 1), acceptedAt: null, startedAt: null,
        finishedAt: DateTime(2026, 11, 20),
      );

  testWidgets('cada desfecho mostra resultado e valor à direita, com a cor do desfecho', (tester) async {
    repo.respostas.add(() async => _pagina([
      desfecho('venceu', StatusEncerrado.finished, vencedor: 'eu'),
      desfecho('perdeu', StatusEncerrado.finished, vencedor: 'amigo'),
      desfecho('ninguem', StatusEncerrado.finished),
      desfecho('adiada', StatusEncerrado.cancelled, motivo: 'MATCH_POSTPONED'),
      desfecho('recusado', StatusEncerrado.rejected),
      desfecho('expirado', StatusEncerrado.expired),
    ]));
    await abrir(tester);
    await tester.pumpAndSettle();

    final esperado = {
      'venceu': ('Você venceu', '+50', CoresApp.primario),
      'perdeu': ('Você perdeu', '−50', CoresApp.destrutivo),
      'ninguem': ('Ninguém acertou', '0', CoresApp.textoSuave),
      'adiada': ('Partida adiada', '0', CoresApp.textoSuave),
      'recusado': ('Recusado', '0', CoresApp.textoSuave),
      'expirado': ('Expirado', '0', CoresApp.textoSuave),
    };
    for (final e in esperado.entries) {
      final linha = find.byKey(Key('card_desafio_finalizado_${e.key}'));
      final rotulo = find.descendant(of: linha, matching: find.text(e.value.$1));
      final valor = find.descendant(of: linha, matching: find.text(e.value.$2));
      expect(rotulo, findsOneWidget, reason: e.key);
      expect(valor, findsOneWidget, reason: e.key);
      expect(tester.widget<Text>(rotulo).style!.color, e.value.$3, reason: e.key);
      // O resultado fica à direita do título da linha
      expect(tester.getTopLeft(rotulo).dx, greaterThan(tester.getTopLeft(find.descendant(of: linha, matching: find.text('Você x João'))).dx));
      expect(tester.getTopLeft(valor).dx, greaterThan(tester.getSize(linha).width / 2), reason: e.key);
    }
    expect(find.text('FINALIZADOS', findRichText: false), findsNothing);
    expect(find.textContaining('FINALIZADOS', findRichText: true), findsOneWidget);
  });

  testWidgets('partida com placar mostra "Flamengo 2 x 1 Bahia", liga, data e aposta', (tester) async {
    partidas..golsMandante = 2..golsVisitante = 1;
    repo.respostas.add(() async => _pagina([_desafio('recente')]));
    await abrir(tester);
    await tester.pumpAndSettle();

    expect(find.text('Flamengo 2 x 1 Bahia'), findsOneWidget);
    expect(find.text('Brasileirão Série A · 20/11 · aposta 50'), findsOneWidget);
    expect(find.text('Você x João'), findsOneWidget);
  });
}
