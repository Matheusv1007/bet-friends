import 'package:flutter_test/flutter_test.dart';
import 'package:betfriends/app.dart';

import 'support/fake_auth.dart';

void main() {
  testWidgets('Verifica se a aplicação inicializa com o título BetFriends', (WidgetTester tester) async {
    // O AuthGate consulta a sessão ao iniciar; sem usuário, exibe o Login
    await tester.pumpWidget(App(authService: FakeAuthService()));
    await tester.pump();
    expect(find.text('BetFriends'), findsOneWidget);
  });
}
