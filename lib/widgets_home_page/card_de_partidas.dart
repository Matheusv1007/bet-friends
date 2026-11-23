import 'package:flutter/material.dart';
import '../models/partida_model.dart';
import 'detalhes_da_partida_dialog.dart';
import 'escudo_do_time.dart';

class Carddepartidas extends StatelessWidget {
  final PartidaModel? partida;
  final VoidCallback? onTap;

  const Carddepartidas({super.key, this.partida, this.onTap});

  @override
  Widget build(BuildContext context) {
    final mandante = partida?.timeMandante ?? "Mandante";
    final visitante = partida?.timeVisitante ?? "Visitante";
    final isFinalizado = partida?.isFinalizado ?? false;
    final isAoVivo = partida?.isAoVivo ?? false;
    final isAdiado = partida?.isAdiado ?? false;
    final isCancelado = partida?.isCancelado ?? false;
    final placar = partida?.placarTexto ?? "0 - 0";
    final minuto = partida?.minuto;
    final horario = partida?.horario ?? "A definir";

    final cardContent = Container(
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
                EscudoDoTime(url: partida?.logoMandante, nome: mandante),
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
                    (minuto != null && minuto.isNotEmpty) ? minuto : "Ao vivo",
                    style: const TextStyle(
                      color: Color(0xFFFFA726),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                ] else if (isAdiado) ...[
                  // BADGE ADIADO
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A1C14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      "ADIADO",
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
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
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else if (isCancelado) ...[
                  // BADGE CANCELADO
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B1414),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      "CANCELADO",
                      style: TextStyle(
                        color: Color(0xFFEF4444),
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
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
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
                EscudoDoTime(url: partida?.logoVisitante, nome: visitante),
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

    return InkWell(
      key: Key('card_partida_${partida?.id ?? "desconhecida"}'),
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else if (partida != null) {
          DetalhesDaPartidaDialog.exibir(context, partida!);
        }
      },
      child: cardContent,
    );
  }
}
