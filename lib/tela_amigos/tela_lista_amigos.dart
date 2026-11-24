import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/friendship_repository.dart';
import '../models/usuario_publico.dart';
import '../services/challenge_service.dart';
import '../services/friendship_service.dart';
import '../services/registro_de_erros.dart';
import '../services/user_search_service.dart';
import '../tela_criar_desafio/tela_criar_desafio.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'avatar_de_iniciais.dart';
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

  const TelaListaAmigos({super.key, this.friendshipService});

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

  bool _remocaoEmAndamento = false;

  Future<void> _removerAmizade(UsuarioPublico amigo) async {
    if (_remocaoEmAndamento) return;
    setState(() => _remocaoEmAndamento = true);
    try {
      var respostaEnviada = false;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remover amizade?'),
          content: Text(
            'Deseja remover a amizade com ${amigo.displayName}? '
            'Vocês não poderão se desafiar até voltarem a ser amigos. '
            'O histórico de desafios será mantido.',
          ),
          actions: [
            TextButton(
              key: const Key('cancelar_remocao_amizade'),
              onPressed: () {
                if (respostaEnviada) return;
                respostaEnviada = true;
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              key: const Key('confirmar_remocao_amizade'),
              onPressed: () {
                if (respostaEnviada) return;
                respostaEnviada = true;
                Navigator.pop(context, true);
              },
              child: const Text('Remover amizade'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
      await _friendshipService.removerAmizade(amigo.userId);
      if (!mounted) return;
      setState(() {
        _amigos = _amigos.where((item) => item.userId != amigo.userId).toList();
      });
      mostrarAviso(context, 'Amizade removida com sucesso.', tom: Tom.sucesso);
    } on FriendshipException catch (e) {
      if (!mounted) return;
      mostrarAviso(context, e.message, tom: Tom.destrutivo);
    } catch (e, s) {
      registrarErro('remover amizade na lista', e, s);
      if (!mounted) return;
      mostrarAviso(
        context,
        'Não foi possível remover a amizade. Tente novamente.',
        tom: Tom.destrutivo,
      );
    } finally {
      if (mounted) setState(() => _remocaoEmAndamento = false);
    }
  }

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

  Widget _buildLoading() => const Center(
    child: CircularProgressIndicator(key: Key('loading_lista_amigos')),
  );

  void _buscarAmigos() {
    final searchService = context.read<UserSearchService?>();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => TelaBuscarUsuarios(
              friendshipService: _friendshipService,
              searchService: searchService,
            ),
          ),
        )
        .then((_) {
          if (mounted) _carregarAmigos();
        });
  }

  Widget _buildErro() => SingleChildScrollView(
    padding: const EdgeInsets.all(EspacosApp.e24),
    child: Column(
      children: [
        const Icon(
          Icons.error_outline,
          key: Key('icone_erro_amigos'),
          color: CoresApp.destrutivo,
          size: 40,
        ),
        const SizedBox(height: EspacosApp.e16),
        const Text('Falha ao carregar amigos', style: TextoApp.corpoForte),
        Text(
          _errorMessage ?? 'Erro inesperado ao consultar amigos.',
          key: const Key('texto_erro_amigos'),
          style: TextoApp.secundario,
        ),
        BotaoSecundario(
          key: const Key('btn_tentar_novamente_amigos'),
          rotulo: 'Tentar novamente',
          onPressed: _carregarAmigos,
        ),
      ],
    ),
  );

  Widget _buildVazio() => SingleChildScrollView(
    key: const Key('lista_amigos_vazia'),
    padding: const EdgeInsets.all(EspacosApp.e24),
    child: Column(
      children: [
        const Icon(Icons.people_outline, color: CoresApp.textoSuave, size: 48),
        const SizedBox(height: EspacosApp.e16),
        const Text(
          'Nenhum amigo adicionado',
          key: Key('titulo_lista_vazia'),
          style: TextoApp.corpoForte,
        ),
        const SizedBox(height: EspacosApp.e8),
        const Text(
          'Você ainda não possui amizades aceitas. Busque por outros usuários e envie solicitações para começar a desafiá-los!',
          key: Key('subtitulo_lista_vazia'),
          style: TextoApp.secundario,
          textAlign: TextAlign.center,
        ),
        BotaoPrimario(
          key: const Key('btn_buscar_amigos_vazio'),
          rotulo: 'Buscar amigos',
          onPressed: _buscarAmigos,
        ),
      ],
    ),
  );

  Widget _buildItemAmigo(UsuarioPublico amigo) => Card(
    key: Key('card_amigo_${amigo.userId}'),
    child: Padding(
      padding: const EdgeInsets.all(EspacosApp.e12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarDeIniciais(amigo.displayName),
              const SizedBox(width: EspacosApp.e12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amigo.displayName,
                      key: Key('amigo_nome_${amigo.userId}'),
                      style: TextoApp.corpoForte,
                    ),
                    Text(
                      amigo.usernameComArroba,
                      key: Key('amigo_username_${amigo.userId}'),
                      style: TextoApp.secundario,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('btn_remover_amigo_${amigo.userId}'),
                tooltip: 'Mais opções',
                enabled: !_remocaoEmAndamento,
                icon: const Icon(Icons.more_horiz),
                onSelected: (_) => _removerAmizade(amigo),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'remover',
                    child: Text('Remover amizade'),
                  ),
                ],
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: BotaoSecundario(
              key: Key('btn_desafiar_amigo_${amigo.userId}'),
              rotulo: 'Desafiar',
              pequeno: true,
              onPressed: () {
                final service = context.read<ChallengeService?>();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CriarDesafioScreen(
                      preSelectedFriendId: amigo.userId,
                      preSelectedFriendName: amigo.displayName,
                      challengeService: service,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildLista() {
    final amigos = _amigosFiltrados;
    return Column(
      key: const Key('lista_amigos_conteudo'),
      children: [
        Padding(
          padding: const EdgeInsets.all(EspacosApp.e16),
          child: CampoDeTexto(
            key: const Key('campo_busca_amigos'),
            rotulo: 'Filtrar amigos',
            dica: 'Nome ou @username',
            controller: _filtroController,
            onChanged: (valor) => setState(() => _termoFiltro = valor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EspacosApp.e16),
          child: TituloDeSecao(
            'Amigos conectados',
            acao: TagDeStatus(
              '${_amigos.length} amigo(s)',
              Tom.neutro,
              key: const Key('badge_total_amigos'),
            ),
          ),
        ),
        Expanded(
          child: amigos.isEmpty
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(EspacosApp.e16),
                    child: Text(
                      'Nenhum amigo encontrado para "$_termoFiltro"',
                      key: const Key('mensagem_filtro_vazio'),
                      style: TextoApp.secundario,
                    ),
                  ),
                )
              : ListView.builder(
                  key: const Key('lista_amigos_scroll'),
                  padding: const EdgeInsets.all(EspacosApp.e16),
                  itemCount: amigos.length,
                  itemBuilder: (_, index) => _buildItemAmigo(amigos[index]),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      key: const Key('appbar_lista_amigos'),
      leading: IconButton(
        key: const Key('btn_voltar_amigos'),
        tooltip: 'Voltar',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Meus amigos'),
      actions: [
        IconButton(
          key: const Key('btn_appbar_buscar_amigos'),
          tooltip: 'Buscar novos amigos',
          icon: const Icon(Icons.person_add_alt_1_outlined),
          onPressed: _buscarAmigos,
        ),
        IconButton(
          key: const Key('btn_appbar_solicitacoes_amigos'),
          tooltip: 'Solicitações de amizade',
          icon: const Icon(Icons.mark_email_unread_outlined),
          onPressed: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => TelaComunicacoesAmizade(
                      friendshipService: _friendshipService,
                    ),
                  ),
                )
                .then((_) {
                  if (mounted) _carregarAmigos();
                });
          },
        ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
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
  );
}
