import 'package:flutter/material.dart';

import '../tema/tema.dart';
import '../widgets/componentes.dart';

/// Estado da tela de Perfil sem dados (erro ou perfil ainda não criado).
class AvisoPerfil extends StatelessWidget {
  final Tom tom;
  final String titulo;
  final String mensagem;
  final VoidCallback? onTentarNovamente;
  final String rotuloDaAcao;
  final IconData iconeDaAcao;

  const AvisoPerfil({
    super.key,
    required this.tom,
    required this.titulo,
    required this.mensagem,
    this.onTentarNovamente,
    this.rotuloDaAcao = 'Tentar novamente',
    this.iconeDaAcao = Icons.refresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(EspacosApp.margemDaTela),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextoApp.tituloDeBarra.copyWith(color: CoresApp.texto),
            ),
            const SizedBox(height: EspacosApp.e12),
            AvisoInline(mensagem, tom),
            if (onTentarNovamente != null) ...[
              const SizedBox(height: EspacosApp.e16),
              BotaoPrimario(
                rotulo: rotuloDaAcao,
                icone: iconeDaAcao,
                onPressed: onTentarNovamente,
                larguraTotal: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
