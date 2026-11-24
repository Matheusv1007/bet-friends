import 'package:flutter/material.dart';

import 'cores_app.dart';

/// Escala tipográfica: 7 tamanhos (12, 13, 15, 18, 20, 22, 36); mínimo 12.
///
/// A Schibsted Grotesk é embutida como um único arquivo variável (eixo `wght`
/// 400–900). Nesta versão do Flutter o `fontWeight` já move o eixo `wght`
/// (verificado em `test/tema/fonte_test.dart`), então não há instâncias
/// estáticas nem `FontVariation` no tema: basta usar `fontWeight`.
abstract final class TextoApp {
  static const familia = 'SchibstedGrotesk';

  /// Título de tela: 22/700.
  static const tituloDeTela = TextStyle(
    fontFamily: familia,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0,
  );

  /// Título de AppBar e de diálogo: 20/700.
  static const tituloDeBarra = TextStyle(
    fontFamily: familia,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0,
  );

  /// Título de seção: 12/600 com espaçamento 0,8; escreva em caixa alta.
  static const secao = TextStyle(
    fontFamily: familia,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0.8,
    color: CoresApp.textoSuave,
  );

  /// Corpo: 15/400.
  static const corpo = TextStyle(
    fontFamily: familia,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0,
  );

  /// Corpo forte: 15/600 (nomes, rótulos de botão).
  static const corpoForte = TextStyle(
    fontFamily: familia,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
  );

  /// Secundário: 13/400 em texto suave (metadados, datas, ajuda).
  static const secundario = TextStyle(
    fontFamily: familia,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: 0,
    color: CoresApp.textoSuave,
  );

  /// Mínimo: 12/500. Nenhum texto do app fica menor que isto.
  static const minimo = TextStyle(
    fontFamily: familia,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0,
  );

  /// Saldo: 36/700 com números tabulares. Com separador de milhar ("1.000")
  /// o ponto fica com largura de dígito; aí use `fontFeatures: const []`.
  static const saldo = TextStyle(
    fontFamily: familia,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Placar: 18/700 com números tabulares.
  static const placar = TextStyle(
    fontFamily: familia,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Números tabulares em [estilo]. Só para números puros (saldo, placar,
  /// valores): em horários ("22:39") e datas a fonte daria ao ponto e aos
  /// dois-pontos a largura de um dígito.
  static TextStyle tabular(TextStyle estilo) =>
      estilo.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Todos os papéis do Material mapeados na escala (nenhum abaixo de 12).
  /// `bodySmall` é o secundário (texto suave); os demais usam o texto claro.
  static final TextTheme textTheme = TextTheme(
    displayLarge: _claro(saldo.copyWith(fontFeatures: const [])),
    displayMedium: _claro(saldo.copyWith(fontFeatures: const [])),
    displaySmall: _claro(saldo.copyWith(fontFeatures: const [])),
    headlineLarge: _claro(tituloDeTela),
    headlineMedium: _claro(tituloDeTela),
    headlineSmall: _claro(tituloDeTela),
    titleLarge: _claro(tituloDeBarra),
    titleMedium: _claro(corpoForte),
    titleSmall: _claro(secundario.copyWith(fontWeight: FontWeight.w600)),
    bodyLarge: _claro(corpo),
    bodyMedium: _claro(corpo),
    bodySmall: secundario,
    labelLarge: _claro(corpoForte),
    labelMedium: _claro(secundario.copyWith(fontWeight: FontWeight.w500)),
    labelSmall: _claro(minimo),
  );

  static TextStyle _claro(TextStyle estilo) =>
      estilo.copyWith(color: CoresApp.texto);
}
