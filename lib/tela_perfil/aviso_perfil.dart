import 'package:flutter/material.dart';

class AvisoPerfil extends StatelessWidget {
  final IconData icone;
  final Color corIcone;
  final String titulo;
  final String mensagem;
  final VoidCallback? onTentarNovamente;
  final String rotuloDaAcao;
  final IconData iconeDaAcao;

  const AvisoPerfil({
    super.key,
    required this.icone,
    required this.corIcone,
    required this.titulo,
    required this.mensagem,
    this.onTentarNovamente,
    this.rotuloDaAcao = 'TENTAR NOVAMENTE',
    this.iconeDaAcao = Icons.refresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF151E2E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, color: corIcone, size: 36),
              const SizedBox(height: 10),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8E9CAB), fontSize: 12),
              ),
              if (onTentarNovamente != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onTentarNovamente,
                  icon: Icon(iconeDaAcao, size: 16),
                  label: Text(
                    rotuloDaAcao,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D084),
                    foregroundColor: const Color(0xFF062319),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
