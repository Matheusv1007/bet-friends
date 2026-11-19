import 'package:flutter/material.dart';

import '../models/challenge_model.dart';
import 'cartao_amigo_desafio.dart';

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
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECIONE O AMIGO',
          style: TextStyle(
            color: textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        if (isLoadingAmigos)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: primaryGreen),
            ),
          )
        else if (amigosAceitos.isEmpty && amigoId == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Você ainda não possui amigos aceitos. Adicione amigos na aba Amigos para poder criar desafios.',
              style: TextStyle(color: textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          if (amigoId != null && !amigosAceitos.any((a) => a.uid == amigoId))
            CartaoAmigoDesafio(
              uid: amigoId!,
              onTap: () =>
                  onChanged(amigoId!, amigoNome ?? 'Amigo Selecionado'),
              displayName: amigoNome ?? 'Amigo Selecionado',
              isSelected: true,
            ),
          ...amigosAceitos.map((amigo) {
            final sel = amigoId == amigo.uid;
            return CartaoAmigoDesafio(
              uid: amigo.uid,
              onTap: () => onChanged(amigo.uid, amigo.displayName),
              displayName: amigo.displayName,
              username: amigo.username,
              isSelected: sel,
            );
          }),
        ],
      ],
    );
  }
}
