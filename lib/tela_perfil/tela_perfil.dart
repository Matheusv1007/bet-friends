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
                return _AvisoPerfil(
                  icone: Icons.error_outline,
                  corIcone: const Color(0xFFEF4444),
                  titulo: 'Não foi possível carregar o perfil',
                  mensagem: _mensagemDeErro(snapshot.error!),
                  onTentarNovamente: _tentarNovamente,
                );
              }

              final perfil = snapshot.data!.perfil;
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

              return _DadosDoPerfil(
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
      case UserProfileErrorCode.unknown:
        return 'Não foi possível acessar o perfil. Tente novamente.';
    }
  }
}

class _DadosDoPerfil extends StatelessWidget {
  final UserProfile perfil;

  /// O perfil veio do cache: o servidor não confirmou o dado.
  final bool semConexao;

  const _DadosDoPerfil({required this.perfil, required this.semConexao});

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);

    final inicial = perfil.displayName.trim().characters.first.toUpperCase();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        if (semConexao) ...[
          const _AvisoSemConexao(),
          const SizedBox(height: 20),
        ],
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
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('perfil_editar_nome'),
            onPressed: () => _editarNome(context),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              'EDITAR NOME',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryGreen,
              side: const BorderSide(color: primaryGreen, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// O novo nome aparece na tela pelo stream do perfil; aqui só se confirma
  /// o sucesso, depois que a gravação terminou.
  Future<void> _editarNome(BuildContext context) async {
    // Atalho de usabilidade: a garantia de não gravar offline é do repositório
    if (semConexao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sem conexão. Conecte-se à internet para alterar o nome.'),
        ),
      );
      return;
    }
    final salvou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditarNomeDialog(nomeAtual: perfil.displayName),
    );
    if (salvou == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome de exibição atualizado.')),
      );
    }
  }
}

/// Edita somente `displayName` (KAN-29). Fecha com `true` apenas depois que o
/// Firestore confirmou a gravação; com `false` ao cancelar ou se nada mudou.
class _EditarNomeDialog extends StatefulWidget {
  final String nomeAtual;

  const _EditarNomeDialog({required this.nomeAtual});

  @override
  State<_EditarNomeDialog> createState() => _EditarNomeDialogState();
}

class _EditarNomeDialogState extends State<_EditarNomeDialog> {
  late final _controller = TextEditingController(text: widget.nomeAtual);
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;
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
    if (_salvando || !_formKey.currentState!.validate()) return;

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
      case UserProfileErrorCode.unknown:
        return 'Não foi possível salvar. O nome não foi alterado.';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);

    return PopScope(
      canPop: !_salvando,
      child: AlertDialog(
        backgroundColor: const Color(0xFF151E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Editar nome de exibição',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('editar_nome_campo'),
                controller: _controller,
                enabled: !_salvando,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                validator: _validar,
                onFieldSubmitted: (_) => _salvar(),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: primaryGreen,
                decoration: InputDecoration(
                  labelText: 'Nome de exibição',
                  labelStyle: const TextStyle(color: textMuted),
                  helperText: 'De 1 a 60 caracteres. O username não muda.',
                  helperStyle: const TextStyle(color: textMuted, fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFF0B111D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                  ),
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erro!,
                  key: const Key('editar_nome_erro'),
                  style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _salvando ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            key: const Key('editar_nome_salvar'),
            onPressed: _salvando ? null : _salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              disabledBackgroundColor: primaryGreen.withValues(alpha: 0.65),
              foregroundColor: const Color(0xFF062319),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF062319),
                    ),
                  )
                : const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AvisoSemConexao extends StatelessWidget {
  const _AvisoSemConexao();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('perfil_sem_conexao'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: Color(0xFFF59E0B), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sem conexão. Exibindo os últimos dados salvos neste aparelho; '
              'alterações ficam indisponíveis até a conexão voltar.',
              style: TextStyle(color: Color(0xFFF5D08A), fontSize: 12),
            ),
          ),
        ],
      ),
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
