import 'package:flutter/material.dart';

import '../tema/cores_app.dart';
import '../tema/espacos_app.dart';
import '../tema/raios_app.dart';
import '../tema/texto_app.dart';
import '../tema/tom.dart';

/// Faixa fina na própria tela para pendências e erros, com ação opcional.
class AvisoInline extends StatelessWidget {
  const AvisoInline(this.texto, this.tom, {super.key, this.acao});

  final String texto;
  final Tom tom;

  /// Normalmente um `BotaoTexto(pequeno: true)`, como "Responder".
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tom.fundo,
        borderRadius: RaiosApp.bordaBotao,
        border: Border.all(
          color: tom == Tom.neutro ? CoresApp.contorno : tom.cor.withValues(alpha: 0.6),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: EspacosApp.alvoDeToque),
        child: Padding(
          padding: EdgeInsets.only(
            left: EspacosApp.e12,
            right: acao == null ? EspacosApp.e12 : EspacosApp.e4,
            top: EspacosApp.e4,
            bottom: EspacosApp.e4,
          ),
          child: Row(
            children: [
              Icon(tom.icone, size: 20, color: tom.cor),
              const SizedBox(width: EspacosApp.e12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: EspacosApp.e8),
                  child: Text(
                    texto,
                    style: TextoApp.corpo.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: CoresApp.texto,
                    ),
                  ),
                ),
              ),
              ?acao,
            ],
          ),
        ),
      ),
    );
  }
}
