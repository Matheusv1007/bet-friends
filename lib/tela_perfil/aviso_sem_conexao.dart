import 'package:flutter/material.dart';

class AvisoSemConexao extends StatelessWidget {
  const AvisoSemConexao({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('perfil_sem_conexao'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: Color(0xFFF59E0B), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sem conexão. Exibindo os últimos dados salvos neste aparelho; '
              'alterações ficam indisponíveis até a conexão voltar.',
              style: TextStyle(color: Color(0xFFF5D08A), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
