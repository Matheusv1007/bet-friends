import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/widgets_home_page/card_de_partidas.dart';
import 'package:flutter/material.dart';

/// Estados de carregamento e lista de partidas exibidos na Home.
class ListaPartidasHome extends StatelessWidget {
  final List<PartidaModel> partidas;
  final bool isLoading;
  final String? errorMessage;
  final bool hasRefreshError;
  final String? refreshErrorMessage;
  final bool mostrarTodas;
  final VoidCallback onRecarregar;
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

  @override
  Widget build(BuildContext context) {
    // 1. Estado de carregando
    if (isLoading &&
        partidas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            color: Color(0xFF00D084),
          ),
        ),
      );
    }

    // 2. Estado de erro
    if (errorMessage != null &&
        partidas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF151E2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFEF4444),
              size: 36,
            ),
            const SizedBox(height: 10),
            const Text(
              "Erro ao carregar partidas",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8E9CAB),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRecarregar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text(
                "TENTAR NOVAMENTE",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D084),
                foregroundColor: const Color(0xFF062319),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Estado vazio (nenhuma partida encontrada)
    if (partidas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF151E2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sports_soccer,
              color: Color(0xFF94A3B8),
              size: 36,
            ),
            const SizedBox(height: 10),
            const Text(
              "Nenhuma partida disponível",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Não encontramos partidas disponíveis no momento.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8E9CAB),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRecarregar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text(
                "ATUALIZAR",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D084),
                foregroundColor: const Color(0xFF062319),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 4. Partidas carregadas com sucesso
    final baseList = partidas;
    final listaParaExibir = mostrarTodas
        ? baseList
        : baseList.take(3).toList();

    return Column(
      children: [
        if (hasRefreshError) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1C14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF59E0B)
                    .withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sync_problem,
                  color: Color(0xFFF59E0B),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    refreshErrorMessage ??
                        "Falha ao atualizar dados mais recentes.",
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onRecarregar,
                  child: const Text(
                    "Recarregar",
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ...listaParaExibir.map((partida) {
          return Carddepartidas(partida: partida);
        }),
        if (baseList.length > 3) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onAlternarPartidas,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D084),
                foregroundColor: const Color(0xFF062319),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                mostrarTodas
                    ? "MOSTRAR MENOS"
                    : "MAIS PARTIDAS",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
