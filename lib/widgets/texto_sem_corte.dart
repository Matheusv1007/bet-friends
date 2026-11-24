import 'package:flutter/material.dart';

/// Nome com quebra natural, sem encolher a fonte para caber.
/// Com texto ampliado, deixa o conteúdo crescer sem limitar as linhas.
class TextoSemCorte extends StatelessWidget {
  const TextoSemCorte(
    this.texto, {
    super.key,
    required this.estilo,
    this.maxLinhas = 2,
    this.alinhamento = TextAlign.start,
  });

  final String texto;
  final TextStyle estilo;
  final int maxLinhas;
  final TextAlign alinhamento;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: estilo,
      maxLines: MediaQuery.textScalerOf(context).scale(1) > 1
          ? null
          : maxLinhas,
      overflow: MediaQuery.textScalerOf(context).scale(1) > 1
          ? TextOverflow.visible
          : TextOverflow.ellipsis,
      textAlign: alinhamento,
    );
  }
}
