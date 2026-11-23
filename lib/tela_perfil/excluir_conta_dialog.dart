import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/auth_provider.dart';
import '../services/auth_service.dart';

class ExcluirContaDialog extends StatefulWidget {
  final String username;

  const ExcluirContaDialog({super.key, required this.username});

  @override
  State<ExcluirContaDialog> createState() => _ExcluirContaDialogState();
}

class _ExcluirContaDialogState extends State<ExcluirContaDialog> {
  final _username = TextEditingController();
  final _senha = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _excluindo = false;
  String? _erro;

  @override
  void dispose() {
    _senha.clear();
    _senha.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _excluir() async {
    if (_excluindo) return;
    if (!_formKey.currentState!.validate()) {
      _senha.clear();
      return;
    }
    setState(() {
      _excluindo = true;
      _erro = null;
    });
    try {
      final exclusao = context.read<AuthProvider>().deleteAccount(
        password: _senha.text,
      );
      // Não guarda a senha enquanto aguarda rede nem entre tentativas.
      _senha.clear();
      await exclusao;
      // Sem navegação manual: o AuthGate descarta as rotas da sessão excluída.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _excluindo = false;
        _erro = e is DeleteAccountException
            ? e.message
            : 'Não foi possível excluir a conta. Tente novamente.';
      });
    } finally {
      if (mounted) _senha.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    const alerta = Color(0xFFEF4444);
    const textoSecundario = Color(0xFF94A3B8);
    const campo = InputDecoration(
      filled: true,
      fillColor: Color(0xFF0B111D),
      border: OutlineInputBorder(),
      labelStyle: TextStyle(color: textoSecundario),
      errorMaxLines: 3,
    );

    return PopScope(
      canPop: !_excluindo,
      child: AlertDialog(
        backgroundColor: const Color(0xFF151E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: alerta),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Excluir conta',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta ação é permanente. Seu perfil, amizades e pedidos de '
                  'amizade serão apagados. Seu username ficará livre. '
                  'O extrato e os desafios encerrados permanecerão sem dados pessoais. '
                  'A exclusão exige conexão com o servidor.',
                  style: TextStyle(color: textoSecundario, height: 1.4),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('excluir_conta_username'),
                  controller: _username,
                  enabled: !_excluindo,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: campo.copyWith(
                    labelText: 'Digite seu username: ${widget.username}',
                  ),
                  validator: (valor) => valor == widget.username
                      ? null
                      : 'Digite seu username exatamente como exibido.',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('excluir_conta_senha'),
                  controller: _senha,
                  enabled: !_excluindo,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: campo.copyWith(labelText: 'Senha atual'),
                  validator: (valor) => valor == null || valor.isEmpty
                      ? 'Informe sua senha atual.'
                      : null,
                  onFieldSubmitted: (_) => _excluir(),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _erro!,
                    key: const Key('excluir_conta_erro'),
                    style: const TextStyle(color: alerta),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('excluir_conta_cancelar'),
            onPressed: _excluindo ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: textoSecundario,
            ),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('excluir_conta_confirmar'),
            onPressed: _excluindo ? null : _excluir,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: alerta,
              foregroundColor: const Color(0xFF0B111D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _excluindo
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Excluir definitivamente'),
          ),
        ],
      ),
    );
  }
}
