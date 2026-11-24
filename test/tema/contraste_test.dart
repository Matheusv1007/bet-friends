import 'package:betfriends/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Razão de contraste WCAG 2.x entre duas cores opacas.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final escuro = la > lb ? lb : la;
  return (claro + 0.05) / (escuro + 0.05);
}

void main() {
  const superficies = {
    'fundo': CoresApp.fundo,
    'superfície 1': CoresApp.superficie1,
    'superfície 2': CoresApp.superficie2,
  };
  const textos = {
    'texto': CoresApp.texto,
    'texto suave': CoresApp.textoSuave,
    'primário': CoresApp.primario,
    'atenção': CoresApp.atencao,
    'destrutivo': CoresApp.destrutivo,
  };

  test('a fórmula confere com os extremos do WCAG', () {
    expect(contraste(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contraste(CoresApp.fundo, CoresApp.fundo), closeTo(1, 0.001));
  });

  for (final t in textos.entries) {
    for (final s in superficies.entries) {
      test('${t.key} sobre ${s.key} tem contraste ≥ 4,5', () {
        expect(contraste(t.value, s.value), greaterThanOrEqualTo(4.5));
      });
    }
  }

  test('texto escuro sobre o primário tem contraste ≥ 4,5', () {
    expect(contraste(CoresApp.sobrePrimario, CoresApp.primario), greaterThanOrEqualTo(4.5));
  });

  test('texto sobre o fundo de seleção (chip, indicador) tem contraste ≥ 4,5', () {
    expect(contraste(CoresApp.texto, CoresApp.primarioSuave), greaterThanOrEqualTo(4.5));
  });

  for (final tom in Tom.values) {
    test('tag e aviso no tom ${tom.name} têm contraste ≥ 4,5', () {
      expect(tom.fundo.a, 1.0, reason: 'o fundo do tom precisa ser opaco');
      expect(contraste(tom.cor, tom.fundo), greaterThanOrEqualTo(4.5));
      expect(contraste(CoresApp.texto, tom.fundo), greaterThanOrEqualTo(4.5));
    });
  }
}
