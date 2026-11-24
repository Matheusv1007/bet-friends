import 'package:flutter/material.dart';

import 'cores_app.dart';

/// Tom semântico de tags, avisos e SnackBars.
enum Tom {
  neutro(CoresApp.textoSuave, Icons.info_outline),
  sucesso(CoresApp.primario, Icons.check_circle_outline),
  atencao(CoresApp.atencao, Icons.warning_amber_rounded),
  destrutivo(CoresApp.destrutivo, Icons.error_outline);

  const Tom(this.cor, this.icone);

  /// Cor do texto e do ícone.
  final Color cor;

  /// Ícone que acompanha o tom em avisos.
  final IconData icone;

  /// Fundo opaco (a cor a 12% sobre o fundo do app; neutro usa a superfície 2),
  /// para o contraste não depender da superfície onde o componente está.
  Color get fundo => this == Tom.neutro
      ? CoresApp.superficie2
      : Color.alphaBlend(cor.withValues(alpha: 0.12), CoresApp.fundo);
}
