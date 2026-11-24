import 'package:flutter/material.dart';

import '../tema/cores_app.dart';
import '../tema/espacos_app.dart';
import '../tema/texto_app.dart';

/// Linha de lista agrupada (Perfil, menus): altura mínima 48, divisor opcional.
class LinhaDeLista extends StatelessWidget {
  const LinhaDeLista({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.leading,
    this.trailing,
    this.onTap,
    this.divisor = false,
  });

  final String titulo;
  final String? subtitulo;

  /// Normalmente um `Icon` (fica em texto suave, 20).
  final Widget? leading;

  /// Normalmente um chevron, um valor ou um `BotaoTexto(pequeno: true)`.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Filete na base, recuado até o início do texto.
  final bool divisor;

  @override
  Widget build(BuildContext context) {
    final recuo = EspacosApp.e16 + (leading == null ? 0 : 20 + EspacosApp.e16);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: EspacosApp.alvoDeToque),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EspacosApp.e16,
                vertical: EspacosApp.e12,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    IconTheme.merge(
                      data: const IconThemeData(color: CoresApp.textoSuave, size: 20),
                      child: leading!,
                    ),
                    const SizedBox(width: EspacosApp.e16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(titulo, style: TextoApp.corpo.copyWith(color: CoresApp.texto)),
                        if (subtitulo != null)
                          Text(subtitulo!, style: TextoApp.secundario),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: EspacosApp.e12),
                    IconTheme.merge(
                      data: const IconThemeData(color: CoresApp.textoSuave, size: 20),
                      child: trailing!,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (divisor) Divider(height: 1, indent: recuo),
        ],
      ),
    );
  }
}
