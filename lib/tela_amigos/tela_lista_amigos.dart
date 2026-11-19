import 'package:flutter/material.dart';

import '../data/firestore/friendship_repository.dart';
import '../models/usuario_publico.dart';
import '../services/friendship_service.dart';
import '../services/registro_de_erros.dart';
import '../tela_criar_desafio/tela_criar_desafio.dart';
import 'tela_buscar_usuarios.dart';
import 'tela_comunicacoes_amizade.dart';

/// Tela para visualização da lista de amigos aceitos (RF-006, RN-PROF-002, RN-FRD-001).
///
/// Critérios de Aceitação:
/// - Somente relações de amizade aceitas aparecem (RN-FRD-001);
/// - Nome e nome de usuário (@username) são exibidos (RN-PROF-002);
/// - E-mail NÃO é exibido (RN-PROF-002);
/// - Saldo detalhado de BetCoins NÃO é descrito (RN-PROF-002);
/// - Transações financeiras NÃO são exibidas (RN-PROF-002);
/// - Dados internos do usuário NÃO são expostos (RN-PROF-002).
class TelaListaAmigos extends StatefulWidget {
  final FriendshipService? friendshipService;

  const TelaListaAmigos({
    super.key,
    this.friendshipService,
  });

  @override
  State<TelaListaAmigos> createState() => _TelaListaAmigosState();
}

class _TelaListaAmigosState extends State<TelaListaAmigos> {
  late final FriendshipService _friendshipService;
  final TextEditingController _filtroController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<UsuarioPublico> _amigos = [];
  String _termoFiltro = '';

  @override
  void initState() {
    super.initState();
    _friendshipService = widget.friendshipService ?? FriendshipService();
    _carregarAmigos();
  }

  @override
  void dispose() {
    _filtroController.dispose();
    super.dispose();
  }

  Future<void> _carregarAmigos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resultado = await _friendshipService.listarAmigosAceitos();
      if (!mounted) return;
      setState(() {
        _amigos = resultado;
        _isLoading = false;
      });
    } on FriendshipException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e, s) {
      registrarErro('Carregar lista de amigos', e, s);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível carregar a lista de amigos. Verifique sua conexão.';
        _isLoading = false;
      });
    }
  }

  List<UsuarioPublico> get _amigosFiltrados {
    final termo = _termoFiltro.trim().toLowerCase();
    if (termo.isEmpty) return _amigos;

    return _amigos.where((a) {
      final nome = a.displayName.toLowerCase();
      final username = a.username.toLowerCase();
      return nome.contains(termo) || username.contains(termo);
    }).toList();
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        key: Key('loading_lista_amigos'),
        color: Color(0xFF00D084),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              key: Key('icone_erro_amigos'),
              color: Color(0xFFEF4444),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Falha ao carregar amigos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Erro inesperado ao consultar amigos.',
              key: const Key('texto_erro_amigos'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8E9CAB),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('btn_tentar_novamente_amigos'),
              onPressed: _carregarAmigos,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'TENTAR NOVAMENTE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D084),
                foregroundColor: const Color(0xFF062319),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Container(
          key: const Key('lista_amigos_vazia'),
          width: double.infinity,
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            color: const Color(0xFF151E2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2638),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00D084).withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.people_outline,
                  color: Color(0xFF00D084),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nenhum amigo adicionado',
                key: Key('titulo_lista_vazia'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Você ainda não possui amizades aceitas. Busque por outros usuários e envie solicitações para começar a desafiá-los!',
                key: Key('subtitulo_lista_vazia'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8E9CAB),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                key: const Key('btn_buscar_amigos_vazio'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TelaBuscarUsuarios(
                        friendshipService: _friendshipService,
                      ),
                    ),
                  ).then((_) => _carregarAmigos());
                },
                icon: const Icon(Icons.person_search, size: 18),
                label: const Text(
                  'BUSCAR AMIGOS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D084),
                  foregroundColor: const Color(0xFF062319),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemAmigo(UsuarioPublico amigo) {
    final inicial = amigo.displayName.trim().isNotEmpty
        ? amigo.displayName.trim()[0].toUpperCase()
        : 'U';

    return Container(
      key: Key('card_amigo_${amigo.userId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar com inicial
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1F2B3E),
              border: Border.all(
                color: const Color(0xFF00D084).withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                inicial,
                style: const TextStyle(
                  color: Color(0xFF00D084),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Nome e @username (RN-PROF-002: exclusivamente dados públicos)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  amigo.displayName,
                  key: Key('amigo_nome_${amigo.userId}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amigo.usernameComArroba,
                  key: Key('amigo_username_${amigo.userId}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E9CAB),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),

          // Botão Desafiar
          ElevatedButton.icon(
            key: Key('btn_desafiar_amigo_${amigo.userId}'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CriarDesafioScreen(),
                ),
              );
            },
            icon: const Icon(Icons.sports_kabaddi, size: 15),
            label: const Text(
              'DESAFIAR',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2624),
              foregroundColor: const Color(0xFF00D084),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: const Color(0xFF00D084).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    final amigosFiltrados = _amigosFiltrados;

    return Column(
      key: const Key('lista_amigos_conteudo'),
      children: [
        // Campo de busca local
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            key: const Key('campo_busca_amigos'),
            controller: _filtroController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Filtrar por nome ou @username...',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
              suffixIcon: _termoFiltro.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 18),
                      onPressed: () {
                        _filtroController.clear();
                        setState(() => _termoFiltro = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF151E2E),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                borderSide: const BorderSide(color: Color(0xFF00D084), width: 1.2),
              ),
            ),
            onChanged: (valor) {
              setState(() => _termoFiltro = valor);
            },
          ),
        ),

        // Contador de amigos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
          child: Row(
            children: [
              Text(
                'AMIGOS CONECTADOS',
                style: TextStyle(
                  color: const Color(0xFF8E9CAB).withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                key: const Key('badge_total_amigos'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D084).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF00D084).withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_amigos.length} amigo(s)',
                  style: const TextStyle(
                    color: Color(0xFF00D084),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Lista de amigos ou mensagem de filtro sem resultados
        Expanded(
          child: amigosFiltrados.isEmpty && _termoFiltro.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off, color: Color(0xFF64748B), size: 40),
                      const SizedBox(height: 10),
                      Text(
                        'Nenhum amigo encontrado para "$_termoFiltro"',
                        key: const Key('mensagem_filtro_vazio'),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  key: const Key('lista_amigos_scroll'),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: amigosFiltrados.length,
                  itemBuilder: (context, index) {
                    return _buildItemAmigo(amigosFiltrados[index]);
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B111D),
      appBar: AppBar(
        key: const Key('appbar_lista_amigos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('btn_voltar_amigos'),
          tooltip: 'Voltar',
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Meus Amigos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('btn_appbar_buscar_amigos'),
            tooltip: 'Buscar novos amigos',
            icon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF00D084)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TelaBuscarUsuarios(
                    friendshipService: _friendshipService,
                  ),
                ),
              ).then((_) => _carregarAmigos());
            },
          ),
          IconButton(
            key: const Key('btn_appbar_solicitacoes_amigos'),
            tooltip: 'Solicitações de amizade',
            icon: const Icon(Icons.mark_email_unread_outlined, color: Colors.white70),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TelaComunicacoesAmizade(
                    friendshipService: _friendshipService,
                  ),
                ),
              ).then((_) => _carregarAmigos());
            },
          ),
        ],
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
          child: RefreshIndicator(
            color: const Color(0xFF00D084),
            backgroundColor: const Color(0xFF151E2E),
            onRefresh: _carregarAmigos,
            child: _isLoading
                ? _buildLoading()
                : _errorMessage != null
                    ? _buildErro()
                    : _amigos.isEmpty
                        ? _buildVazio()
                        : _buildLista(),
          ),
        ),
      ),
    );
  }
}
