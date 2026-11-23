import 'dart:async';

import 'package:betfriends/models/carteira.dart';
import 'package:betfriends/services/bonus_recuperacao_service.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:betfriends/widgets_home_page/bonus_recuperacao.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Functions extends Fake implements FunctionsService {
  int chamadas = 0;
  String? nome;
  Map<String, dynamic>? parametros;
  FunctionsException? erro;
  Completer<Map<String, dynamic>>? pendente;
  Map<String, dynamic> resposta = {
    'transacaoId': 'recuperacao-1',
    'amount': 100,
    'saldoTotal': 105,
    'saldoReservado': 0,
    'saldoDisponivel': 105,
    'concedidoEm': '2026-11-23T12:00:00.000Z',
    'proximaRecuperacaoEm': '2026-11-24T12:00:00.000Z',
  };

  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
    chamadas++;
    nome = name;
    parametros = data;
    if (erro != null) throw erro!;
    return pendente == null ? resposta : await pendente!.future;
  }
}

void main() {
  final acao = find.byKey(const Key('resgatar_bonus_recuperacao'));
  final intervalo = find.byKey(const Key('bonus_recuperacao_intervalo'));
  late _Functions functions;
  late BonusRecuperacaoService service;

  setUp(() {
    functions = _Functions();
    service = BonusRecuperacaoService(functionsService: functions);
  });

  Widget tela(Carteira carteira) => MaterialApp(
    home: Scaffold(body: BonusRecuperacaoCard(carteira: carteira, service: service)),
  );

  test('lê timestamp e libera exatamente após 24 horas, nunca com reservas ou saldo 10', () {
    final ultimo = DateTime.utc(2026, 11, 23, 12);
    final carteira = Carteira.fromMap({
      'saldoTotal': 9,
      'saldoReservado': 0,
      'lastRecoveryBonusAt': Timestamp.fromDate(ultimo),
    });
    expect(carteira.lastRecoveryBonusAt, ultimo);
    expect(carteira.podeResgatarBonus(ultimo.add(const Duration(hours: 24))
        .subtract(const Duration(microseconds: 1))), isFalse);
    expect(carteira.podeResgatarBonus(ultimo.add(const Duration(hours: 24))), isTrue);
    expect(Carteira(saldoTotal: 10, saldoReservado: 0).podeResgatarBonus(ultimo), isFalse);
    expect(Carteira(saldoTotal: 9, saldoReservado: 1).podeResgatarBonus(ultimo), isFalse);
    expect(() => Carteira.fromMap({
      'saldoTotal': 0, 'saldoReservado': 0, 'lastRecoveryBonusAt': 'ontem',
    }), throwsFormatException);
  });

  test('resgata sem payload e interpreta confirmação completa', () async {
    final resultado = await service.resgatar();
    expect(functions.nome, CallableNames.claimRecoveryBonus);
    expect(functions.parametros, isNull);
    expect(resultado.transacaoId, 'recuperacao-1');
    expect(resultado.amount, 100);
    expect(resultado.carteira.saldoDisponivel, 105);
    expect(resultado.concedidoEm, DateTime.utc(2026, 11, 23, 12));
    expect(resultado.proximaRecuperacaoEm, DateTime.utc(2026, 11, 24, 12));
  });

  final mensagens = {
    'saldo-reservado': 'Você tem BetCoins reservadas em desafios abertos.',
    'saldo-suficiente': 'O bônus só está disponível com menos de 10 BetCoins livres.',
    'intervalo-nao-cumprido': 'Aguarde 24 horas desde o último bônus para resgatar novamente.',
    'perfil-inexistente': 'Seu perfil e sua carteira ainda não foram criados.',
  };
  for (final motivo in mensagens.keys) {
    test('traduz $motivo sem expor mensagem técnica', () async {
      functions.erro = FunctionsException(code: 'failed-precondition', message: 'interno', motivo: motivo);
      await expectLater(service.resgatar(), throwsA(isA<BonusRecuperacaoException>()
        .having((e) => e.motivo, 'motivo', motivo)
        .having((e) => e.message, 'mensagem', mensagens[motivo])));
    });
  }

  for (final codigo in ['unavailable', 'deadline-exceeded']) {
    test('$codigo não confirma nem repete o resgate', () async {
      functions.erro = FunctionsException(code: codigo, message: 'interno');
      await expectLater(service.resgatar(), throwsA(isA<BonusRecuperacaoException>()
        .having((e) => e.semConfirmacaoDoServidor, 'sem confirmação', isTrue)
        .having((e) => e.message, 'mensagem', contains('Sem confirmação do servidor'))));
      expect(functions.chamadas, 1);
    });
  }

  test('resposta inválida nunca confirma o resgate', () async {
    functions.resposta['saldoDisponivel'] = 999;
    await expectLater(service.resgatar(), throwsA(isA<BonusRecuperacaoException>()
      .having((e) => e.motivo, 'motivo', 'resposta-invalida')));
  });

  testWidgets('elegível mostra ação; saldo suficiente e reserva não mostram nada', (tester) async {
    await tester.pumpWidget(tela(Carteira(saldoTotal: 9, saldoReservado: 0)));
    expect(acao, findsOneWidget);
    for (final carteira in [
      Carteira(saldoTotal: 10, saldoReservado: 0),
      Carteira(saldoTotal: 9, saldoReservado: 1),
    ]) {
      await tester.pumpWidget(tela(carteira));
      expect(acao, findsNothing);
      expect(intervalo, findsNothing);
    }
  });

  testWidgets('intervalo mostra horário local e libera ação ao completar 24h', (tester) async {
    await tester.pumpWidget(tela(Carteira(
      saldoTotal: 0, saldoReservado: 0,
      lastRecoveryBonusAt: DateTime.now().subtract(const Duration(hours: 23)),
    )));
    expect(acao, findsNothing);
    expect(intervalo, findsOneWidget);
    expect(tester.widget<Text>(intervalo).data, contains(' às '));
    await tester.pumpWidget(tela(Carteira(
      saldoTotal: 0, saldoReservado: 0,
      lastRecoveryBonusAt: DateTime.now().subtract(const Duration(hours: 24)),
    )));
    expect(acao, findsOneWidget);
    expect(intervalo, findsNothing);
  });

  testWidgets('toque duplo chama uma vez, carrega e confirma por SnackBar', (tester) async {
    functions.pendente = Completer();
    await tester.pumpWidget(tela(Carteira(saldoTotal: 5, saldoReservado: 0)));
    await tester.tap(acao);
    await tester.tap(acao);
    await tester.pump();
    expect(functions.chamadas, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(acao).onPressed, isNull);
    final agora = DateTime.now().toUtc();
    functions.resposta['concedidoEm'] = agora.toIso8601String();
    functions.resposta['proximaRecuperacaoEm'] = agora.add(const Duration(hours: 24)).toIso8601String();
    functions.pendente!.complete(functions.resposta);
    await tester.pumpAndSettle();
    expect(find.text('Bônus resgatado! +100 BetCoins.'), findsOneWidget);
    expect(acao, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sem conexão exibe erro e não exibe sucesso ou repete chamada', (tester) async {
    functions.erro = FunctionsException(code: 'unavailable', message: 'interno');
    await tester.pumpWidget(tela(Carteira(saldoTotal: 0, saldoReservado: 0)));
    await tester.tap(acao);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sem confirmação do servidor'), findsOneWidget);
    expect(find.textContaining('Bônus resgatado!'), findsNothing);
    expect(functions.chamadas, 1);
    expect(tester.widget<FilledButton>(acao).onPressed, isNotNull);
  });

  testWidgets('erro de domínio chega ao SnackBar', (tester) async {
    functions.erro = FunctionsException(code: 'failed-precondition', message: 'interno', motivo: 'saldo-reservado');
    await tester.pumpWidget(tela(Carteira(saldoTotal: 0, saldoReservado: 0)));
    await tester.tap(acao);
    await tester.pumpAndSettle();
    expect(find.text(mensagens['saldo-reservado']!), findsOneWidget);
    expect(find.textContaining('Bônus resgatado!'), findsNothing);
  });
}
