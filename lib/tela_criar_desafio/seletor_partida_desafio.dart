import 'package:flutter/material.dart';

import '../models/campeonato.dart';
import '../models/partida_model.dart';
import '../widgets_home_page/escudo_do_time.dart';

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

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);

    if (isLoading && partidas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(color: primaryGreen),
        ),
      );
    }

    if (errorMessage != null && partidas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 12),
            const Text(
              'Erro ao carregar partidas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRecarregar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: const Color(0xFF062319),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (partidas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.sports_soccer, size: 32, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            const Text(
              'Nenhuma partida encontrada no momento',
              style: TextStyle(color: textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRecarregar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Carregar partidas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: const Color(0xFF062319),
              ),
            ),
          ],
        ),
      );
    }

    if (elegiveis.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Nenhuma partida agendada disponível para apostas no momento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final partidaAtivaId = partidaId;

    final doFiltro = filtradas(elegiveis, filtro);
    final visiveis = exibidas(
      elegiveis,
      partidaAtivaId,
      mostrarTodas,
      filtro: filtro,
    );
    final idsDoFiltro = {for (final p in doFiltro) p.id};
    final ocultas =
        doFiltro.length -
        visiveis.where((p) => idsDoFiltro.contains(p.id)).length;

    return Column(
      children: [
        _FiltroCampeonatos(filtro: filtro, onChanged: onFiltroChanged),
        if (doFiltro.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Nenhuma partida agendada disponível em ${filtro!.nome} no momento.',
              key: const Key('filtro_campeonato_vazio'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: textMuted, fontSize: 13),
            ),
          ),
        ...visiveis.map((PartidaModel p) {
          final sel = partidaAtivaId == p.id;
          final horarioOuStatus = p.horario ?? p.status;

          return InkWell(
            key: Key('partida_desafio_${p.id}'),
            onTap: () => onChanged(p.id),
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF0E2924) : cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel
                      ? primaryGreen
                      : Colors.white.withValues(alpha: 0.05),
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nomeDoCampeonato,
                    key: Key('partida_desafio_campeonato_${p.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      EscudoDoTime(
                        url: p.logoMandante,
                        nome: p.timeMandante,
                        tamanho: 32,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.timeMandante,
                          style: TextStyle(
                            color: sel ? primaryGreen : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'x',
                            style: TextStyle(
                              color: sel ? primaryGreen : textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            horarioOuStatus,
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Text(
                          p.timeVisitante,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: sel ? primaryGreen : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      EscudoDoTime(
                        url: p.logoVisitante,
                        nome: p.timeVisitante,
                        tamanho: 32,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (ocultas > 0 || (mostrarTodas && doFiltro.length > maxPartidas))
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              key: const Key('btn_mostrar_mais_partidas'),
              style: TextButton.styleFrom(
                foregroundColor: primaryGreen,
                minimumSize: const Size(48, 48),
              ),
              onPressed: onAlternarMostrarTodas,
              icon: Icon(
                mostrarTodas ? Icons.expand_less : Icons.expand_more,
                size: 20,
              ),
              label: Text(
                mostrarTodas ? 'Mostrar menos' : 'Mostrar mais ($ocultas)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
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
      ),
    );
  }

  Widget _chip({
    required Key key,
    required String rotulo,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    const primaryGreen = Color(0xFF00D084);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selecionado
                ? const Color(0xFF0E2924)
                : const Color(0xFF151E2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selecionado
                  ? primaryGreen
                  : Colors.white.withValues(alpha: 0.05),
              width: selecionado ? 1.5 : 1,
            ),
          ),
          child: Text(
            rotulo,
            style: TextStyle(
              color: selecionado ? primaryGreen : const Color(0xFF8E9CAB),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
