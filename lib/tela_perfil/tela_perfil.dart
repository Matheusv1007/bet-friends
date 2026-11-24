import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/user_profile_repository.dart';
import '../services/user_profile_service.dart';
import '../tema/tema.dart';
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Perfil'),
      ),
      body: SafeArea(
        child: StreamBuilder<PerfilObservado>(
          stream: _perfil,
          builder: (context, snapshot) {
            // Ao tentar novamente, o snapshot volta a "waiting" mas mantém o
            // erro anterior; por isso o carregamento é verificado primeiro.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return AvisoPerfil(
                tom: Tom.destrutivo,
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
                tom: Tom.neutro,
                titulo: 'Perfil ainda não criado',
                mensagem:
                    'Sua conta está ativa, mas o cadastro não foi concluído. '
                    'Escolha seu nome e username para criar o perfil.',
                rotuloDaAcao: 'Concluir cadastro',
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
