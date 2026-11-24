import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tema/tema.dart';

/// Escudo do time num círculo neutro (RNF-012: a URL vem do provedor).
///
/// Mostra a imagem da [url] (PNG ou SVG) sobre a superfície 2 e, enquanto ela
/// carrega, quando falha ou quando o provedor não informou escudo, um disco
/// na cor do clube com a [sigla] de 3 letras. Tamanhos usuais: 22, 28, 36,
/// 44 e 56.
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

  static const _acentos = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'é': 'e', 'ê': 'e',
    'è': 'e', 'ë': 'e', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ó': 'o',
    'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ú': 'u', 'ù': 'u', 'û': 'u',
    'ü': 'u', 'ç': 'c', 'ñ': 'n',
  };

  static String _semAcento(String texto) => texto
      .toLowerCase()
      .split('')
      .map((c) => _acentos[c] ?? c)
      .join();

  /// Siglas que não saem da regra geral.
  static const _siglasConhecidas = {
    'atletico de madrid': 'ATM',
    'atletico madrid': 'ATM',
    'manchester city': 'MCI',
    'man city': 'MCI',
    'manchester united': 'MUN',
    'man united': 'MUN',
    'paris saint-germain': 'PSG',
    'paris saint germain': 'PSG',
    'red bull bragantino': 'RBB',
    'sao paulo': 'SAO',
  };

  /// Prefixos de razão social que não identificam o clube ("FC Barcelona").
  static const _prefixos = {
    'fc', 'sc', 'ac', 'as', 'ss', 'ssc', 'cf', 'ca', 'cr', 'ec', 'se', 'afc',
    'club', 'clube', 'sport', 'esporte',
  };

  /// Sigla de 3 letras, maiúsculas e sem acento: as 3 primeiras letras do nome
  /// ("Internacional" → INT, "Atlético Mineiro" → ATL), "Real X" → R + X
  /// ("Real Madrid" → RMA) e exceções evidentes ("Manchester City" → MCI).
  static String sigla(String nome) {
    final limpo = _semAcento(nome.trim()).replaceAll(RegExp(r'\s+'), ' ');
    final conhecida = _siglasConhecidas[limpo];
    if (conhecida != null) return conhecida;

    final palavras = [
      for (final p in limpo.split(RegExp(r'[\s\-]+')))
        if (p.replaceAll(RegExp(r'[^a-z0-9]'), '').isNotEmpty)
          p.replaceAll(RegExp(r'[^a-z0-9]'), ''),
    ];
    while (palavras.length > 1 && _prefixos.contains(palavras.first)) {
      palavras.removeAt(0);
    }
    if (palavras.isEmpty) return '?';
    if (palavras.length > 1 && palavras.first == 'real') {
      final resto = palavras[1];
      return ('r${resto.substring(0, resto.length < 2 ? resto.length : 2)}')
          .toUpperCase();
    }
    final primeira = palavras.first;
    return primeira.substring(0, primeira.length < 3 ? primeira.length : 3).toUpperCase();
  }

  /// Cor principal do clube pelo nome; `null` se o clube não é conhecido.
  /// Os clubes europeus vêm antes, porque trechos curtos dos brasileiros
  /// ("int", "juv") também aparecem nos nomes deles.
  static const _cores = <(List<String>, Color)>[
    (['arsenal'], Color(0xFFDB0007)),
    (['chelsea'], Color(0xFF034694)),
    (['liverpool'], Color(0xFFC8102E)),
    (['manchester city', 'man city'], Color(0xFF6CABDD)),
    (['manchester united', 'man united', 'man utd'], Color(0xFFDA291C)),
    (['tottenham', 'spurs'], Color(0xFF132257)),
    (['real madrid'], Color(0xFFFEBE10)),
    (['barcelona', 'barca'], Color(0xFFA50044)),
    (['atletico de madrid', 'atletico madrid', 'atleti'], Color(0xFFCB3524)),
    (['juventus'], Color(0xFF1A1A1A)),
    (['inter de milao', 'inter milan', 'internazionale', 'inter milao'], Color(0xFF0068A8)),
    (['milan'], Color(0xFFFB090B)),
    (['napoli'], Color(0xFF12A0D7)),
    (['roma'], Color(0xFF8E1F2F)),
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

  /// Cor do clube pelo [nome] (sem diferenciar caixa nem acento), ou `null`.
  static Color? corDoClube(String nome) {
    final alvo = _semAcento(nome);
    for (final (trechos, cor) in _cores) {
      if (trechos.any((t) => alvo.contains(_semAcento(t)))) return cor;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final endereco = url?.trim();
    final disco = _DiscoDoClube(nome: nome, tamanho: tamanho);
    if (endereco == null || endereco.isEmpty) return disco;

    // O substituto ocupa o círculo inteiro, não só a área interna da moldura.
    final substituto = OverflowBox(
      maxWidth: tamanho,
      maxHeight: tamanho,
      child: disco,
    );
    final imagem = _ehSvg(endereco)
        ? SvgPicture.network(
            endereco,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => substituto,
            errorBuilder: (_, _, _) => substituto,
          )
        : Image.network(
            endereco,
            fit: BoxFit.contain,
            frameBuilder: (_, filho, quadro, sincrono) =>
                quadro == null && !sincrono ? substituto : filho,
            errorBuilder: (_, _, _) => substituto,
          );

    return Container(
      width: tamanho,
      height: tamanho,
      padding: EdgeInsets.all(tamanho * 0.16),
      decoration: const BoxDecoration(
        color: CoresApp.superficie2,
        shape: BoxShape.circle,
      ),
      child: Center(child: imagem),
    );
  }
}

/// Disco na cor do clube com a sigla; clube desconhecido usa a superfície 2.
class _DiscoDoClube extends StatelessWidget {
  final String nome;
  final double tamanho;

  const _DiscoDoClube({required this.nome, required this.tamanho});

  @override
  Widget build(BuildContext context) {
    final cor = EscudoDoTime.corDoClube(nome);
    final fundo = cor ?? CoresApp.superficie2;
    final corDaSigla = cor == null
        ? CoresApp.texto
        : (fundo.computeLuminance() > 0.4 ? CoresApp.fundo : CoresApp.texto);
    // A sigla é desenho, não texto: o nome do clube está sempre ao lado.
    // Não escala com a fonte do sistema, para não estourar o disco.
    return ExcludeSemantics(
      child: Container(
        width: tamanho,
        height: tamanho,
        padding: EdgeInsets.symmetric(horizontal: tamanho * 0.14),
        decoration: BoxDecoration(
          color: fundo,
          shape: BoxShape.circle,
          border: cor == null ? Border.all(color: CoresApp.contorno) : null,
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            EscudoDoTime.sigla(nome),
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: TextoApp.familia,
              fontSize: tamanho * 0.34,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0.2,
              color: corDaSigla,
            ),
          ),
        ),
      ),
    );
  }
}
