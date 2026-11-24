import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:provider/provider.dart';

import 'cadastro_page.dart';
import '../provider/auth_provider.dart';
import '../services/registro_de_erros.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  /// Erros inline: o do e-mail ou usuário fica sob o primeiro campo; as
  /// credenciais incorretas, sob a senha. Somem ao editar o campo.
  String? _erroIdentificador;
  String? _erroSenha;

  Future<void> _entrar() async {
    if (_isLoading) return;

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    // Validação básica antes de chamar o Firebase
    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        _erroIdentificador = identifier.isEmpty ? 'Informe seu e-mail ou usuário.' : null;
        _erroSenha = password.isEmpty ? 'Informe sua senha.' : null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _erroIdentificador = null;
      _erroSenha = null;
    });

    try {
      // Em caso de sucesso, o AuthGate recebe a nova sessão e exibe a Home.
      // Não navegar aqui para não empilhar uma segunda Home.
      await context.read<AuthProvider>().signIn(
        identifier: identifier,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      switch (e.code) {
        case 'invalid-email':
          setState(() => _erroIdentificador = 'E-mail inválido.');
          break;

        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          setState(() => _erroSenha = 'E-mail, usuário ou senha incorretos.');
          break;

        case 'user-disabled':
          mostrarAviso(context, 'Esta conta foi desativada.', tom: Tom.destrutivo);
          break;

        case 'too-many-requests':
          mostrarAviso(
            context,
            'Muitas tentativas. Tente novamente mais tarde.',
            tom: Tom.destrutivo,
          );
          break;

        case 'network-request-failed':
          mostrarAviso(
            context,
            'Erro de conexão. Verifique sua internet.',
            tom: Tom.destrutivo,
          );
          break;

        default:
          mostrarAviso(
            context,
            'Não foi possível entrar. Tente novamente.',
            tom: Tom.destrutivo,
          );
      }
    } catch (e, s) {
      registrarErro('Entrar na conta', e, s);
      if (!mounted) return;

      mostrarAviso(
        context,
        'Ocorreu um erro inesperado. Tente novamente.',
        tom: Tom.destrutivo,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: EspacosApp.e24,
              vertical: EspacosApp.e20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo à esquerda; em telas estreitas encolhe em vez de estourar
                const Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: LogoBetFriends(altura: 36),
                  ),
                ),
                const SizedBox(height: EspacosApp.e8),
                Text(
                  'Aposte e desafie seus amigos',
                  style: TextoApp.corpo.copyWith(color: CoresApp.textoSuave),
                ),
                const SizedBox(height: EspacosApp.e32),

                CampoDeTexto(
                  key: const Key('login_identificador'),
                  rotulo: 'E-mail ou usuário',
                  controller: _identifierController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  erro: _erroIdentificador,
                  onChanged: (_) {
                    if (_erroIdentificador != null || _erroSenha != null) {
                      setState(() {
                        _erroIdentificador = null;
                        _erroSenha = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: EspacosApp.e16),

                CampoDeTexto(
                  key: const Key('login_senha'),
                  rotulo: 'Senha',
                  controller: _passwordController,
                  senha: true,
                  textInputAction: TextInputAction.done,
                  enabled: !_isLoading,
                  erro: _erroSenha,
                  onChanged: (_) {
                    if (_erroSenha != null) setState(() => _erroSenha = null);
                  },
                  onSubmitted: (_) => _entrar(),
                ),
                const SizedBox(height: EspacosApp.e24),

                BotaoPrimario(
                  key: const Key('login_entrar'),
                  rotulo: 'Entrar',
                  carregando: _isLoading,
                  larguraTotal: true,
                  onPressed: _entrar,
                ),
                const SizedBox(height: EspacosApp.e16),

                // Wrap: com fonte grande o link desce para a linha de baixo
                // em vez de sair da tela
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Não tem uma conta?',
                      style: TextoApp.corpo.copyWith(color: CoresApp.textoSuave),
                    ),
                    BotaoTexto(
                      key: const Key('login_criar_conta'),
                      rotulo: 'Criar conta',
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CadastroPage(),
                                ),
                              );
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
