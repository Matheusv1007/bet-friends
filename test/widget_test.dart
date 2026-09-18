import 'package:flutter_test/flutter_test.dart';
import 'package:betfriends/app.dart';

void main() {
  testWidgets('Verifica se a aplicação inicializa com o título BetFriends', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('BetFriends'), findsOneWidget);
  });
}
