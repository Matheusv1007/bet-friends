import 'package:flutter/material.dart';

import '../models/user_profile.dart';

class CabecalhoDoPerfil extends StatelessWidget {
  final UserProfile perfil;

  const CabecalhoDoPerfil({super.key, required this.perfil});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);
    final inicial = perfil.displayName.trim().characters.first.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryGreen, width: 2),
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF334155),
              child: Text(
                inicial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          perfil.displayName,
          key: const Key('perfil_display_name'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${perfil.username}',
          key: const Key('perfil_username'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: textMuted, fontSize: 15),
        ),
      ],
    );
  }
}
