import 'package:flutter/material.dart';

import '../tema/tema.dart';

/// Linha de dado do grupo DADOS: rótulo pequeno em cima, valor embaixo e uma
/// ação opcional à direita (ex.: "Editar").
class LinhaDoPerfil extends StatelessWidget {
  final String rotulo;
  final String valor;
  final Key? chaveDoValor;
  final Widget? acao;

  const LinhaDoPerfil({
    super.key,
    required this.rotulo,
    required this.valor,
    this.chaveDoValor,
    this.acao,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: EspacosApp.alvoDeToque),
      child: Padding(
        padding: EdgeInsets.only(
          left: EspacosApp.e16,
          right: acao == null ? EspacosApp.e16 : EspacosApp.e8,
          top: EspacosApp.e12,
          bottom: EspacosApp.e12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rotulo, style: TextoApp.secundario),
                  Text(
                    valor,
                    key: chaveDoValor,
                    style: TextoApp.corpoForte.copyWith(color: CoresApp.texto),
                  ),
                ],
              ),
            ),
            ?acao,
          ],
        ),
      ),
    );
  }
}
