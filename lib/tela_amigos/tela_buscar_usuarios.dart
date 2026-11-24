import 'dart:async';

import 'package:flutter/material.dart';

import '../data/firestore/friendship_repository.dart';
import '../data/firestore/user_profile_repository.dart';
import '../models/friendship_model.dart';
import '../models/usuario_publico.dart';
import '../services/friendship_service.dart';
import '../services/registro_de_erros.dart';
import '../services/user_search_service.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'avatar_de_iniciais.dart';
import 'tela_comunicacoes_amizade.dart';

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
  /// Mesmo mínimo do backend (`USERNAME_MINIMO`): termos menores não são buscados.
  static const int _minimoDaBusca = 3;

  late final UserSearchService _searchService;
  late final FriendshipService _friendshipService;
  late final Set<String> _solicitacoesRecebidas;
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  int _requisicaoBusca = 0;

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
    _requisicaoBusca++;
    _debounceTimer?.cancel();
    // Abaixo do tamanho de um username o backend devolve lista vazia (A-05);
    // nem chamamos, e a tela volta à orientação em vez de "nenhum usuário".
    if (valor.trim().replaceFirst('@', '').length < _minimoDaBusca) {
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
    final requisicao = ++_requisicaoBusca;
    final query = termo.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final usuarios = await _searchService.buscarUsuarios(query);
      if (!mounted || requisicao != _requisicaoBusca) return;
      setState(() {
        _resultados = usuarios;
        _pesquisaRealizada = true;
        _isLoading = false;
      });
    } on UserProfileException catch (e) {
      if (!mounted || requisicao != _requisicaoBusca) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e, s) {
      registrarErro('Buscar usuários', e, s);
      if (!mounted || requisicao != _requisicaoBusca) return;
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
      final resultado = await _friendshipService.enviarSolicitacaoAmizade(
        usuario.userId,
      );
      if (!mounted) return;

      setState(() {
        _statusAmizade[usuario.userId] = resultado.status;
      });

      final mensagem = resultado.autoAccepted
          ? 'Amizade aceita automaticamente com ${usuario.displayName}!'
          : 'Solicitação de amizade enviada para ${usuario.displayName}!';

      mostrarAviso(context, mensagem, tom: Tom.sucesso);
    } on FriendshipException catch (e) {
      if (!mounted) return;
      mostrarAviso(context, e.message, tom: Tom.destrutivo);
    } catch (e, s) {
      registrarErro('Enviar solicitação de amizade', e, s);
      if (!mounted) return;
      mostrarAviso(
        context,
        'Não foi possível enviar a solicitação. Tente novamente.',
        tom: Tom.destrutivo,
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
      final resultado = await _friendshipService.aceitarSolicitacaoAmizade(
        usuario.userId,
      );
      if (!mounted) return;

      setState(() {
        _solicitacoesRecebidas.remove(usuario.userId);
        _statusAmizade[usuario.userId] = resultado.status;
      });

      mostrarAviso(
        context,
        'Agora você e ${usuario.displayName} são amigos!',
        tom: Tom.sucesso,
      );
    } on FriendshipException catch (e) {
      if (!mounted) return;
      mostrarAviso(context, e.message, tom: Tom.destrutivo);
    } catch (e, s) {
      registrarErro('Aceitar solicitação na busca de usuários', e, s);
      if (!mounted) return;
      mostrarAviso(
        context,
        'Não foi possível aceitar a solicitação. Tente novamente.',
        tom: Tom.destrutivo,
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Buscar usuários'),
      leading: IconButton(
        tooltip: 'Voltar',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          key: const Key('btn_abrir_solicitacoes_amizade'),
          tooltip: 'Solicitações de amizade',
          icon: const Icon(Icons.mark_email_unread_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TelaComunicacoesAmizade(
                friendshipService: _friendshipService,
              ),
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(EspacosApp.e16),
            child: CampoDeTexto(
              key: const Key('search_users_input'),
              rotulo: 'Buscar por nome ou @username',
              dica: 'Digite ao menos 3 letras',
              controller: _controller,
              onChanged: _aoDigitar,
              onSubmitted: _executarBusca,
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(child: _buildConteudo()),
        ],
      ),
    ),
  );

  Widget _buildConteudo() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('search_users_loading')),
      );
    }
    if (_errorMessage != null) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(EspacosApp.e24),
          child: Column(
            key: const Key('search_users_error'),
            children: [
              AvisoInline(_errorMessage!, Tom.destrutivo),
              BotaoSecundario(
                key: const Key('search_users_retry_button'),
                rotulo: 'Tentar novamente',
                onPressed: () => _executarBusca(_controller.text),
              ),
            ],
          ),
        ),
      );
    }
    if (!_pesquisaRealizada || _resultados.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          key: _pesquisaRealizada ? const Key('search_users_empty') : null,
          padding: const EdgeInsets.all(EspacosApp.e24),
          child: Column(
            children: [
              const Icon(
                Icons.person_search_outlined,
                size: 48,
                color: CoresApp.textoSuave,
              ),
              const SizedBox(height: EspacosApp.e16),
              Text(
                _pesquisaRealizada
                    ? 'Nenhum usuário encontrado'
                    : 'Encontre amigos no BetFriends',
                style: TextoApp.corpoForte,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: EspacosApp.e8),
              Text(
                _pesquisaRealizada
                    ? 'Não encontramos ninguém para "${_controller.text.trim()}".'
                    : 'Digite ao menos 3 letras do @username para buscar outros jogadores cadastrados.',
                style: TextoApp.secundario,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      key: const Key('search_users_list'),
      padding: const EdgeInsets.all(EspacosApp.e16),
      itemCount: _resultados.length,
      itemBuilder: (_, index) => _buildUserCard(_resultados[index]),
    );
  }

  Widget _buildUserCard(UsuarioPublico usuario) => Card(
    key: Key('user_item_${usuario.userId}'),
    child: Padding(
      padding: const EdgeInsets.all(EspacosApp.e12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarDeIniciais(usuario.displayName),
              const SizedBox(width: EspacosApp.e12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usuario.displayName, style: TextoApp.corpoForte),
                    Text(usuario.usernameComArroba, style: TextoApp.secundario),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _buildBotaoAcao(usuario),
          ),
        ],
      ),
    ),
  );

  Widget _buildBotaoAcao(UsuarioPublico usuario) {
    final status = _statusAmizade[usuario.userId];
    if (status == FriendshipStatus.accepted) {
      return TagDeStatus(
        'Amigos',
        Tom.sucesso,
        key: Key('btn_amigos_${usuario.userId}'),
      );
    }
    if (status == FriendshipStatus.pending) {
      return TagDeStatus(
        'Pendente',
        Tom.neutro,
        key: Key('btn_pendente_${usuario.userId}'),
      );
    }
    final recebeu = _solicitacoesRecebidas.contains(usuario.userId);
    return BotaoSecundario(
      key: Key('btn_${recebeu ? 'aceitar' : 'convidar'}_${usuario.userId}'),
      rotulo: recebeu ? 'Aceitar' : 'Convidar',
      pequeno: true,
      carregando: _enviandoIds.contains(usuario.userId),
      onPressed: () =>
          recebeu ? _aceitarSolicitacao(usuario) : _enviarSolicitacao(usuario),
    );
  }
}
