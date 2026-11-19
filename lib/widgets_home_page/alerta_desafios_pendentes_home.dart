import 'package:flutter/material.dart';

/// Destaque dos desafios recebidos que aguardam resposta.
class AlertaDesafiosPendentesHome extends StatelessWidget {
  final int quantidade;

  const AlertaDesafiosPendentesHome({
    super.key,
    required this.quantidade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home_alerta_desafios_pendentes'),
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2213),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            color: Color(0xFFF59E0B),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Você tem $quantidade desafio(s) aguardando sua resposta!",
              style: const TextStyle(
                color: Color(0xFFFDE68A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
