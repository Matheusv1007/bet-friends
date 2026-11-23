import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Escudo do time em um quadro branco (RNF-012: a URL vem do provedor).
///
/// Mostra a imagem da [url] (PNG ou SVG) e, enquanto ela carrega, quando falha
/// ou quando o provedor não informou escudo, um ícone de escudo estilizado
/// pela cor do [nome].
class EscudoDoTime extends StatelessWidget {
  final String? url;
  final String nome;
  final double tamanho;

  const EscudoDoTime({
    super.key,
    required this.url,
    required this.nome,
    this.tamanho = 44,
  });

  static bool _ehSvg(String url) =>
      (Uri.tryParse(url)?.path ?? url).toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    final endereco = url?.trim();
    final fallback = _IconeDeEscudo(nome: nome, tamanho: tamanho * 0.68);

    Widget conteudo = fallback;
    if (endereco != null && endereco.isNotEmpty) {
      conteudo = _ehSvg(endereco)
          ? SvgPicture.network(
              endereco,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => fallback,
              errorBuilder: (_, _, _) => fallback,
            )
          : Image.network(
              endereco,
              fit: BoxFit.contain,
              loadingBuilder: (_, filho, progresso) =>
                  progresso == null ? filho : fallback,
              errorBuilder: (_, _, _) => fallback,
            );
    }

    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Center(child: conteudo),
    );
  }
}

/// Escudo genérico, na cor do clube quando o nome é conhecido.
class _IconeDeEscudo extends StatelessWidget {
  final String nome;
  final double tamanho;

  const _IconeDeEscudo({required this.nome, required this.tamanho});

  static const _cores = <(List<String>, Color)>[
    (['fla'], Color(0xFFC00000)),
    (['flu'], Color(0xFF800020)),
    (['pal'], Color(0xFF006437)),
    (['cor', 'sccp'], Color(0xFF111111)),
    (['sao', 'são'], Color(0xFFC00000)),
    (['san'], Color(0xFF222222)),
    (['vas'], Color(0xFF1E293B)),
    (['bot'], Color(0xFF0F172A)),
    (['gre'], Color(0xFF0D6EFD)),
    (['int'], Color(0xFFDC2626)),
    (['cru'], Color(0xFF1D4ED8)),
    (['cam', 'atletico', 'atlético'], Color(0xFF1E293B)),
    (['bah'], Color(0xFF0284C7)),
    (['for'], Color(0xFF1E40AF)),
    (['ath', 'furacao', 'furacão'], Color(0xFFB91C1C)),
    (['cui'], Color(0xFF15803D)),
    (['cri'], Color(0xFFCA8A04)),
    (['juv'], Color(0xFF16A34A)),
    (['goi', 'goiás'], Color(0xFF15803D)),
    (['vil'], Color(0xFFDC2626)),
    (['volta'], Color(0xFFE5A800)),
  ];

  @override
  Widget build(BuildContext context) {
    final minusculo = nome.toLowerCase();
    var cor = Colors.black87;
    for (final (trechos, corDoClube) in _cores) {
      if (trechos.any(minusculo.contains)) {
        cor = corDoClube;
        break;
      }
    }
    return Icon(Icons.shield, color: cor, size: tamanho);
  }
}
