import 'package:flutter/material.dart';
import '../models/partida_model.dart';

class Carddepartidas extends StatelessWidget {
  final PartidaModel? partida;

  const Carddepartidas({super.key, this.partida});

  Widget _buildTeamLogo(String? url, {required String fallbackName}) {
    if (url != null && url.toLowerCase().endsWith('.png')) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            _buildShieldIcon(fallbackName),
      );
    }
    return _buildShieldIcon(fallbackName);
  }

  Widget _buildShieldIcon(String name) {
    // Escudo estilizado preto/vermelho/branco para os times
    Color shieldColor = Colors.black87;
    if (name.toLowerCase().contains('fla')) {
      shieldColor = const Color(0xFFC00000);
    } else if (name.toLowerCase().contains('flu')) {
      shieldColor = const Color(0xFF800020);
    } else if (name.toLowerCase().contains('volta')) {
      shieldColor = const Color(0xFFE5A800);
    }

    return Icon(
      Icons.shield,
      color: shieldColor,
      size: 30,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mandante = partida?.timeMandante ?? "Flamengo";
    final visitante = partida?.timeVisitante ?? "Vasco";
    final isFinalizado = partida?.isFinalizado ?? true;
    final isAoVivo = partida?.isAoVivo ?? false;
    final placar = partida?.placarTexto ?? (isFinalizado ? "2 - 0" : "1 - 1");
    final minuto = partida?.minuto ?? "65:12";
    final horario = partida?.horario ?? "Amanhã 19:00";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151E2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Time Mandante
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Center(
                    child: _buildTeamLogo(
                      partida?.logoMandante,
                      fallbackName: mandante,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mandante,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Centro: Placar e Status
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFinalizado) ...[
                  // BADGE FINALIZADO
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2825),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF0F433B),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      "FINALIZADO",
                      style: TextStyle(
                        color: Color(0xFF00D084),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    placar,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ] else if (isAoVivo) ...[
                  // BADGE EM ANDAMENTO
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2210),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF543D16),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      "EM ANDAMENTO",
                      style: TextStyle(
                        color: Color(0xFFFFA726),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    placar,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    minuto,
                    style: const TextStyle(
                      color: Color(0xFFFFA726),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Barra de progresso laranja
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3649),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 52,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA726),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // BADGE PRÓXIMO JOGO
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF334155),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      "PRÓXIMO JOGO",
                      style: TextStyle(
                        color: Color(0xFF8A9BB5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    horario,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Color(0xFF8A9BB5),
                  ),
                ],
              ],
            ),
          ),

          // Time Visitante
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Center(
                    child: _buildTeamLogo(
                      partida?.logoVisitante,
                      fallbackName: visitante,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  visitante,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
