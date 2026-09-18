import 'package:flutter/material.dart';
import '../models/partida_model.dart';

class Carddepartidas extends StatelessWidget {
  final PartidaModel? partida;

  const Carddepartidas({super.key, this.partida});

  Widget _buildTeamLogo(String? url) {
    if (url != null && url.toLowerCase().endsWith('.png')) {
      return Image.network(
        url,
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.sports_soccer, size: 32),
      );
    }
    return const Icon(Icons.sports_soccer, size: 32);
  }

  Color _getStatusColor(String status) {
    if (status == 'AO VIVO') return Colors.red;
    if (status == 'FINALIZADO') return Colors.grey.shade700;
    return Colors.blue.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final mandante = partida?.timeMandante ?? "Flamengo";
    final visitante = partida?.timeVisitante ?? "Vasco";
    final status = partida?.status ?? "FINALIZADO";
    final placar = partida?.placarTexto ?? "2 - 0";
    final campeonato = partida?.campeonato;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Column(
          children: [
            if (campeonato != null) ...[
              Text(
                campeonato.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                // Time Mandante
                Expanded(
                  child: Column(
                    children: [
                      _buildTeamLogo(partida?.logoMandante),
                      const SizedBox(height: 6),
                      Text(
                        mandante,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Placar e Status Central
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        placar,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Time Visitante
                Expanded(
                  child: Column(
                    children: [
                      _buildTeamLogo(partida?.logoVisitante),
                      const SizedBox(height: 6),
                      Text(
                        visitante,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
