import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/user_profile_repository.dart';
import '../services/user_profile_service.dart';

/// Edita somente `displayName` (KAN-29). Fecha com `true` apenas depois que o
/// Firestore confirmou a gravação; com `false` ao cancelar ou se nada mudou.
class EditarNomeDialog extends StatefulWidget {
  final String nomeAtual;

  const EditarNomeDialog({super.key, required this.nomeAtual});

  @override
  State<EditarNomeDialog> createState() => _EditarNomeDialogState();
}

class _EditarNomeDialogState extends State<EditarNomeDialog> {
  late final _controller = TextEditingController(text: widget.nomeAtual);
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Mesmos limites do schema §3.1 e das Security Rules.
  static String? _validar(String? valor) {
    final nome = (valor ?? '').trim();
    if (nome.isEmpty) return 'Informe um nome de exibição.';
    if (nome.length > 60) return 'Use no máximo 60 caracteres.';
    return null;
  }

  Future<void> _salvar() async {
    if (_salvando || !_formKey.currentState!.validate()) return;

    final nome = _controller.text.trim();
    if (nome == widget.nomeAtual) {
      Navigator.pop(context, false);
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      await context.read<UserProfileService>().atualizarDisplayNameAtual(nome);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = _mensagemDeErroAoSalvar(e);
      });
    }
  }

  static String _mensagemDeErroAoSalvar(Object erro) {
    if (erro is! UserProfileException) {
      return 'Ocorreu um erro inesperado. O nome não foi alterado.';
    }
    switch (erro.code) {
      case UserProfileErrorCode.unavailable:
        return 'Sem conexão com o servidor. O nome não foi alterado.';
      case UserProfileErrorCode.permissionDenied:
        return 'Você não tem permissão para alterar este perfil.';
      case UserProfileErrorCode.unauthenticated:
        return 'Sua sessão expirou. Entre novamente para alterar o nome.';
      case UserProfileErrorCode.invalidData:
        return erro.message;
      case UserProfileErrorCode.alreadyExists:
      case UserProfileErrorCode.usernameUnavailable:
      case UserProfileErrorCode.unknown:
        return 'Não foi possível salvar. O nome não foi alterado.';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);

    return PopScope(
      canPop: !_salvando,
      child: AlertDialog(
        backgroundColor: const Color(0xFF151E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Editar nome de exibição',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('editar_nome_campo'),
                controller: _controller,
                enabled: !_salvando,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                validator: _validar,
                onFieldSubmitted: (_) => _salvar(),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: primaryGreen,
                decoration: InputDecoration(
                  labelText: 'Nome de exibição',
                  labelStyle: const TextStyle(color: textMuted),
                  helperText: 'De 1 a 60 caracteres. O username não muda.',
                  helperStyle: const TextStyle(color: textMuted, fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFF0B111D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                  ),
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erro!,
                  key: const Key('editar_nome_erro'),
                  style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _salvando ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            key: const Key('editar_nome_salvar'),
            onPressed: _salvando ? null : _salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              disabledBackgroundColor: primaryGreen.withValues(alpha: 0.65),
              foregroundColor: const Color(0xFF062319),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF062319),
                    ),
                  )
                : const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
