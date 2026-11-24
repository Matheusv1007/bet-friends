import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/user_profile_repository.dart';
import '../provider/auth_provider.dart';
import '../services/user_profile_service.dart';
import '../services/registro_de_erros.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'validacao_cadastro.dart';

/// Cadastro de usuário (KAN-25): cria a conta no Firebase Auth e, em seguida,
/// o perfil e a carteira pelo backend (`UserProfileService` → Callable
/// `createUserProfile`). O app não grava `users/{uid}`.
///
/// Se a conta for criada e o perfil não, a sessão é mantida e a tela passa a
/// repetir só a criação do perfil, que é idempotente no backend. A conta
/// nunca é apagada automaticamente. Com [somentePerfil], a tela conclui o
/// perfil de uma conta já logada (aberta pelo Perfil, para contas criadas
/// sem perfil).
class CadastroPage extends StatefulWidget {
  final bool somentePerfil;

  const CadastroPage({super.key}) : somentePerfil = false;

  const CadastroPage.concluirPerfil({super.key}) : somentePerfil = true;

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _nomeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _nomeFoco = FocusNode();
  final _usernameFoco = FocusNode();
  final _emailFoco = FocusNode();
  final _senhaFoco = FocusNode();
  final _confirmarSenhaFoco = FocusNode();

  late final AuthProvider _auth;
  late bool _contaCriada;
  bool _enviando = false;

  /// Erro inline de cada campo; some quando o campo é editado.
  String? _erroNome;
  String? _erroUsername;
  String? _erroEmail;
  String? _erroSenha;
  String? _erroConfirmacao;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _contaCriada = widget.somentePerfil;
  }

  @override
  void dispose() {
    _auth.encerrarCadastro();
    _nomeController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _nomeFoco.dispose();
    _usernameFoco.dispose();
    _emailFoco.dispose();
    _senhaFoco.dispose();
    _confirmarSenhaFoco.dispose();
    super.dispose();
  }

  void _limparErros() {
    _erroNome = null;
    _erroUsername = null;
    _erroEmail = null;
    _erroSenha = null;
    _erroConfirmacao = null;
  }

  /// Mostra os erros de validação e leva o foco ao primeiro campo com erro.
  void _mostrarErrosDeValidacao(ErrosDoCadastro erros) {
    setState(() {
      _erroNome = erros.nome;
      _erroUsername = erros.username;
      _erroEmail = erros.email;
      _erroSenha = erros.senha;
      _erroConfirmacao = erros.confirmacao;
    });
    final primeiro = [
      (erros.nome, _nomeFoco),
      (erros.username, _usernameFoco),
      (erros.email, _emailFoco),
      (erros.senha, _senhaFoco),
      (erros.confirmacao, _confirmarSenhaFoco),
    ].where((e) => e.$1 != null).firstOrNull;
    primeiro?.$2.requestFocus();
  }

  Future<void> _criarConta() async {
    if (_enviando) return;

    final nome = _nomeController.text;
    final username = _usernameController.text;
    final erros = _contaCriada
        ? validarPerfil(nome: nome, username: username)
        : validarCadastro(
            nome: nome,
            username: username,
            email: _emailController.text,
            senha: _senhaController.text,
            confirmacao: _confirmarSenhaController.text,
          );
    if (erros.temErro) {
      _mostrarErrosDeValidacao(erros);
      return;
    }

    setState(() {
      _enviando = true;
      _limparErros();
    });
    final perfis = context.read<UserProfileService>();

    try {
      if (!_contaCriada) {
        try {
          await _auth.signUp(
            email: _emailController.text,
            password: _senhaController.text,
          );
        } on FirebaseAuthException catch (e) {
          _tratarErroDoAuth(e.code);
          return;
        }
        _contaCriada = true;
      }

      await perfis.criarPerfilDoUsuarioAtual(
        displayName: nome,
        username: username,
      );
      if (!mounted) return;
      // Sucesso: volta para a Home (ou para o Perfil, ao concluir o perfil)
      if (widget.somentePerfil) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on UserProfileException catch (e) {
      _tratarErroDoPerfil(e);
    } catch (e, s) {
      registrarErro('Cadastrar conta e concluir perfil', e, s);
      _avisarErro(_contaCriada
          ? 'Sua conta foi criada, mas o perfil não foi concluído. Tente novamente.'
          : 'Ocorreu um erro inesperado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Erro sem campo correspondente: aviso na parte de baixo da tela.
  void _avisarErro(String mensagem) {
    if (mounted) {
      mostrarAviso(context, mensagem, tom: Tom.destrutivo, duracao: const Duration(seconds: 6));
    }
  }

  /// Erros do Auth que têm campo (e-mail e senha) aparecem sob ele.
  void _tratarErroDoAuth(String code) {
    if (!mounted) return;
    switch (code) {
      case 'email-already-in-use':
        setState(() => _erroEmail = 'Este e-mail já está cadastrado. Entre com ele; '
            'se o cadastro não foi concluído, conclua-o pela aba Perfil.');
      case 'invalid-email':
        setState(() => _erroEmail = 'E-mail inválido.');
      case 'weak-password':
        setState(() => _erroSenha = 'Senha fraca. Use pelo menos $senhaMinima caracteres.');
      case 'network-request-failed':
        _avisarErro('Erro de conexão. Verifique sua internet. A conta não foi criada.');
      case 'too-many-requests':
        _avisarErro('Muitas tentativas. Tente novamente mais tarde.');
      default:
        _avisarErro('Não foi possível criar a conta. Tente novamente.');
    }
  }

  /// Nome e username recusados aparecem sob o campo; o resto vira aviso. Com a
  /// conta já criada, o aviso fixo no topo diz que só falta o perfil.
  void _tratarErroDoPerfil(UserProfileException e) {
    if (!mounted) return;
    switch (e.code) {
      case UserProfileErrorCode.usernameUnavailable:
        setState(() => _erroUsername = 'Este username já está em uso. Escolha outro.');
      case UserProfileErrorCode.invalidData when e.message.startsWith('O nome'):
        setState(() => _erroNome = e.message);
      case UserProfileErrorCode.invalidData when e.message.startsWith('O username'):
        setState(() => _erroUsername = e.message);
      default:
        _avisarErro(_mensagemDoPerfil(e));
    }
  }

  String _mensagemDoPerfil(UserProfileException e) {
    // A conta já existe: deixar claro que só falta o perfil
    final prefixo = widget.somentePerfil ? '' : 'Sua conta foi criada, mas o perfil não. ';
    switch (e.code) {
      case UserProfileErrorCode.usernameUnavailable:
      case UserProfileErrorCode.invalidData:
        return '$prefixo${e.message}';
      case UserProfileErrorCode.unavailable:
        return '${prefixo}Sem confirmação do servidor. Verifique sua conexão e '
            'toque em Concluir cadastro.';
      case UserProfileErrorCode.alreadyExists:
        return 'Esta conta já possui um perfil.';
      case UserProfileErrorCode.unauthenticated:
        return 'Sua sessão expirou. Entre novamente para concluir o cadastro.';
      case UserProfileErrorCode.permissionDenied:
      case UserProfileErrorCode.unknown:
        return '${prefixo}O serviço de cadastro está indisponível agora. '
            'Tente novamente mais tarde.';
    }
  }

  void _voltarParaLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_contaCriada ? 'Concluir cadastro' : 'Criar conta'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              EspacosApp.e24,
              EspacosApp.e8,
              EspacosApp.e24,
              EspacosApp.e24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.somentePerfil
                      ? 'Escolha seu nome e username para começar a jogar'
                      : 'Junte-se ao BetFriends e comece a jogar',
                  style: TextoApp.corpo.copyWith(color: CoresApp.textoSuave),
                ),
                const SizedBox(height: EspacosApp.e24),

                if (_contaCriada && !widget.somentePerfil) ...[
                  const AvisoInline(
                    'Conta criada. Falta concluir o perfil: confira o '
                    'nome e o username e toque em Concluir cadastro.',
                    Tom.atencao,
                    key: Key('cadastro_conta_criada'),
                  ),
                  const SizedBox(height: EspacosApp.e16),
                ],

                CampoDeTexto(
                  key: const Key('cadastro_nome'),
                  rotulo: 'Nome completo',
                  controller: _nomeController,
                  focusNode: _nomeFoco,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  enabled: !_enviando,
                  erro: _erroNome,
                  onChanged: (_) {
                    if (_erroNome != null) setState(() => _erroNome = null);
                  },
                ),
                const SizedBox(height: EspacosApp.e16),

                CampoDeTexto(
                  key: const Key('cadastro_username'),
                  rotulo: 'Nome de usuário',
                  ajuda: '3 a 20 caracteres: letras, números e _. Não muda depois.',
                  controller: _usernameController,
                  focusNode: _usernameFoco,
                  textInputAction: TextInputAction.next,
                  enabled: !_enviando,
                  erro: _erroUsername,
                  onChanged: (_) {
                    if (_erroUsername != null) setState(() => _erroUsername = null);
                  },
                ),
                const SizedBox(height: EspacosApp.e16),

                if (!widget.somentePerfil) ...[
                  CampoDeTexto(
                    key: const Key('cadastro_email'),
                    rotulo: 'E-mail',
                    controller: _emailController,
                    focusNode: _emailFoco,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_contaCriada && !_enviando,
                    erro: _erroEmail,
                    onChanged: (_) {
                      if (_erroEmail != null) setState(() => _erroEmail = null);
                    },
                  ),
                  const SizedBox(height: EspacosApp.e16),

                  CampoDeTexto(
                    key: const Key('cadastro_senha'),
                    rotulo: 'Senha',
                    ajuda: 'Mínimo de $senhaMinima caracteres.',
                    controller: _senhaController,
                    focusNode: _senhaFoco,
                    senha: true,
                    textInputAction: TextInputAction.next,
                    enabled: !_contaCriada && !_enviando,
                    erro: _erroSenha,
                    onChanged: (_) {
                      if (_erroSenha != null) setState(() => _erroSenha = null);
                    },
                  ),
                  const SizedBox(height: EspacosApp.e16),

                  CampoDeTexto(
                    key: const Key('cadastro_confirmar_senha'),
                    rotulo: 'Confirmar senha',
                    controller: _confirmarSenhaController,
                    focusNode: _confirmarSenhaFoco,
                    senha: true,
                    textInputAction: TextInputAction.done,
                    enabled: !_contaCriada && !_enviando,
                    erro: _erroConfirmacao,
                    onChanged: (_) {
                      if (_erroConfirmacao != null) {
                        setState(() => _erroConfirmacao = null);
                      }
                    },
                    onSubmitted: (_) => _criarConta(),
                  ),
                  const SizedBox(height: EspacosApp.e16),
                ],

                const SizedBox(height: EspacosApp.e8),
                BotaoPrimario(
                  key: const Key('cadastro_enviar'),
                  rotulo: _contaCriada ? 'Concluir cadastro' : 'Cadastrar',
                  carregando: _enviando,
                  larguraTotal: true,
                  onPressed: _criarConta,
                ),

                if (!_contaCriada) ...[
                  const SizedBox(height: EspacosApp.e16),
                  // Wrap: com fonte grande o link desce para a linha de baixo
                  // em vez de estourar a largura
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Já possui uma conta?',
                        style: TextoApp.corpo.copyWith(color: CoresApp.textoSuave),
                      ),
                      BotaoTexto(
                        key: const Key('cadastro_entrar'),
                        rotulo: 'Entrar',
                        onPressed: _voltarParaLogin,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
