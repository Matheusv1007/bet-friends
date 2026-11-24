import 'package:flutter/material.dart';

import '../tela_amigos/avatar_de_iniciais.dart';
import '../tema/tema.dart';
import '../widgets/texto_sem_corte.dart';

/// Linha de rádio do amigo a desafiar: iniciais, nome (até 2 linhas) e
/// @username; fica dentro do grupo do [SeletorAmigoDesafio].
class CartaoAmigoDesafio extends StatelessWidget {
  final String uid;
  final String displayName;
  final String? username;
  final bool isSelected;
  final VoidCallback onTap;

  const CartaoAmigoDesafio({
    super.key,
    required this.uid,
    required this.displayName,
    this.username,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: isSelected ? CoresApp.superficie2 : CoresApp.superficie1,
        child: InkWell(
          key: Key('amigo_item_$uid'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: EspacosApp.alvoDeToque),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EspacosApp.e16,
                vertical: EspacosApp.e12,
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 22,
                    color: isSelected ? CoresApp.primario : CoresApp.textoSuave,
                  ),
                  const SizedBox(width: EspacosApp.e12),
                  AvatarDeIniciais(displayName, tamanho: 36),
                  const SizedBox(width: EspacosApp.e12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextoSemCorte(
                          displayName,
                          estilo: TextoApp.corpoForte.copyWith(
                            color: CoresApp.texto,
                            height: 1.25,
                          ),
                        ),
                        if (username != null)
                          Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextoApp.secundario,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
