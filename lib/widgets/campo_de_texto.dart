import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema/cores_app.dart';
import '../tema/espacos_app.dart';
import '../tema/texto_app.dart';

/// Campo com rótulo acima, dica, ajuda e erro inline (coral, com ícone).
///
/// O erro vem de [erro] (estado da tela) ou de [validator] (dentro de um
/// `Form`); [erro] tem precedência. Com [senha], um botão alterna a
/// visibilidade. A [key] fica no widget externo; `enterText(find.byKey(k))`
/// funciona, e o `TextField` interno sai de `find.descendant`.
class CampoDeTexto extends StatefulWidget {
  const CampoDeTexto({
    super.key,
    required this.rotulo,
    this.controller,
    this.dica,
    this.ajuda,
    this.erro,
    this.validator,
    this.senha = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  final String rotulo;
  final TextEditingController? controller;
  final String? dica;
  final String? ajuda;
  final String? erro;
  final FormFieldValidator<String>? validator;
  final bool senha;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CampoDeTexto> createState() => _CampoDeTextoState();
}

class _CampoDeTextoState extends State<CampoDeTexto> {
  bool _senhaVisivel = false;

  @override
  Widget build(BuildContext context) {
    final senha = widget.senha;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.rotulo,
            style: TextoApp.secundario.copyWith(
              fontWeight: FontWeight.w600,
              color: widget.enabled ? CoresApp.texto : CoresApp.textoSuave,
            ),
          ),
        ),
        const SizedBox(height: EspacosApp.e8),
        Semantics(
          label: widget.rotulo,
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            obscureText: senha && !_senhaVisivel,
            enableSuggestions: !senha,
            autocorrect: !senha,
            style: TextoApp.corpo.copyWith(color: CoresApp.texto),
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            validator: widget.validator,
            forceErrorText: widget.erro,
            errorBuilder: (context, texto) => _ErroInline(texto),
            decoration: InputDecoration(
              hintText: widget.dica,
              helper: widget.ajuda == null
                  ? null
                  : Text(widget.ajuda!, style: TextoApp.secundario),
              suffixIcon: senha
                  ? IconButton(
                      tooltip: _senhaVisivel
                          ? 'Ocultar senha'
                          : 'Mostrar senha',
                      icon: Icon(
                        _senhaVisivel
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _senhaVisivel = !_senhaVisivel),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErroInline extends StatelessWidget {
  const _ErroInline(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: 16,
              color: CoresApp.destrutivo,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: TextoApp.secundario.copyWith(color: CoresApp.destrutivo),
            ),
          ),
        ],
      ),
    );
  }
}
