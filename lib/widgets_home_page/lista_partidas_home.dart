import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/tema/tema.dart';
import 'package:betfriends/widgets/componentes.dart';
import 'package:betfriends/widgets_home_page/card_de_partidas.dart';
import 'package:flutter/material.dart';

/// Estados de carregamento e lista de partidas exibidos na Home.
///
/// As partidas formam um grupo único em superfície 1, com filetes entre as
/// linhas. Sem [mostrarTodas] aparecem as 3 primeiras; o controle que alterna
/// é o "Ver todas" do cabeçalho da seção (`Appbardaspartidas`).
class ListaPartidasHome extends StatelessWidget {
  final List<PartidaModel> partidas;
  final bool isLoading;
  final String? errorMessage;
  final bool hasRefreshError;
  final String? refreshErrorMessage;
  final bool mostrarTodas;
  final VoidCallback onRecarregar;

  /// Alterna `mostrarTodas` na Home. A lista não tem controle próprio (o
  /// "Ver todas" do cabeçalho faz o mesmo); fica no construtor, que a Home usa.
  final VoidCallback onAlternarPartidas;

  const ListaPartidasHome({
    super.key,
    required this.partidas,
    required this.isLoading,
    required this.errorMessage,
    required this.hasRefreshError,
    required this.refreshErrorMessage,
    required this.mostrarTodas,
    required this.onRecarregar,
    required this.onAlternarPartidas,
  });

  /// Partidas visíveis sem "Ver todas".
  static const int partidasIniciais = 3;

  @override
  Widget build(BuildContext context) {
    // 1. Carregando
    if (isLoading && partidas.isEmpty) {
      return const _Grupo(
        child: Padding(
          padding: EdgeInsets.all(EspacosApp.e32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 2. Erro
    if (errorMessage != null && partidas.isEmpty) {
      return _EstadoDaLista(
        icone: Icons.error_outline,
        corDoIcone: CoresApp.destrutivo,
        titulo: 'Erro ao carregar partidas',
        mensagem: errorMessage!,
        acao: BotaoSecundario(
          rotulo: 'Tentar novamente',
          icone: Icons.refresh,
          pequeno: true,
          onPressed: onRecarregar,
        ),
      );
    }

    // 3. Vazio
    if (partidas.isEmpty) {
      return _EstadoDaLista(
        icone: Icons.sports_soccer,
        corDoIcone: CoresApp.textoSuave,
        titulo: 'Nenhuma partida disponível',
        mensagem: 'Não encontramos partidas disponíveis no momento.',
        acao: BotaoSecundario(
          rotulo: 'Atualizar',
          icone: Icons.refresh,
          pequeno: true,
          onPressed: onRecarregar,
        ),
      );
    }

    // 4. Partidas
    final exibidas = mostrarTodas
        ? partidas
        : partidas.take(partidasIniciais).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasRefreshError) ...[
          AvisoInline(
            refreshErrorMessage ?? 'Falha ao atualizar dados mais recentes.',
            Tom.atencao,
            acao: BotaoTexto(
              rotulo: 'Recarregar',
              pequeno: true,
              onPressed: onRecarregar,
            ),
          ),
          const SizedBox(height: EspacosApp.e12),
        ],
        _Grupo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < exibidas.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: EspacosApp.e16,
                    endIndent: EspacosApp.e16,
                  ),
                Carddepartidas(partida: exibidas[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Superfície 1 com raio de cartão; recorta o realce do toque das linhas.
class _Grupo extends StatelessWidget {
  final Widget child;

  const _Grupo({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CoresApp.superficie1,
      borderRadius: RaiosApp.bordaCartao,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _EstadoDaLista extends StatelessWidget {
  final IconData icone;
  final Color corDoIcone;
  final String titulo;
  final String mensagem;
  final Widget acao;

  const _EstadoDaLista({
    required this.icone,
    required this.corDoIcone,
    required this.titulo,
    required this.mensagem,
    required this.acao,
  });

  @override
  Widget build(BuildContext context) {
    return _Grupo(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: EspacosApp.e20,
          vertical: EspacosApp.e24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: corDoIcone, size: 32),
            const SizedBox(height: EspacosApp.e12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextoApp.corpoForte.copyWith(color: CoresApp.texto),
            ),
            const SizedBox(height: EspacosApp.e4),
            Text(mensagem, textAlign: TextAlign.center, style: TextoApp.secundario),
            const SizedBox(height: EspacosApp.e16),
            acao,
          ],
        ),
      ),
    );
  }
}
