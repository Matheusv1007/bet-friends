import 'package:flutter/material.dart';

class EnviarDesafio extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onPressed;

  const EnviarDesafio({
    super.key,
    required this.isSubmitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00D084);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1420),
        border: Border(top: BorderSide(color: Color(0xFF1B2536), width: 1)),
      ),
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          key: const Key('btn_enviar_desafio'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: const Color(0xFF062319),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: isSubmitting ? null : onPressed,
          child: isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF062319),
                  ),
                )
              : const Text(
                  'ENVIAR DESAFIO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
        ),
      ),
    );
  }
}
