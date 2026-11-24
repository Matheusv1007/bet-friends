import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../tema/tema.dart';

class CabecalhoDoPerfil extends StatelessWidget {
  final UserProfile perfil;

  const CabecalhoDoPerfil({super.key, required this.perfil});

  @override
  Widget build(BuildContext context) {
    final inicial = perfil.displayName.trim().characters.first.toUpperCase();

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: CoresApp.superficie2,
          ),
          child: ExcludeSemantics(
            child: Text(
              inicial,
              style: TextoApp.tituloDeTela.copyWith(color: CoresApp.texto),
            ),
          ),
        ),
        const SizedBox(width: EspacosApp.e16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                perfil.displayName,
                key: const Key('perfil_display_name'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextoApp.tituloDeTela.copyWith(color: CoresApp.texto),
              ),
              Text(
                '@${perfil.username}',
                key: const Key('perfil_username'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextoApp.corpo.copyWith(color: CoresApp.textoSuave),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
