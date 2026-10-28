import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/user_profile_repository.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';

/// Perfil do usuário autenticado (KAN-28).
///
/// Lê somente `users/{uid}` da sessão atual pelo [UserProfileService]: não
/// recebe UID por parâmetro, então não há como abrir o perfil de terceiros.
/// Exibe apenas dados públicos do perfil (RN-PROF-002): nome e username.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late Stream<UserProfile?> _perfil;

  @override
  void initState() {
    super.initState();
    _perfil = _observarPerfil();
  }

  Stream<UserProfile?> _observarPerfil() {
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
          child: StreamBuilder<UserProfile?>(
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
                return _AvisoPerfil(
                  icone: Icons.error_outline,
                  corIcone: const Color(0xFFEF4444),
                  titulo: 'Não foi possível carregar o perfil',
                  mensagem: _mensagemDeErro(snapshot.error!),
                  onTentarNovamente: _tentarNovamente,
                );
              }

              final perfil = snapshot.data;
              if (perfil == null) {
                return const _AvisoPerfil(
                  icone: Icons.person_off_outlined,
                  corIcone: Color(0xFF64748B),
                  titulo: 'Perfil ainda não criado',
                  mensagem:
                      'Sua conta está ativa, mas o perfil do BetFriends ainda não '
                      'foi criado. O perfil é criado no cadastro, que ainda '
                      'está em desenvolvimento.',
                );
              }

              return _DadosDoPerfil(perfil: perfil);
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
      case UserProfileErrorCode.unknown:
        return 'Não foi possível acessar o perfil. Tente novamente.';
    }
  }
}

class _DadosDoPerfil extends StatelessWidget {
  final UserProfile perfil;

  const _DadosDoPerfil({required this.perfil});

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);

    final inicial = perfil.displayName.trim().characters.first.toUpperCase();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryGreen, width: 2),
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF334155),
              child: Text(
                inicial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          perfil.displayName,
          key: const Key('perfil_display_name'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${perfil.username}',
          key: const Key('perfil_username'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: textMuted, fontSize: 15),
        ),
        const SizedBox(height: 28),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              _LinhaDoPerfil(
                icone: Icons.badge_outlined,
                rotulo: 'Nome de exibição',
                valor: perfil.displayName,
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
              _LinhaDoPerfil(
                icone: Icons.alternate_email,
                rotulo: 'Nome de usuário',
                valor: perfil.username,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinhaDoPerfil extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;

  const _LinhaDoPerfil({
    required this.icone,
    required this.rotulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icone, color: const Color(0xFF64748B), size: 20),
      title: Text(
        rotulo,
        style: const TextStyle(color: Color(0xFF8E9CAB), fontSize: 12),
      ),
      subtitle: Text(
        valor,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AvisoPerfil extends StatelessWidget {
  final IconData icone;
  final Color corIcone;
  final String titulo;
  final String mensagem;
  final VoidCallback? onTentarNovamente;

  const _AvisoPerfil({
    required this.icone,
    required this.corIcone,
    required this.titulo,
    required this.mensagem,
    this.onTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF151E2E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, color: corIcone, size: 36),
              const SizedBox(height: 10),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8E9CAB), fontSize: 12),
              ),
              if (onTentarNovamente != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onTentarNovamente,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text(
                    'TENTAR NOVAMENTE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D084),
                    foregroundColor: const Color(0xFF062319),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
