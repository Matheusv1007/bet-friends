import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/user_profile_repository.dart';
import '../provider/auth_provider.dart';
import '../services/user_profile_service.dart';
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
  bool _obscureSenha = true;
  bool _obscureConfirmarSenha = true;

  late final AuthProvider _auth;
  late bool _contaCriada;
  bool _enviando = false;
  String? _erro;

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
    super.dispose();
  }

  Future<void> _criarConta() async {
    if (_enviando) return;

    final nome = _nomeController.text;
    final username = _usernameController.text;
    final problema = _contaCriada
        ? validarPerfil(nome: nome, username: username)
        : validarCadastro(
            nome: nome,
            username: username,
            email: _emailController.text,
            senha: _senhaController.text,
            confirmacao: _confirmarSenhaController.text,
          );
    if (problema != null) {
      setState(() => _erro = problema);
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
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
          _mostrarErro(_mensagemDoAuth(e.code));
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
      _mostrarErro(_mensagemDoPerfil(e));
    } catch (_) {
      _mostrarErro(_contaCriada
          ? 'Sua conta foi criada, mas o perfil não foi concluído. Tente novamente.'
          : 'Ocorreu um erro inesperado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarErro(String mensagem) {
    if (mounted) setState(() => _erro = mensagem);
  }

  static String _mensagemDoAuth(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado. Entre com ele; se o cadastro '
            'não foi concluído, conclua-o pela aba Perfil.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'Senha fraca. Use pelo menos $senhaMinima caracteres.';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet. A conta não foi criada.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      default:
        return 'Não foi possível criar a conta. Tente novamente.';
    }
  }

  String _mensagemDoPerfil(UserProfileException e) {
    // A conta já existe: deixar claro que só falta o perfil
    final prefixo = widget.somentePerfil ? '' : 'Sua conta foi criada, mas o perfil não. ';
    switch (e.code) {
      case UserProfileErrorCode.usernameUnavailable:
        return '${prefixo}Este username já está em uso. Escolha outro.';
      case UserProfileErrorCode.invalidData:
        return '$prefixo${e.message}';
      case UserProfileErrorCode.unavailable:
        return '${prefixo}Sem confirmação do servidor. Verifique sua conexão e '
            'toque em CONCLUIR CADASTRO.';
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

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool enabled = true,
  }) {
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);

    return TextField(
      key: key,
      controller: controller,
      enabled: enabled && !_enviando,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: primaryGreen,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textMuted),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgScaffold = Color(0xFF0B111D);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.white,
          ),
          onPressed: _voltarParaLogin,
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.85, -0.9),
            radius: 1.2,
            colors: [
              Color(0xFF0F2624),
              Color(0xFF0B111D),
              Color(0xFF0B111D),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.somentePerfil ? 'Concluir Cadastro' : 'Criar Conta',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.somentePerfil
                        ? 'Escolha seu nome e username para começar a jogar'
                        : 'Junte-se ao BetFriends e comece a jogar',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: textMuted),
                  ),
                  const SizedBox(height: 30),

                  if (_contaCriada && !widget.somentePerfil) ...[
                    const _Aviso(
                      key: Key('cadastro_conta_criada'),
                      texto: 'Conta criada. Falta concluir o perfil: confira o '
                          'nome e o username e toque em CONCLUIR CADASTRO.',
                    ),
                    const SizedBox(height: 14),
                  ],

                  _buildTextField(
                    key: const Key('cadastro_nome'),
                    controller: _nomeController,
                    label: 'Nome Completo',
                    prefixIcon: Icons.badge_outlined,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    key: const Key('cadastro_username'),
                    controller: _usernameController,
                    label: 'Nome de usuário (Username)',
                    prefixIcon: Icons.alternate_email,
                  ),
                  const SizedBox(height: 14),

                  if (!widget.somentePerfil) ...[
                    _buildTextField(
                      key: const Key('cadastro_email'),
                      controller: _emailController,
                      label: 'E-mail',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_contaCriada,
                    ),
                    const SizedBox(height: 14),

                    _buildTextField(
                      key: const Key('cadastro_senha'),
                      enabled: !_contaCriada,
                      controller: _senhaController,
                      label: 'Senha',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscureSenha,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureSenha = !_obscureSenha),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildTextField(
                      key: const Key('cadastro_confirmar_senha'),
                      enabled: !_contaCriada,
                      controller: _confirmarSenhaController,
                      label: 'Confirmar Senha',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscureConfirmarSenha,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmarSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () =>
                              _obscureConfirmarSenha = !_obscureConfirmarSenha,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_erro != null) ...[
                    Text(
                      _erro!,
                      key: const Key('cadastro_erro'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      key: const Key('cadastro_enviar'),
                      onPressed: _enviando ? null : _criarConta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: const Color(0xFF062319),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _enviando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF062319),
                              ),
                            )
                          : Text(
                              _contaCriada ? 'CONCLUIR CADASTRO' : 'CADASTRAR',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (!_contaCriada) Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Já possui uma conta? ',
                        style: TextStyle(color: textMuted, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: _voltarParaLogin,
                        child: const Text(
                          'Entrar',
                          style: TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;

  const _Aviso({super.key, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2421),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00D084).withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
