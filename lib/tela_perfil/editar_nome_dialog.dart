import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/user_profile_repository.dart';
import '../services/user_profile_service.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';

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
  bool _salvando = false;

  /// Erro de validação, sob o campo; some ao editar.
  String? _erroDoCampo;

  /// Falha ao salvar (conexão, permissão, sessão), fora do campo.
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
    if (_salvando) return;

    final problema = _validar(_controller.text);
    if (problema != null) {
      setState(() => _erroDoCampo = problema);
      return;
    }

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
    return PopScope(
      canPop: !_salvando,
      child: AlertDialog(
        scrollable: true,
        // Margens menores para as duas ações caberem numa linha em 320 dp
        insetPadding: const EdgeInsets.symmetric(horizontal: EspacosApp.e16, vertical: EspacosApp.e24),
        actionsPadding: const EdgeInsets.fromLTRB(EspacosApp.e16, 0, EspacosApp.e16, EspacosApp.e16),
        title: const Text('Editar nome de exibição'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoDeTexto(
              key: const Key('editar_nome_campo'),
              rotulo: 'Nome de exibição',
              ajuda: 'De 1 a 60 caracteres. O username não muda.',
              controller: _controller,
              enabled: !_salvando,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              erro: _erroDoCampo,
              onChanged: (_) {
                if (_erroDoCampo != null) setState(() => _erroDoCampo = null);
              },
              onSubmitted: (_) => _salvar(),
            ),
            if (_erro != null) ...[
              const SizedBox(height: EspacosApp.e12),
              AvisoInline(_erro!, Tom.destrutivo, key: const Key('editar_nome_erro')),
            ],
          ],
        ),
        actions: [
          BotaoTexto(
            key: const Key('editar_nome_cancelar'),
            rotulo: 'Cancelar',
            onPressed: _salvando ? null : () => Navigator.pop(context, false),
          ),
          BotaoPrimario(
            key: const Key('editar_nome_salvar'),
            rotulo: 'Salvar',
            carregando: _salvando,
            onPressed: _salvar,
          ),
        ],
      ),
    );
  }
}
