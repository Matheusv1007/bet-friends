import 'package:flutter/material.dart';

class LinhaDoPerfil extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;

  const LinhaDoPerfil({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icone, color: const Color(0xFF94A3B8), size: 20),
      title: Text(
        rotulo,
        style: const TextStyle(color: Color(0xFF8E9CAB), fontSize: 12),
      ),
      subtitle: Text(
        valor,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
