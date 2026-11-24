import 'package:flutter/material.dart';

import '../widgets/componentes.dart';

/// Único aviso de desafios recebidos aguardando resposta; "Responder" leva à seção Recebidos.
class AlertaDesafiosPendentesHome extends StatelessWidget {
  final int quantidade;
  final VoidCallback onResponder;

  const AlertaDesafiosPendentesHome({
    super.key,
    required this.quantidade,
    required this.onResponder,
  });

  @override
  Widget build(BuildContext context) {
    return AvisoInline(
      quantidade == 1 ? '1 desafio aguardando você' : '$quantidade desafios aguardando você',
      Tom.atencao,
      key: const Key('home_alerta_desafios_pendentes'),
      acao: BotaoTexto(
        key: const Key('home_alerta_responder'),
        rotulo: 'Responder',
        pequeno: true,
        onPressed: onResponder,
      ),
    );
  }
}
