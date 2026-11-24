import 'package:flutter/material.dart';

/// Paleta "Evolução": superfícies chapadas em 2 níveis, sem brilho nem gradiente.
abstract final class CoresApp {
  /// Fundo das telas.
  static const fundo = Color(0xFF0E141C);

  /// Superfície 1: cartões, grupos, barra inferior, diálogos e bottom sheets.
  static const superficie1 = Color(0xFF151C27);

  /// Superfície 2: campos, avatares, tags neutras e linha selecionada.
  static const superficie2 = Color(0xFF1C2532);

  /// Filete: divisores e bordas discretas.
  static const filete = Color(0xFF263142);

  /// Contorno: botão secundário e campo em repouso.
  static const contorno = Color(0xFF35425A);

  static const texto = Color(0xFFE8ECF1);
  static const textoSuave = Color(0xFF98A3B1);

  /// Primário e vitória: só em ação primária, seleção e vitória.
  static const primario = Color(0xFF45A880);

  /// Texto e ícones sobre o [primario] (branco daria contraste 2,9).
  static const sobrePrimario = Color(0xFF0E141C);

  /// [primario] a 16% sobre a [superficie1]: fundo de chip e item selecionados.
  static const primarioSuave = Color(0xFF1D3235);

  /// Atenção e "ao vivo".
  static const atencao = Color(0xFFD9A441);

  /// Destrutivo e perda.
  static const destrutivo = Color(0xFFE07264);
}
