import 'package:flutter/material.dart';

import '../models/partida_model.dart';

class SeletorPartidaDesafio extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<PartidaModel> partidas;
  final List<PartidaModel> elegiveis;
  final String? partidaId;
  final VoidCallback onRecarregar;
  final ValueChanged<String> onChanged;

  const SeletorPartidaDesafio({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.partidas,
    required this.elegiveis,
    required this.partidaId,
    required this.onRecarregar,
    required this.onChanged,
  });

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
            const Icon(Icons.sports_soccer, size: 32, color: Color(0xFF64748B)),
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

    final partidaAtivaId = partidaId ?? elegiveis.first.id;

    return Column(
      children: elegiveis.map((PartidaModel p) {
        final sel = partidaAtivaId == p.id;
        final horarioOuStatus = p.horario ?? p.status;

        return GestureDetector(
          onTap: () => onChanged(p.id),
          child: Container(
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
            child: Row(
              children: [
                Icon(
                  Icons.sports_soccer,
                  size: 20,
                  color: sel ? primaryGreen : const Color(0xFF64748B),
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
                Icon(
                  Icons.sports_soccer,
                  size: 20,
                  color: sel ? primaryGreen : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
