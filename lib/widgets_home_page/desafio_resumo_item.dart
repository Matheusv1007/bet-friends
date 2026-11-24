import 'package:flutter/material.dart';

import '../tema/tema.dart';

/// Linha estruturada de um desafio: quem, a partida e, opcionalmente, a
/// tabela "Palpite · Valor · Prêmio" e as ações.
class DesafioResumoItem extends StatelessWidget {
  /// Quem desafia ("Bruno Alves te desafiou", "Você x Bruno").
  final Widget titulo;

  /// À direita do título: tempo relativo, tag de status, link ou resultado.
  final Widget? lateral;

  /// "Internacional x Vitória".
  final String partida;

  /// Liga e horário em texto suave.
  final String? contexto;
  final TabelaDoDesafio? tabela;

  /// Ações no rodapé (Responder e Recusar).
  final Widget? rodape;

  /// Filete à esquerda para destacar pendências.
  final Color? destaque;
  final VoidCallback? onTap;
  final Key? itemKey;
  final Key? botaoKey;

  const DesafioResumoItem({
    super.key,
    required this.titulo,
    required this.partida,
    this.lateral,
    this.contexto,
    this.tabela,
    this.rodape,
    this.destaque,
    this.onTap,
    this.itemKey,
    this.botaoKey,
  });

  @override
  Widget build(BuildContext context) {
    Widget conteudo = Padding(
      padding: const EdgeInsets.fromLTRB(
        EspacosApp.e16, EspacosApp.e12, EspacosApp.e12, EspacosApp.e12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, restricoes) {
              // Estreito (320 dp ou texto ampliado): o lateral desce para não cortar o nome
              if (lateral != null && estreito(context, restricoes.maxWidth)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titulo, const SizedBox(height: EspacosApp.e4), lateral!],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titulo),
                  if (lateral != null) ...[
                    const SizedBox(width: EspacosApp.e8),
                    lateral!,
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: EspacosApp.e4),
          Text(
            partida,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextoApp.corpoForte.copyWith(color: CoresApp.texto),
          ),
          if (contexto != null)
            Text(
              contexto!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextoApp.secundario,
            ),
          if (tabela != null) ...[
            const SizedBox(height: EspacosApp.e12),
            tabela!,
          ],
          if (rodape != null) ...[
            const SizedBox(height: EspacosApp.e12),
            rodape!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      conteudo = InkWell(key: botaoKey, onTap: onTap, child: conteudo);
    }

    return Padding(
      key: itemKey,
      padding: const EdgeInsets.only(bottom: EspacosApp.e8),
      child: ClipRRect(
        borderRadius: RaiosApp.bordaCartao,
        child: Material(
          color: CoresApp.superficie1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: destaque == null
                  ? null
                  : Border(left: BorderSide(color: destaque!, width: 3)),
            ),
            child: conteudo,
          ),
        ),
      ),
    );
  }
}

/// Tabela de 3 colunas: palpite, valor apostado e prêmio (ganho líquido).
class TabelaDoDesafio extends StatelessWidget {
  final String rotuloDoPalpite;
  final String palpite;
  final int valor;

  const TabelaDoDesafio({
    super.key,
    required this.rotuloDoPalpite,
    required this.palpite,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    final rotulo = TextoApp.secundario;
    final forte = TextoApp.corpoForte.copyWith(color: CoresApp.texto);
    final numero = TextoApp.tabular(forte);
    final colunaDoPalpite = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotuloDoPalpite, maxLines: 1, overflow: TextOverflow.ellipsis, style: rotulo),
        Text(palpite, maxLines: 2, overflow: TextOverflow.ellipsis, style: forte),
      ],
    );
    final valorEPremio = [
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Valor', style: rotulo),
            Text('$valor', style: numero),
          ],
        ),
      ),
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Prêmio', style: rotulo),
            // Ganho líquido: quem acerta recebe o valor do rival (regra sem taxa).
            Text('+$valor', style: numero),
          ],
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, restricoes) {
        const espaco = EspacosApp.e8;
        final larguraDoPalpite = (restricoes.maxWidth - espaco) * 5 / 11;
        // Se o nome do time não cabe na coluna, o palpite ocupa uma linha própria
        // em vez de quebrar no meio da palavra.
        if (estreito(context, restricoes.maxWidth) ||
            _maiorPalavra(context, forte) > larguraDoPalpite) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              colunaDoPalpite,
              const SizedBox(height: EspacosApp.e8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: valorEPremio),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: colunaDoPalpite),
            const SizedBox(width: espaco),
            ...valorEPremio,
          ],
        );
      },
    );
  }

  double _maiorPalavra(BuildContext context, TextStyle estilo) {
    var maior = 0.0;
    for (final palavra in palpite.split(' ')) {
      final pintor = TextPainter(
        text: TextSpan(text: palavra, style: estilo),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (pintor.width > maior) maior = pintor.width;
      pintor.dispose();
    }
    return maior;
  }
}

/// Largura útil pequena para a escala de texto atual (320 dp com texto ampliado, por exemplo).
bool estreito(BuildContext context, double largura) =>
    largura / MediaQuery.textScalerOf(context).scale(1) < 250;

/// Disco em superfície 2 com as iniciais do jogador.
class DiscoDeIniciais extends StatelessWidget {
  final String nome;
  final double tamanho;

  const DiscoDeIniciais(this.nome, {super.key, this.tamanho = 32});

  static String iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final primeira = partes.first.characters.first;
    final ultima = partes.length > 1 ? partes.last.characters.first : '';
    return (primeira + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: tamanho,
        height: tamanho,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: CoresApp.superficie2, shape: BoxShape.circle),
        child: Text(
          iniciais(nome),
          style: TextoApp.minimo.copyWith(fontWeight: FontWeight.w700, color: CoresApp.texto),
        ),
      ),
    );
  }
}

/// Cabeçalho de grupo de desafios: título em caixa alta, complemento e ação opcional.
class CabecalhoDeDesafios extends StatelessWidget {
  final String titulo;
  final String? complemento;
  final Key? complementoKey;
  final Key? tituloKey;
  final Color corDoTitulo;
  final Color corDoComplemento;
  final Widget? acao;

  const CabecalhoDeDesafios(
    this.titulo, {
    super.key,
    this.complemento,
    this.complementoKey,
    this.tituloKey,
    this.corDoTitulo = CoresApp.textoSuave,
    this.corDoComplemento = CoresApp.textoSuave,
    this.acao,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(
              titulo.toUpperCase(),
              key: tituloKey,
              style: TextoApp.secao.copyWith(color: corDoTitulo),
            ),
          ),
          if (complemento != null) ...[
            const SizedBox(width: EspacosApp.e8),
            Expanded(
              child: Text(
                complemento!,
                key: complementoKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextoApp.minimo.copyWith(color: corDoComplemento),
              ),
            ),
          ] else
            const Spacer(),
          ?acao,
        ],
      ),
    );
  }
}

/// "há 12 min", "há 3 h", "há 2 dias"; recente demais vira "agora".
String tempoRelativo(DateTime instante, {DateTime? agora}) {
  final d = (agora ?? DateTime.now()).difference(instante);
  if (d.inMinutes < 1) return 'agora';
  if (d.inHours < 1) return 'há ${d.inMinutes} min';
  if (d.inDays < 1) return 'há ${d.inHours} h';
  return d.inDays == 1 ? 'há 1 dia' : 'há ${d.inDays} dias';
}
