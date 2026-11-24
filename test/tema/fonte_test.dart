import 'package:betfriends/tema/texto_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prova que o `fontWeight` move o eixo `wght` da fonte variável embutida:
/// se o Flutter deixar de fazer isso, os pesos passam a ter a mesma largura
/// (ou ganham negrito sintético) e este teste falha.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final carregador = FontLoader(TextoApp.familia)
      ..addFont(rootBundle.load('assets/fonts/SchibstedGrotesk.ttf'));
    await carregador.load();
  });

  double largura(FontWeight peso) {
    final pintor = TextPainter(
      text: TextSpan(
        text: 'Hamburgefonts 0123',
        style: TextoApp.corpo.copyWith(fontSize: 30, fontWeight: peso),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = pintor.width;
    pintor.dispose();
    return w;
  }

  test('os pesos 400, 500, 600, 700 e 800 têm larguras crescentes', () {
    final larguras = [
      for (final p in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
        FontWeight.w800,
      ])
        largura(p),
    ];
    for (var i = 1; i < larguras.length; i++) {
      expect(larguras[i], greaterThan(larguras[i - 1]), reason: 'larguras: $larguras');
    }
  });
}
