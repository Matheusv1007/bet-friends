import 'package:flutter/material.dart';

import '../tema/texto_app.dart';

/// Título de seção (12/600, caixa alta, texto suave) com ação opcional à direita.
class TituloDeSecao extends StatelessWidget {
  const TituloDeSecao(this.texto, {super.key, this.acao});

  final String texto;

  /// Normalmente um `BotaoTexto(pequeno: true)`, como "Ver todas".
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(texto.toUpperCase(), style: TextoApp.secao),
          ),
        ),
        ?acao,
      ],
    );
  }
}
