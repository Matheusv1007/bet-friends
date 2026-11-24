import 'package:flutter/material.dart';

import '../tema/raios_app.dart';
import '../tema/texto_app.dart';
import '../tema/tom.dart';

/// Etiqueta curta de estado ("AO VIVO 67'", "FINALIZADO"), em caixa alta.
class TagDeStatus extends StatelessWidget {
  const TagDeStatus(this.rotulo, this.tom, {super.key});

  final String rotulo;
  final Tom tom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: tom.fundo, borderRadius: RaiosApp.bordaTag),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          rotulo.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextoApp.minimo.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: tom.cor,
          ),
        ),
      ),
    );
  }
}
