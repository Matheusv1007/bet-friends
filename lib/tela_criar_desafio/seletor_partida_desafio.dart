import 'package:flutter/material.dart';

import '../models/campeonato.dart';
import '../models/partida_model.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import '../widgets/texto_sem_corte.dart';
import '../widgets_home_page/escudo_do_time.dart';

/// Seções "Campeonato" (chips de filtro) e "Partida" (lista de rádios) de
/// Criar Desafio.
class SeletorPartidaDesafio extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<PartidaModel> partidas;
  final List<PartidaModel> elegiveis;
  final String? partidaId;
  final VoidCallback onRecarregar;
  final ValueChanged<String> onChanged;
  final bool mostrarTodas;
  final VoidCallback onAlternarMostrarTodas;

  /// Campeonato escolhido no filtro; `null` é "Todos". Afeta só a exibição.
  final Campeonato? filtro;
  final ValueChanged<Campeonato?> onFiltroChanged;

  /// Ação à direita do título "Partida" (o "Atualizar" da tela).
  final Widget? acaoDoTitulo;

  const SeletorPartidaDesafio({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.partidas,
    required this.elegiveis,
    required this.partidaId,
    required this.onRecarregar,
    required this.onChanged,
    required this.mostrarTodas,
    required this.onAlternarMostrarTodas,
    required this.filtro,
    required this.onFiltroChanged,
    this.acaoDoTitulo,
  });

  /// Quantas partidas o seletor lista antes de "Mostrar mais".
  static const int maxPartidas = 5;

  /// Rótulo do chip "Todos" do filtro por campeonato.
  static const String rotuloFiltroTodos = 'Todos';

  /// Rótulo curto do campeonato no filtro (o nome completo fica nos cards).
  static String rotuloDoFiltro(Campeonato campeonato) =>
      campeonato == Campeonato.brasileirao ? 'Brasileirão' : campeonato.nome;

  /// Se a [partida] pertence ao [campeonato]. Partida sem código é do
  /// Brasileirão, como nos documentos antigos.
  static bool pertenceAoCampeonato(
    PartidaModel partida,
    Campeonato campeonato,
  ) =>
      Campeonato.deCodigo(
        partida.competitionCode ?? Campeonato.brasileirao.codigo,
      ) ==
      campeonato;

  /// Elegíveis do [filtro] (todas, se `null`).
  static List<PartidaModel> filtradas(
    List<PartidaModel> elegiveis,
    Campeonato? filtro,
  ) => filtro == null
      ? elegiveis
      : [
          for (final p in elegiveis)
            if (pertenceAoCampeonato(p, filtro)) p,
        ];

  /// As [maxPartidas] primeiras partidas elegíveis do [filtro], ou todas com
  /// [mostrarTodas]. A partida já selecionada continua visível mesmo fora
  /// delas e fora do filtro (ex.: o desafio aberto pelos detalhes de uma
  /// partida de outra liga ou mais adiante), para a escolha não sumir da tela.
  static List<PartidaModel> exibidas(
    List<PartidaModel> elegiveis,
    String? selecionadaId,
    bool mostrarTodas, {
    Campeonato? filtro,
  }) {
    final noFiltro = filtradas(elegiveis, filtro).map((p) => p.id).toList();
    return [
      for (final p in elegiveis)
        if (p.id == selecionadaId ||
            (noFiltro.contains(p.id) &&
                (mostrarTodas || noFiltro.indexOf(p.id) < maxPartidas)))
          p,
    ];
  }

  Widget _tituloDaPartida() => Padding(
        padding: const EdgeInsets.only(bottom: EspacosApp.e8),
        child: TituloDeSecao('Partida', acao: acaoDoTitulo),
      );

  @override
  Widget build(BuildContext context) {
    if (isLoading && partidas.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloDaPartida(),
          const _Grupo(
            child: Padding(
              padding: EdgeInsets.all(EspacosApp.e32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      );
    }

    if (errorMessage != null && partidas.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloDaPartida(),
          _Estado(
            icone: Icons.wifi_off_rounded,
            corDoIcone: CoresApp.destrutivo,
            titulo: 'Erro ao carregar partidas',
            mensagem: errorMessage!,
            acao: BotaoSecundario(
              rotulo: 'Tentar novamente',
              icone: Icons.refresh,
              pequeno: true,
              onPressed: onRecarregar,
            ),
          ),
        ],
      );
    }

    if (partidas.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloDaPartida(),
          _Estado(
            icone: Icons.sports_soccer,
            corDoIcone: CoresApp.textoSuave,
            mensagem: 'Nenhuma partida encontrada no momento',
            acao: BotaoSecundario(
              rotulo: 'Carregar partidas',
              icone: Icons.refresh,
              pequeno: true,
              onPressed: onRecarregar,
            ),
          ),
        ],
      );
    }

    if (elegiveis.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloDaPartida(),
          const _Estado(
            icone: Icons.event_busy_outlined,
            corDoIcone: CoresApp.textoSuave,
            mensagem: 'Nenhuma partida agendada disponível para apostas no momento.',
          ),
        ],
      );
    }

    final doFiltro = filtradas(elegiveis, filtro);
    final visiveis = exibidas(
      elegiveis,
      partidaId,
      mostrarTodas,
      filtro: filtro,
    );
    final idsDoFiltro = {for (final p in doFiltro) p.id};
    final ocultas =
        doFiltro.length -
        visiveis.where((p) => idsDoFiltro.contains(p.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloDeSecao('Campeonato'),
        const SizedBox(height: EspacosApp.e8),
        _FiltroCampeonatos(filtro: filtro, onChanged: onFiltroChanged),
        const SizedBox(height: EspacosApp.e16),
        _tituloDaPartida(),
        if (doFiltro.isEmpty) ...[
          _Estado(
            icone: Icons.event_busy_outlined,
            corDoIcone: CoresApp.textoSuave,
            mensagem:
                'Nenhuma partida agendada disponível em ${filtro!.nome} no momento.',
            chaveDaMensagem: const Key('filtro_campeonato_vazio'),
          ),
          if (visiveis.isNotEmpty) const SizedBox(height: EspacosApp.e8),
        ],
        if (visiveis.isNotEmpty)
          _Grupo(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visiveis.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _LinhaDaPartida(
                    partida: visiveis[i],
                    selecionada: visiveis[i].id == partidaId,
                    onTap: () => onChanged(visiveis[i].id),
                  ),
                ],
              ],
            ),
          ),
        if (ocultas > 0 || (mostrarTodas && doFiltro.length > maxPartidas))
          Align(
            child: BotaoTexto(
              key: const Key('btn_mostrar_mais_partidas'),
              rotulo: mostrarTodas ? 'Mostrar menos' : 'Mostrar mais ($ocultas)',
              icone: mostrarTodas ? Icons.expand_less : Icons.expand_more,
              pequeno: true,
              onPressed: onAlternarMostrarTodas,
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

class _Estado extends StatelessWidget {
  final IconData icone;
  final Color corDoIcone;
  final String? titulo;
  final String mensagem;
  final Key? chaveDaMensagem;
  final Widget? acao;

  const _Estado({
    required this.icone,
    required this.corDoIcone,
    required this.mensagem,
    this.titulo,
    this.chaveDaMensagem,
    this.acao,
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
            Icon(icone, size: 32, color: corDoIcone),
            const SizedBox(height: EspacosApp.e12),
            if (titulo != null) ...[
              Text(
                titulo!,
                textAlign: TextAlign.center,
                style: TextoApp.corpoForte.copyWith(color: CoresApp.texto),
              ),
              const SizedBox(height: EspacosApp.e4),
            ],
            Text(
              mensagem,
              key: chaveDaMensagem,
              textAlign: TextAlign.center,
              style: TextoApp.secundario,
            ),
            if (acao != null) ...[
              const SizedBox(height: EspacosApp.e16),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Linha de rádio: liga e rodada, mandante e visitante (disco e nome em até
/// 2 linhas) e o horário à direita.
class _LinhaDaPartida extends StatelessWidget {
  final PartidaModel partida;
  final bool selecionada;
  final VoidCallback onTap;

  const _LinhaDaPartida({
    required this.partida,
    required this.selecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = partida;
    final rodada = p.matchday;
    final horario = (p.horario ?? p.status).trim();
    final corte = horario.lastIndexOf(' ');
    final dia = corte > 0 ? horario.substring(0, corte) : horario;
    final hora = corte > 0 ? horario.substring(corte + 1) : null;

    return Semantics(
      selected: selecionada,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selecionada ? CoresApp.superficie2 : CoresApp.superficie1,
        child: InkWell(
          key: Key('partida_desafio_${p.id}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: EspacosApp.alvoDeToque),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EspacosApp.e16,
                vertical: EspacosApp.e12,
              ),
              child: Row(
                children: [
                  Icon(
                    selecionada
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: selecionada ? CoresApp.primario : CoresApp.textoSuave,
                  ),
                  const SizedBox(width: EspacosApp.e12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: EspacosApp.e4,
                          children: [
                            Text(
                              p.nomeDoCampeonato,
                              key: Key('partida_desafio_campeonato_${p.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextoApp.secundario,
                            ),
                            if (rodada != null)
                              Text('· Rodada $rodada', style: TextoApp.secundario),
                          ],
                        ),
                        const SizedBox(height: EspacosApp.e4),
                        _Time(nome: p.timeMandante, escudo: p.logoMandante),
                        const SizedBox(height: EspacosApp.e4),
                        _Time(nome: p.timeVisitante, escudo: p.logoVisitante),
                      ],
                    ),
                  ),
                  const SizedBox(width: EspacosApp.e12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        dia,
                        style: TextoApp.secundario.copyWith(
                          fontWeight: FontWeight.w600,
                          color: CoresApp.texto,
                        ),
                      ),
                      if (hora != null) Text(hora, style: TextoApp.secundario),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Time extends StatelessWidget {
  final String nome;
  final String? escudo;

  const _Time({required this.nome, required this.escudo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        EscudoDoTime(url: escudo, nome: nome, tamanho: 22),
        const SizedBox(width: EspacosApp.e8),
        Expanded(
          child: TextoSemCorte(
            nome,
            estilo: TextoApp.corpoForte.copyWith(color: CoresApp.texto, height: 1.25),
          ),
        ),
      ],
    );
  }
}

/// Faixa rolável de chips para filtrar a lista por campeonato.
class _FiltroCampeonatos extends StatelessWidget {
  final Campeonato? filtro;
  final ValueChanged<Campeonato?> onChanged;

  const _FiltroCampeonatos({required this.filtro, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            key: const Key('filtro_campeonato_todos'),
            rotulo: SeletorPartidaDesafio.rotuloFiltroTodos,
            selecionado: filtro == null,
            onTap: () => onChanged(null),
          ),
          for (final c in Campeonato.suportados)
            _chip(
              key: Key('filtro_campeonato_${c.codigo}'),
              rotulo: SeletorPartidaDesafio.rotuloDoFiltro(c),
              selecionado: filtro == c,
              onTap: () => onChanged(c),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required Key key,
    required String rotulo,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: EspacosApp.e8),
      child: Semantics(
        button: true,
        selected: selecionado,
        child: Material(
          color: selecionado ? CoresApp.primarioSuave : CoresApp.superficie1,
          shape: RoundedRectangleBorder(
            borderRadius: RaiosApp.bordaChip,
            side: BorderSide(
              color: selecionado ? CoresApp.primario : CoresApp.filete,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: key,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: EspacosApp.e16),
              child: Text(
                rotulo,
                style: TextoApp.corpo.copyWith(
                  fontWeight: FontWeight.w500,
                  color: selecionado ? CoresApp.texto : CoresApp.textoSuave,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
