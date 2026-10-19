import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/auth_provider.dart';
import '../telas_principais/homePage.dart';
import 'login_page.dart';

/// Decide entre Login e Home a partir da sessão do Firebase.
/// É a única responsável pela navegação entre as áreas autenticada e pública.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStateChanges;
  String? _uidAtual;
  bool _sessaoResolvida = false;

  @override
  void initState() {
    super.initState();
    // Assina uma única vez para não recriar o stream a cada rebuild
    _authStateChanges = context.read<AuthProvider>().authStateChanges;
  }

  /// Ao entrar, sair ou trocar de usuário, descarta as telas empilhadas acima
  /// do AuthGate (ex.: Criar Desafio, Cadastro) para não sobrar tela da sessão anterior.
  void _sincronizarPilha(String? uid) {
    if (_sessaoResolvida && uid == _uidAtual) return;

    final houveTroca = _sessaoResolvida;
    _uidAtual = uid;
    _sessaoResolvida = true;

    if (!houveTroca) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _VerificandoSessao();
        }

        final user = snapshot.data;
        _sincronizarPilha(user?.uid);

        if (user == null) {
          return const LoginPage();
        }

        // A chave por UID recria a Home (e seu polling) ao trocar de usuário
        return Homepage(key: ValueKey(user.uid));
      },
    );
  }
}

/// Exibida enquanto o Firebase restaura a sessão, evitando mostrar
/// brevemente o Login para quem já está autenticado.
class _VerificandoSessao extends StatelessWidget {
  const _VerificandoSessao();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B111D),
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            color: Color(0xFF00D084),
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }
}
