import 'package:flutter/material.dart';

import '../tema/tema.dart';
import '../widgets/componentes.dart';

/// Cabeçalho da seção de partidas da Home: "PARTIDAS", "atualizado às HH:MM"
/// e o link que alterna entre as primeiras partidas e todas.
///
/// O link é o único controle da lista: cada toque chama [onVerTodasPressed]
/// (que alterna `mostrarTodas` na Home) e troca o rótulo entre "Ver todas"
/// e "Ver menos".
class Appbardaspartidas extends StatefulWidget {
  final VoidCallback? onVerTodasPressed;

  /// A lista se atualiza sozinha: o horário é anunciado aos leitores de tela
  /// quando muda.
  final bool isLive;
  final String? ultimaAtualizacao;

  const Appbardaspartidas({
    super.key,
    this.onVerTodasPressed,
    this.isLive = true,
    this.ultimaAtualizacao,
  });

  @override
  State<Appbardaspartidas> createState() => _AppbardaspartidasState();
}

class _AppbardaspartidasState extends State<Appbardaspartidas> {
  bool _mostrandoTodas = false;

  @override
  Widget build(BuildContext context) {
    final atualizacao = widget.ultimaAtualizacao?.trim();
    return Wrap(
      spacing: EspacosApp.e12,
      runSpacing: EspacosApp.e4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          header: true,
          child: const Text('PARTIDAS', style: TextoApp.secao),
        ),
        if (atualizacao != null && atualizacao.isNotEmpty)
          Semantics(
            liveRegion: widget.isLive,
            child: Text(
              atualizacao[0].toLowerCase() + atualizacao.substring(1),
              style: TextoApp.secundario,
            ),
          ),
        BotaoTexto(
          key: const Key('btn_ver_todas_partidas'),
          rotulo: _mostrandoTodas ? 'Ver menos' : 'Ver todas',
          pequeno: true,
          onPressed: () {
            setState(() => _mostrandoTodas = !_mostrandoTodas);
            widget.onVerTodasPressed?.call();
          },
        ),
      ],
    );
  }
}
