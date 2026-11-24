import 'package:flutter/material.dart';

import '../tema/tema.dart';

/// Avatar circular com as iniciais do nome ("Carla Mendes" → CM), na
/// superfície 2. Decorativo: o nome aparece sempre ao lado.
class AvatarDeIniciais extends StatelessWidget {
  final String nome;
  final double tamanho;

  const AvatarDeIniciais(this.nome, {super.key, this.tamanho = 40});

  /// Primeira letra do primeiro e do último nome, em maiúsculas; "?" sem nome.
  static String iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final primeira = partes.first.characters.first;
    if (partes.length == 1) return primeira.toUpperCase();
    return (primeira + partes.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: tamanho,
        height: tamanho,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: CoresApp.superficie2,
          shape: BoxShape.circle,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            iniciais(nome),
            textScaler: TextScaler.noScaling,
            style: TextoApp.corpoForte.copyWith(
              fontSize: tamanho * 0.38,
              height: 1,
              color: CoresApp.texto,
            ),
          ),
        ),
      ),
    );
  }
}
