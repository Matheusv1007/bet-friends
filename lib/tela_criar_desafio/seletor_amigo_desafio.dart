import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'cartao_amigo_desafio.dart';

/// Seção "Amigo" de Criar Desafio: lista de rádios num grupo de superfície 1.
class SeletorAmigoDesafio extends StatelessWidget {
  final bool isLoadingAmigos;
  final List<AmigoItem> amigosAceitos;
  final String? amigoId;
  final String? amigoNome;
  final void Function(String uid, String nome) onChanged;

  const SeletorAmigoDesafio({
    super.key,
    required this.isLoadingAmigos,
    required this.amigosAceitos,
    required this.amigoId,
    required this.amigoNome,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[
      if (amigoId != null && !amigosAceitos.any((a) => a.uid == amigoId))
        CartaoAmigoDesafio(
          uid: amigoId!,
          onTap: () => onChanged(amigoId!, amigoNome ?? 'Amigo Selecionado'),
          displayName: amigoNome ?? 'Amigo Selecionado',
          isSelected: true,
        ),
      for (final amigo in amigosAceitos)
        CartaoAmigoDesafio(
          uid: amigo.uid,
          onTap: () => onChanged(amigo.uid, amigo.displayName),
          displayName: amigo.displayName,
          username: amigo.username,
          isSelected: amigoId == amigo.uid,
        ),
    ];

    final Widget conteudo;
    if (isLoadingAmigos) {
      conteudo = const Padding(
        padding: EdgeInsets.all(EspacosApp.e24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (linhas.isEmpty) {
      conteudo = const Padding(
        padding: EdgeInsets.all(EspacosApp.e16),
        child: Text(
          'Você ainda não possui amigos aceitos. Adicione amigos na aba Amigos para poder criar desafios.',
          style: TextoApp.secundario,
          textAlign: TextAlign.center,
        ),
      );
    } else {
      conteudo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < linhas.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            linhas[i],
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloDeSecao('Amigo'),
        const SizedBox(height: EspacosApp.e8),
        Material(
          color: CoresApp.superficie1,
          borderRadius: RaiosApp.bordaCartao,
          clipBehavior: Clip.antiAlias,
          child: conteudo,
        ),
      ],
    );
  }
}
