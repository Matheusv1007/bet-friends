import 'package:flutter/material.dart';

class DesafioResumoItem extends StatelessWidget {
  final String jogador1;
  final String jogador2;
  final VoidCallback onTap;
  final String? subtitulo;
  final String? statusLabel;
  final Color? statusColor;
  final String? botaoLabel;
  final Key? itemKey;
  final Key? botaoKey;

  const DesafioResumoItem({super.key, required this.jogador1, required this.jogador2, required this.onTap, this.subtitulo, this.statusLabel, this.statusColor, this.botaoLabel, this.itemKey, this.botaoKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: itemKey,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatares sobrepostos dos dois jogadores
          SizedBox(
            width: 48,
            height: 32,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF151E2E),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(0xFF334155),
                      child: Icon(Icons.person, size: 18, color: Colors.white70),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF151E2E),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(0xFF475569),
                      child: Icon(Icons.person, size: 18, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Nomes e subtítulo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$jogador1 x $jogador2",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo!,
                    style: const TextStyle(
                      color: Color(0xFF8E9CAB),
                      fontSize: 11.5,
                    ),
                  ),
                ],
                if (statusLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    statusLabel!,
                    style: TextStyle(
                      color: statusColor ?? const Color(0xFF00D084),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Botão de ação
          GestureDetector(
            key: botaoKey,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2425),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (statusColor ?? const Color(0xFF00D084)).withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Text(
                botaoLabel ?? "Detalhes do Desafio",
                style: TextStyle(
                  color: statusColor ?? const Color(0xFF00D084),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

