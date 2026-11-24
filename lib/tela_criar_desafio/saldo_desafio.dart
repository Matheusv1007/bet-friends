import 'package:flutter/material.dart';

import '../tema/tema.dart';

/// Saldo compacto ao lado do título "Valor": "Disponível 900".
class SaldoDesafio extends StatelessWidget {
  final int? saldoDisponivel;

  const SaldoDesafio({super.key, required this.saldoDisponivel});

  @override
  Widget build(BuildContext context) {
    final saldo = saldoDisponivel;
    return Text.rich(
      key: const Key('criar_desafio_saldo'),
      TextSpan(
        text: saldo == null ? 'Carregando...' : 'Disponível ',
        children: [
          if (saldo != null)
            TextSpan(
              text: '$saldo',
              style: TextoApp.tabular(TextoApp.secundario).copyWith(
                fontWeight: FontWeight.w700,
                color: CoresApp.texto,
              ),
            ),
        ],
      ),
      style: TextoApp.secundario,
    );
  }
}
