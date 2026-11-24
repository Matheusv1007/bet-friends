import 'package:betfriends/telas_autenticacao/cadastro_page.dart';
import 'package:betfriends/telas_autenticacao/login_page.dart';
import 'package:betfriends/models/friendship_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/backend_ui.dart';

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo.first);
  await tester.pumpAndSettle();
  expect(alvo.first.hitTestable(), findsOneWidget);
  await tester.tap(alvo.first);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _percorrer(WidgetTester tester) async {
  // Visita também as linhas lazy: ausência de overflow só no primeiro quadro
  // não cobre a zona de risco, os valores ou os nomes no fim das listas.
  final rolaveis = find.byType(Scrollable).evaluate().toList();
  for (final elemento in rolaveis.reversed) {
    final estado = (elemento as StatefulElement).state as ScrollableState;
    if (estado.position.axis != Axis.vertical) continue;
    for (var passo = 0; passo < 100; passo++) {
      final posicao = estado.position;
      if (posicao.pixels >= posicao.maxScrollExtent) break;
      posicao.jumpTo((posicao.pixels + 400).clamp(0, posicao.maxScrollExtent));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  }
}

void main() {
  setUpAll(() async {
    final fonte = FontLoader('SchibstedGrotesk')
      ..addFont(rootBundle.load('assets/fonts/SchibstedGrotesk.ttf'));
    await fonte.load();
  });

  for (final largura in [320.0, 360.0]) {
    for (final escala in [1.0, 2.0]) {
      for (final tela in [
        'home',
        'login',
        'cadastro',
        'criar',
        'perfil',
        'extrato',
        'amigos',
        'buscar',
        'solicitacoes',
        'historico',
        'partida',
        'aceitar',
      ]) {
        testWidgets(
          '$tela em ${largura.toInt()} dp e texto ${escala}x sem overflow',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(largura, 568);
            tester.platformDispatcher.textScaleFactorTestValue = escala;
            addTearDown(() {
              tester.view.reset();
              tester.platformDispatcher.clearTextScaleFactorTestValue();
            });
            final backend = Backend()
              ..logado = tela != 'login' && tela != 'cadastro'
              ..solicitacoes = [
                SolicitacaoAmizade(
                  friendshipId: 's1',
                  remetente: diego,
                  createdAt: DateTime.utc(2026, 11, 23),
                ),
              ];
            await tester.pumpWidget(backend.app());
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            switch (tela) {
              case 'login':
                await _tocar(tester, find.byKey(const Key('login_entrar')));
                expect(find.byType(LoginPage), findsOneWidget);
              case 'cadastro':
                await _tocar(tester, find.text('Criar conta'));
                expect(find.byType(CadastroPage), findsOneWidget);
              case 'criar':
                await _tocar(tester, find.byIcon(Icons.add_circle_outline));
                await _tocar(
                  tester,
                  find.byKey(const Key('partida_desafio_m1')),
                );
              case 'perfil' ||
                  'extrato' ||
                  'amigos' ||
                  'buscar' ||
                  'solicitacoes':
                await _tocar(tester, find.text('Perfil'));
                final chave = switch (tela) {
                  'extrato' => 'perfil_extrato',
                  'amigos' => 'perfil_meus_amigos',
                  'buscar' => 'perfil_buscar_usuarios',
                  'solicitacoes' => 'perfil_solicitacoes_amizade',
                  _ => null,
                };
                if (chave != null) await _tocar(tester, find.byKey(Key(chave)));
                if (tela == 'buscar') {
                  await tester.enterText(
                    find.byKey(const Key('search_users_input')),
                    'mar',
                  );
                  await tester.pump(const Duration(seconds: 1));
                  await tester.pumpAndSettle();
                }
              case 'historico':
                await _tocar(
                  tester,
                  find.byKey(const Key('home_ver_todos_desafios')),
                );
              case 'partida':
                await _tocar(tester, find.byKey(const Key('card_partida_m1')));
              case 'aceitar':
                await _tocar(
                  tester,
                  find.byKey(const Key('btn_responder_desafio_c1')),
                );
              case 'home':
                await _tocar(
                  tester,
                  find.descendant(
                    of: find.byKey(const Key('home_alerta_desafios_pendentes')),
                    matching: find.text('Responder'),
                  ),
                );
            }
            await _percorrer(tester);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
