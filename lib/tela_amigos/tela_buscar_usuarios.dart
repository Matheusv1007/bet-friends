import 'dart:async';

import 'package:flutter/material.dart';

import '../data/firestore/friendship_repository.dart';
import '../data/firestore/user_profile_repository.dart';
import '../models/friendship_model.dart';
import '../models/usuario_publico.dart';
import '../services/friendship_service.dart';
import '../services/user_search_service.dart';

/// Tela para buscar outros usuários cadastrados no BetFriends (RF-004),
/// enviar solicitações de amizade e aceitar solicitações pendentes (RF-005, RN-FRD-001, RN-FRD-005).
///
/// Diretrizes de Privacidade e Regras:
/// - Exibe apenas dados públicos: nome e @username (RN-PROF-002).
/// - Não exibe e-mail, saldos nem transações (RN-PROF-002).
/// - O próprio usuário logado nunca é exibido como resultado (RN-FRD-002).
/// - Utiliza o identificador estável `userId` internamente (RN-AUTH-006).
/// - Trata solicitações válidas, duplicadas, cruzadas e aceites (RN-FRD-001, RN-FRD-003, RN-FRD-004, RN-FRD-005).
class TelaBuscarUsuarios extends StatefulWidget {
  final UserSearchService? searchService;
  final FriendshipService? friendshipService;
  final Set<String>? solicitacoesRecebidas;

  const TelaBuscarUsuarios({
    super.key,
    this.searchService,
    this.friendshipService,
    this.solicitacoesRecebidas,
  });

  @override
  State<TelaBuscarUsuarios> createState() => _TelaBuscarUsuariosState();
}

class _TelaBuscarUsuariosState extends State<TelaBuscarUsuarios> {
  late final UserSearchService _searchService;
  late final FriendshipService _friendshipService;
  late final Set<String> _solicitacoesRecebidas;
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  String? _errorMessage;
  List<UsuarioPublico> _resultados = [];
  bool _pesquisaRealizada = false;
  final Set<String> _enviandoIds = {};
  final Map<String, FriendshipStatus> _statusAmizade = {};

  @override
  void initState() {
    super.initState();
    _searchService = widget.searchService ?? UserSearchService();
    _friendshipService = widget.friendshipService ?? FriendshipService();
    _solicitacoesRecebidas = widget.solicitacoesRecebidas != null
        ? Set.from(widget.solicitacoesRecebidas!)
        : <String>{};
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _aoDigitar(String valor) {
    _debounceTimer?.cancel();
    if (valor.trim().isEmpty) {
      setState(() {
        _resultados = [];
        _pesquisaRealizada = false;
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executarBusca(valor);
    });
  }

  Future<void> _executarBusca(String termo) async {
    final query = termo.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final usuarios = await _searchService.buscarUsuarios(query);
      if (!mounted) return;
      setState(() {
        _resultados = usuarios;
        _pesquisaRealizada = true;
        _isLoading = false;
      });
    } on UserProfileException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível buscar usuários. Tente novamente.';
        _isLoading = false;
      });
    }
  }

  Future<void> _enviarSolicitacao(UsuarioPublico usuario) async {
    if (_enviandoIds.contains(usuario.userId)) return;

    setState(() {
      _enviandoIds.add(usuario.userId);
    });

    try {
      final resultado = await _friendshipService.enviarSolicitacaoAmizade(usuario.userId);
      if (!mounted) return;

      setState(() {
        _statusAmizade[usuario.userId] = resultado.status;
      });

      final mensagem = resultado.autoAccepted
          ? 'Amizade aceita automaticamente com ${usuario.displayName}!'
          : 'Solicitação de amizade enviada para ${usuario.displayName}!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: const Color(0xFF00D084),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FriendshipException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível enviar a solicitação. Tente novamente.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviandoIds.remove(usuario.userId);
        });
      }
    }
  }

  Future<void> _aceitarSolicitacao(UsuarioPublico usuario) async {
    if (_enviandoIds.contains(usuario.userId)) return;

    setState(() {
      _enviandoIds.add(usuario.userId);
    });

    try {
      final resultado = await _friendshipService.aceitarSolicitacaoAmizade(usuario.userId);
      if (!mounted) return;

      setState(() {
        _solicitacoesRecebidas.remove(usuario.userId);
        _statusAmizade[usuario.userId] = resultado.status;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Agora você e ${usuario.displayName} são amigos!'),
          backgroundColor: const Color(0xFF00D084),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FriendshipException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível aceitar a solicitação. Tente novamente.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviandoIds.remove(usuario.userId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgScaffold = Color(0xFF0B111D);
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);

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
          'Buscar Usuários',
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
          child: Column(
            children: [
              // Barra de pesquisa
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  key: const Key('search_users_input'),
                  controller: _controller,
                  onChanged: _aoDigitar,
                  onSubmitted: _executarBusca,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou @username...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF00D084),
                      size: 20,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFF64748B),
                              size: 18,
                            ),
                            onPressed: () {
                              _controller.clear();
                              _aoDigitar('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: primaryGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Conteúdo: Inicial, Carregando, Erro, Vazio ou Lista
              Expanded(
                child: _buildConteudo(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('search_users_loading'),
          color: Color(0xFF00D084),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            key: const Key('search_users_error'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('search_users_retry_button'),
                onPressed: () => _executarBusca(_controller.text),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D084),
                  foregroundColor: const Color(0xFF062319),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_pesquisaRealizada) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_search_outlined,
                size: 54,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 14),
              const Text(
                'Encontre amigos no BetFriends',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Digite o nome ou @username para buscar outros jogadores cadastrados.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_resultados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            key: const Key('search_users_empty'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off,
                size: 46,
                color: Color(0xFF64748B),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nenhum usuário encontrado',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Não encontramos ninguém para "${_controller.text.trim()}".',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8E9CAB),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('search_users_list'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _resultados.length,
      itemBuilder: (context, index) {
        final usuario = _resultados[index];
        return _buildUserCard(usuario);
      },
    );
  }

  Widget _buildUserCard(UsuarioPublico usuario) {
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);

    return Container(
      key: Key('user_item_${usuario.userId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar com inicial
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF334155),
            child: Text(
              usuario.displayName.isNotEmpty
                  ? usuario.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Informações públicas (Nome e @Username)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  usuario.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  usuario.usernameComArroba,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),

          // Ação (Convidar / Aceitar / Amigos / Pendente)
          _buildBotaoAcao(usuario),
        ],
      ),
    );
  }

  Widget _buildBotaoAcao(UsuarioPublico usuario) {
    const primaryGreen = Color(0xFF00D084);
    final estaEnviando = _enviandoIds.contains(usuario.userId);
    final status = _statusAmizade[usuario.userId];

    if (estaEnviando) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2624),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primaryGreen.withValues(alpha: 0.3),
          ),
        ),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: primaryGreen,
          ),
        ),
      );
    }

    if (status == FriendshipStatus.accepted) {
      return Container(
        key: Key('btn_amigos_${usuario.userId}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primaryGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primaryGreen,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: primaryGreen, size: 16),
            SizedBox(width: 6),
            Text(
              'Amigos',
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (status == FriendshipStatus.pending) {
      return Container(
        key: Key('btn_pendente_${usuario.userId}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF64748B).withValues(alpha: 0.5),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, color: Color(0xFF94A3B8), size: 16),
            SizedBox(width: 6),
            Text(
              'Pendente',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // Se o usuário atual recebeu solicitação pendente deste jogador
    final recebeuSolicitacao = _solicitacoesRecebidas.contains(usuario.userId);
    if (recebeuSolicitacao) {
      return InkWell(
        key: Key('btn_aceitar_${usuario.userId}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _aceitarSolicitacao(usuario),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: primaryGreen,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, color: Color(0xFF062319), size: 16),
              SizedBox(width: 6),
              Text(
                'Aceitar',
                style: TextStyle(
                  color: Color(0xFF062319),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      key: Key('btn_convidar_${usuario.userId}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => _enviarSolicitacao(usuario),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2624),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primaryGreen.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1, color: primaryGreen, size: 16),
            SizedBox(width: 6),
            Text(
              'Convidar',
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
