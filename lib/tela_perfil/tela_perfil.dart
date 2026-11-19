import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/user_profile_repository.dart';
import '../services/user_profile_service.dart';
import '../telas_autenticacao/cadastro_page.dart';
import 'aviso_perfil.dart';
import 'dados_do_perfil.dart';

/// Perfil do usuário autenticado (KAN-28).
///
/// Lê somente `users/{uid}` da sessão atual pelo [UserProfileService]: não
/// recebe UID por parâmetro, então não há como abrir o perfil de terceiros.
/// Exibe apenas dados públicos do perfil (RN-PROF-002): nome e username.
///
/// Sem conexão (KAN-24), continua exibindo o último perfil conhecido neste
/// aparelho, avisa que ele pode estar desatualizado e não permite editar.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late Stream<PerfilObservado> _perfil;

  @override
  void initState() {
    super.initState();
    _perfil = _observarPerfil();
  }

  Stream<PerfilObservado> _observarPerfil() {
    try {
      return context.read<UserProfileService>().observarPerfilAtual();
    } on UserProfileException catch (e) {
      // Ex.: sessão encerrada — exibido como erro na tela, sem quebrar o app
      return Stream.error(e);
    }
  }

  void _tentarNovamente() {
    setState(() => _perfil = _observarPerfil());
  }

  @override
  Widget build(BuildContext context) {
    const bgScaffold = Color(0xFF0B111D);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Perfil',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.85, -0.9),
            radius: 1.2,
            colors: [Color(0xFF0F2624), Color(0xFF0B111D), Color(0xFF0B111D)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<PerfilObservado>(
            stream: _perfil,
            builder: (context, snapshot) {
              // Ao tentar novamente, o snapshot volta a "waiting" mas mantém o
              // erro anterior; por isso o carregamento é verificado primeiro.
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D084)),
                );
              }

              if (snapshot.hasError) {
                return AvisoPerfil(
                  icone: Icons.error_outline,
                  corIcone: const Color(0xFFEF4444),
                  titulo: 'Não foi possível carregar o perfil',
                  mensagem: _mensagemDeErro(snapshot.error!),
                  onTentarNovamente: _tentarNovamente,
                );
              }

              final perfil = snapshot.data!.perfil;
              if (perfil == null) {
                // Conta criada no Auth sem perfil (cadastro interrompido): o
                // perfil é concluído pela própria tela de cadastro (KAN-25)
                return AvisoPerfil(
                  icone: Icons.person_off_outlined,
                  corIcone: const Color(0xFF94A3B8),
                  titulo: 'Perfil ainda não criado',
                  mensagem:
                      'Sua conta está ativa, mas o cadastro não foi concluído. '
                      'Escolha seu nome e username para criar o perfil.',
                  rotuloDaAcao: 'CONCLUIR CADASTRO',
                  iconeDaAcao: Icons.person_add_alt_1,
                  onTentarNovamente: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CadastroPage.concluirPerfil(),
                    ),
                  ),
                );
              }

              return DadosDoPerfil(
                perfil: perfil,
                semConexao: snapshot.data!.doCache,
              );
            },
          ),
        ),
      ),
    );
  }

  static String _mensagemDeErro(Object erro) {
    if (erro is! UserProfileException) {
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
    switch (erro.code) {
      case UserProfileErrorCode.unavailable:
        return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
      case UserProfileErrorCode.permissionDenied:
        return 'Você não tem permissão para acessar este perfil.';
      case UserProfileErrorCode.unauthenticated:
        return 'Sua sessão expirou. Entre novamente para ver o perfil.';
      case UserProfileErrorCode.invalidData:
        return 'Os dados do perfil estão incompletos.';
      case UserProfileErrorCode.alreadyExists:
      case UserProfileErrorCode.usernameUnavailable:
      case UserProfileErrorCode.unknown:
        return 'Não foi possível acessar o perfil. Tente novamente.';
    }
  }
}
