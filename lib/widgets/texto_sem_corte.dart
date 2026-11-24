import 'package:flutter/material.dart';

/// Texto em até [maxLinhas] linhas que nunca quebra uma palavra no meio.
///
/// Se alguma palavra não cabe na largura, ou o texto não cabe nas linhas,
/// reduz a fonte (já com a escala do sistema aplicada) de 1 em 1 até caber,
/// sem descer de 12. Só abaixo disso entra a reticência. Para nomes de
/// clubes e de pessoas ("Internacional", "Athletico Paranaense").
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

  static const double _tamanhoMinimo = 12;

  static bool _cabe(
    String texto,
    TextStyle estilo,
    double largura,
    int maxLinhas,
    TextDirection direcao,
  ) {
    final palavra = TextPainter(textDirection: direcao, maxLines: 1);
    try {
      for (final p in texto.split(RegExp(r'\s+'))) {
        if (p.isEmpty) continue;
        palavra
          ..text = TextSpan(text: p, style: estilo)
          ..layout();
        if (palavra.width > largura) return false;
      }
    } finally {
      palavra.dispose();
    }
    final todo = TextPainter(
      text: TextSpan(text: texto, style: estilo),
      textDirection: direcao,
    )..layout(maxWidth: largura);
    final linhas = todo.computeLineMetrics().length;
    todo.dispose();
    return linhas <= maxLinhas;
  }

  /// Tamanho de fonte (já escalado, para usar com `TextScaler.noScaling`) em
  /// que [texto] cabe em [largura] e [maxLinhas] sem partir palavra; nunca
  /// abaixo de 12. Para quem precisa do tamanho sem o `LayoutBuilder`.
  static double tamanhoQueCabe(
    BuildContext context,
    String texto,
    TextStyle estilo,
    double largura, {
    int maxLinhas = 2,
  }) {
    final direcao = Directionality.of(context);
    final base = estilo.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
    var tamanho = MediaQuery.textScalerOf(context).scale(base);
    if (!largura.isFinite) return tamanho;
    while (tamanho > _tamanhoMinimo &&
        !_cabe(texto, estilo.copyWith(fontSize: tamanho), largura, maxLinhas, direcao)) {
      tamanho = (tamanho - 1).clamp(_tamanhoMinimo, tamanho);
    }
    return tamanho;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) => Text(
        texto,
        style: estilo.copyWith(
          fontSize: tamanhoQueCabe(
            context,
            texto,
            estilo,
            restricoes.maxWidth,
            maxLinhas: maxLinhas,
          ),
        ),
        textScaler: TextScaler.noScaling,
        maxLines: maxLinhas,
        overflow: TextOverflow.ellipsis,
        textAlign: alinhamento,
      ),
    );
  }
}
