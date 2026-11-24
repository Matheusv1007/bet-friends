import 'package:flutter/material.dart';

/// Os 4 raios do app; não use outros.
abstract final class RaiosApp {
  static const double tag = 4;
  static const double chip = 8;
  static const double botao = 10;
  static const double cartao = 12;

  static const bordaTag = BorderRadius.all(Radius.circular(tag));

  /// Chip e tabela.
  static const bordaChip = BorderRadius.all(Radius.circular(chip));

  /// Botão e campo.
  static const bordaBotao = BorderRadius.all(Radius.circular(botao));

  /// Cartão e grupo.
  static const bordaCartao = BorderRadius.all(Radius.circular(cartao));
}
