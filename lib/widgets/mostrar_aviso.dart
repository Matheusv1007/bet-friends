import 'package:flutter/material.dart';

import '../tema/espacos_app.dart';
import '../tema/tom.dart';

/// Mostra um SnackBar do tema (flutuante, ícone por [tom]), substituindo o atual.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> mostrarAviso(
  BuildContext context,
  String texto, {
  Tom tom = Tom.neutro,
  SnackBarAction? acao,
  Duration duracao = const Duration(seconds: 4),
}) {
  final mensageiro = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  return mensageiro.showSnackBar(
    SnackBar(
      duration: duracao,
      action: acao,
      content: Row(
        children: [
          Icon(tom.icone, size: 20, color: tom.cor),
          const SizedBox(width: EspacosApp.e12),
          Expanded(child: Text(texto)),
        ],
      ),
    ),
  );
}
