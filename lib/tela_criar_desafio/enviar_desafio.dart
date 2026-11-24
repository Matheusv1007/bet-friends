import 'package:flutter/material.dart';

import '../tema/tema.dart';
import '../widgets/componentes.dart';

/// Rodapé fixo de Criar Desafio com o botão "Enviar desafio".
class EnviarDesafio extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onPressed;

  const EnviarDesafio({
    super.key,
    required this.isSubmitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: CoresApp.fundo,
        border: Border(top: BorderSide(color: CoresApp.filete)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(EspacosApp.margemDaTela),
          child: BotaoPrimario(
            key: const Key('btn_enviar_desafio'),
            rotulo: 'Enviar desafio',
            carregando: isSubmitting,
            larguraTotal: true,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
