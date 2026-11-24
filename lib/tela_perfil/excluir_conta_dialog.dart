import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/auth_provider.dart';
import '../services/auth_service.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';

class ExcluirContaDialog extends StatefulWidget {
  final String username;

  const ExcluirContaDialog({super.key, required this.username});

  @override
  State<ExcluirContaDialog> createState() => _ExcluirContaDialogState();
}

class _ExcluirContaDialogState extends State<ExcluirContaDialog> {
  final _username = TextEditingController();
  final _senha = TextEditingController();
  bool _excluindo = false;

  /// Erros sob cada campo; somem ao editar o campo.
  String? _erroUsername;
  String? _erroSenha;

  /// Falha sem campo correspondente (conexão, desafio ativo, sessão).
  String? _erro;

  static bool _senhaIncorreta(String code) =>
      code == 'wrong-password' ||
      code == 'invalid-credential' ||
      code == 'invalid-login-credentials';

  @override
  void dispose() {
    _senha.clear();
    _senha.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _excluir() async {
    if (_excluindo) return;
    final usernameConfere = _username.text == widget.username;
    final senhaPreenchida = _senha.text.isNotEmpty;
    if (!usernameConfere || !senhaPreenchida) {
      _senha.clear();
      setState(() {
        _erroUsername =
            usernameConfere ? null : 'Digite seu username exatamente como exibido.';
        _erroSenha = senhaPreenchida ? null : 'Informe sua senha atual.';
      });
      return;
    }
    setState(() {
      _excluindo = true;
      _erro = null;
      _erroUsername = null;
      _erroSenha = null;
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
        if (e is DeleteAccountException && _senhaIncorreta(e.code)) {
          _erroSenha = e.message;
        } else {
          _erro = e is DeleteAccountException
              ? e.message
              : 'Não foi possível excluir a conta. Tente novamente.';
        }
      });
    } finally {
      if (mounted) _senha.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_excluindo,
      child: AlertDialog(
        scrollable: true,
        // Margens menores para as duas ações caberem numa linha em 320 dp
        insetPadding: const EdgeInsets.symmetric(horizontal: EspacosApp.e16, vertical: EspacosApp.e24),
        actionsPadding: const EdgeInsets.fromLTRB(EspacosApp.e16, 0, EspacosApp.e16, EspacosApp.e16),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: CoresApp.destrutivo),
            SizedBox(width: EspacosApp.e12),
            Expanded(child: Text('Excluir conta')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Esta ação é permanente. Seu perfil, amizades e pedidos de '
              'amizade serão apagados. Seu username ficará livre. '
              'O extrato e os desafios encerrados permanecerão sem dados pessoais. '
              'A exclusão exige conexão com o servidor.',
              style: TextoApp.secundario.copyWith(fontSize: 14),
            ),
            const SizedBox(height: EspacosApp.e20),
            CampoDeTexto(
              key: const Key('excluir_conta_username'),
              rotulo: 'Digite seu username para confirmar',
              ajuda: 'Seu username: ${widget.username}',
              controller: _username,
              enabled: !_excluindo,
              textInputAction: TextInputAction.next,
              erro: _erroUsername,
              onChanged: (_) {
                if (_erroUsername != null) setState(() => _erroUsername = null);
              },
            ),
            const SizedBox(height: EspacosApp.e16),
            CampoDeTexto(
              key: const Key('excluir_conta_senha'),
              rotulo: 'Senha atual',
              controller: _senha,
              senha: true,
              enabled: !_excluindo,
              erro: _erroSenha,
              onChanged: (_) {
                if (_erroSenha != null) setState(() => _erroSenha = null);
              },
              onSubmitted: (_) => _excluir(),
            ),
            if (_erro != null) ...[
              const SizedBox(height: EspacosApp.e16),
              AvisoInline(_erro!, Tom.destrutivo, key: const Key('excluir_conta_erro')),
            ],
          ],
        ),
        actions: [
          BotaoTexto(
            key: const Key('excluir_conta_cancelar'),
            rotulo: 'Cancelar',
            onPressed: _excluindo ? null : () => Navigator.pop(context),
          ),
          BotaoDestrutivo(
            key: const Key('excluir_conta_confirmar'),
            rotulo: 'Excluir conta',
            carregando: _excluindo,
            onPressed: _excluir,
          ),
        ],
      ),
    );
  }
}
