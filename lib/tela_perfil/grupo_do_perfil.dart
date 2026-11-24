import 'package:flutter/material.dart';

import '../tema/tema.dart';
import '../widgets/componentes.dart';

/// Grupo do Perfil: título de seção e um cartão chapado com as linhas.
class GrupoDoPerfil extends StatelessWidget {
  final String titulo;
  final List<Widget> linhas;

  const GrupoDoPerfil({super.key, required this.titulo, required this.linhas});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloDeSecao(titulo),
        const SizedBox(height: EspacosApp.e8),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: linhas),
        ),
      ],
    );
  }
}
