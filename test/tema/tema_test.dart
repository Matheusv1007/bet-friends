import 'dart:convert';

import 'package:betfriends/app.dart';
import 'package:betfriends/telas_autenticacao/login_page.dart';
import 'package:betfriends/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth.dart';

void main() {
  final tema = TemaApp.escuro;

  void confereEstilo(String nome, TextStyle? estilo) {
    expect(estilo, isNotNull, reason: nome);
    expect(estilo!.fontFamily, TextoApp.familia, reason: nome);
    expect(estilo.fontSize, greaterThanOrEqualTo(12), reason: '$nome abaixo do mínimo');
  }

  test('o tema é escuro, Material 3, com as cores dos tokens', () {
    expect(tema.useMaterial3, isTrue);
    expect(tema.brightness, Brightness.dark);
    expect(tema.scaffoldBackgroundColor, CoresApp.fundo);
    final cs = tema.colorScheme;
    expect(cs.primary, CoresApp.primario);
    expect(cs.onPrimary, CoresApp.sobrePrimario);
    expect(cs.error, CoresApp.destrutivo);
    expect(cs.tertiary, CoresApp.atencao);
    expect(cs.onSurface, CoresApp.texto);
    expect(cs.onSurfaceVariant, CoresApp.textoSuave);
    expect(cs.outline, CoresApp.contorno);
    expect(cs.outlineVariant, CoresApp.filete);
    expect(tema.dividerTheme.color, CoresApp.filete);
    expect(tema.inputDecorationTheme.fillColor, CoresApp.superficie2);
    expect(tema.dialogTheme.backgroundColor, CoresApp.superficie1);
    expect(tema.bottomSheetTheme.backgroundColor, CoresApp.superficie1);
    expect(tema.snackBarTheme.backgroundColor, CoresApp.superficie2);
    expect(tema.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(tema.textSelectionTheme.cursorColor, CoresApp.primario);
    expect(tema.progressIndicatorTheme.color, CoresApp.primario);
  });

  test('toda a tipografia usa a Schibsted Grotesk e nada fica abaixo de 12', () {
    final t = tema.textTheme;
    final papeis = {
      'displayLarge': t.displayLarge,
      'displayMedium': t.displayMedium,
      'displaySmall': t.displaySmall,
      'headlineLarge': t.headlineLarge,
      'headlineMedium': t.headlineMedium,
      'headlineSmall': t.headlineSmall,
      'titleLarge': t.titleLarge,
      'titleMedium': t.titleMedium,
      'titleSmall': t.titleSmall,
      'bodyLarge': t.bodyLarge,
      'bodyMedium': t.bodyMedium,
      'bodySmall': t.bodySmall,
      'labelLarge': t.labelLarge,
      'labelMedium': t.labelMedium,
      'labelSmall': t.labelSmall,
    };
    papeis.forEach(confereEstilo);

    confereEstilo('AppBar', tema.appBarTheme.titleTextStyle);
    confereEstilo('SnackBar', tema.snackBarTheme.contentTextStyle);
    confereEstilo('Dialog título', tema.dialogTheme.titleTextStyle);
    confereEstilo('Dialog conteúdo', tema.dialogTheme.contentTextStyle);
    confereEstilo('Chip', tema.chipTheme.labelStyle);
    confereEstilo('Tooltip', tema.tooltipTheme.textStyle);
    confereEstilo('Campo dica', tema.inputDecorationTheme.hintStyle);
    confereEstilo('Campo ajuda', tema.inputDecorationTheme.helperStyle);
    confereEstilo('Campo erro', tema.inputDecorationTheme.errorStyle);
    confereEstilo('ListTile subtítulo', tema.listTileTheme.subtitleTextStyle);
    for (final estilo in [
      TextoApp.tituloDeTela,
      TextoApp.tituloDeBarra,
      TextoApp.secao,
      TextoApp.corpo,
      TextoApp.corpoForte,
      TextoApp.secundario,
      TextoApp.minimo,
      TextoApp.saldo,
      TextoApp.placar,
    ]) {
      confereEstilo('TextoApp', estilo);
    }
  });

  test('a escala segue o protótipo e só o saldo e o placar são tabulares', () {
    expect((TextoApp.tituloDeTela.fontSize, TextoApp.tituloDeTela.fontWeight), (22, FontWeight.w700));
    expect((TextoApp.tituloDeBarra.fontSize, TextoApp.tituloDeBarra.fontWeight), (20, FontWeight.w700));
    expect((TextoApp.secao.fontSize, TextoApp.secao.letterSpacing), (12, 0.8));
    expect((TextoApp.corpo.fontSize, TextoApp.corpoForte.fontWeight), (15, FontWeight.w600));
    expect(TextoApp.secundario.fontSize, 13);
    expect((TextoApp.saldo.fontSize, TextoApp.placar.fontSize), (36, 18));
    const tabular = FontFeature.tabularFigures();
    expect(TextoApp.saldo.fontFeatures, contains(tabular));
    expect(TextoApp.placar.fontFeatures, contains(tabular));
    expect(TextoApp.corpo.fontFeatures, isNull);
    expect(TextoApp.tabular(TextoApp.corpo).fontFeatures, contains(tabular));
  });

  test('AppBar único: fundo da tela, título 20/700 à esquerda, sem elevação', () {
    final a = tema.appBarTheme;
    expect(a.backgroundColor, CoresApp.fundo);
    expect(a.centerTitle, isFalse);
    expect(a.elevation, 0);
    expect(a.scrolledUnderElevation, 0);
    expect(a.titleTextStyle!.fontSize, 20);
    expect(a.titleTextStyle!.fontWeight, FontWeight.w700);
    expect(a.systemOverlayStyle, TemaApp.barrasDoSistema);
  });

  test('barras do sistema com ícones claros sobre o fundo escuro', () {
    const b = TemaApp.barrasDoSistema;
    expect(b.statusBarColor, Colors.transparent);
    expect(b.statusBarIconBrightness, Brightness.light);
    expect(b.systemNavigationBarColor, CoresApp.fundo);
    expect(b.systemNavigationBarIconBrightness, Brightness.light);
  });

  test('a fonte está declarada no pubspec', () async {
    final manifesto = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final familia = manifesto.cast<Map<String, dynamic>>().firstWhere(
          (f) => f['family'] == TextoApp.familia,
        );
    expect(
      (familia['fonts'] as List).map((f) => f['asset']),
      contains('assets/fonts/SchibstedGrotesk.ttf'),
    );
    final licenca = await rootBundle.loadString('assets/fonts/OFL-SchibstedGrotesk.txt');
    expect(licenca, contains('SIL Open Font License'));
  });

  testWidgets('o App usa o tema escuro e o título BetFriends', (tester) async {
    await tester.pumpWidget(App(authService: FakeAuthService()));
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'BetFriends');
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme, same(TemaApp.escuro));
    expect(app.darkTheme, same(TemaApp.escuro));
    final contexto = tester.element(find.byType(LoginPage));
    expect(Theme.of(contexto).colorScheme.primary, CoresApp.primario);
  });
}
