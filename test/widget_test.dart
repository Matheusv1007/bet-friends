import 'package:flutter_test/flutter_test.dart';
import 'package:betfriends/app.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/telas_autenticacao/login_page.dart';
import 'package:betfriends/widgets/logo_bet_friends.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

void main() {
  testWidgets('Verifica se a aplicação inicializa com o título BetFriends', (WidgetTester tester) async {
    // O AuthGate consulta a sessão ao iniciar; sem usuário, exibe o Login
    await tester.pumpWidget(App(authService: FakeAuthService()));
    await tester.pump();
    expect(find.byType(LogoBetFriends), findsOneWidget);
    expect(find.bySemanticsLabel('BetFriends'), findsOneWidget);
  });

  testWidgets('desafios usam a sessão injetada sem inicializar o Firebase', (tester) async {
    await tester.pumpWidget(App(authService: FakeAuthService()));
    await tester.pump();

    final contexto = tester.element(find.byType(LoginPage));
    final desafios = contexto.read<ChallengeService?>();
    expect(desafios, isNotNull);
    expect(await desafios!.listarDesafios(), isEmpty);
  });

  testWidgets('preserva o serviço de desafios injetado', (tester) async {
    final auth = FakeAuthService();
    final desafios = ChallengeService(authService: auth);
    await tester.pumpWidget(App(authService: auth, challengeService: desafios));
    await tester.pump();

    final contexto = tester.element(find.byType(LoginPage));
    expect(contexto.read<ChallengeService?>(), same(desafios));
  });
}
