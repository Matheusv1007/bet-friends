import 'package:flutter/material.dart';

import '../data/firestore/friendship_repository.dart';
import '../models/friendship_model.dart';
import '../services/friendship_service.dart';
import '../services/registro_de_erros.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'avatar_de_iniciais.dart';
import 'tela_lista_amigos.dart';

/// Tela para visualização das comunicações de amizade pendentes recebidas (RF-005, RN-PROF-002).
///
/// Diretrizes de Privacidade e Negócio:
/// - Apresenta as propostas pendentes recebidas pelo usuário logado.
/// - Exibe exclusivamente os dados públicos permitidos do remetente (nome e @username - RN-PROF-002).
/// - Não expõe e-mail, saldos detalhados de BetCoins nem transações (RN-PROF-002).
/// - Disponibiliza ações de aceitar e recusar para cada pendência ativa.
/// - Ao resolver uma solicitação (aceite ou recusa), o item deixa de constar na lista de pendentes.
class TelaComunicacoesAmizade extends StatefulWidget {
  final FriendshipService? friendshipService;

  const TelaComunicacoesAmizade({super.key, this.friendshipService});

  @override
  State<TelaComunicacoesAmizade> createState() =>
      _TelaComunicacoesAmizadeState();
}

class _TelaComunicacoesAmizadeState extends State<TelaComunicacoesAmizade> {
  late final FriendshipService _friendshipService;

  bool _isLoading = true;
  String? _errorMessage;
  List<SolicitacaoAmizade> _solicitacoes = [];
  final Set<String> _processandoIds = {};
  Map<String, dynamic>? _nextCursor;
  bool _carregandoMais = false;

  @override
  void initState() {
    super.initState();
    _friendshipService = widget.friendshipService ?? FriendshipService();
    _carregarSolicitacoes();
  }

  Future<void> _carregarSolicitacoes({bool carregarMais = false}) async {
    if (_carregandoMais || (carregarMais && _nextCursor == null)) return;
    setState(() {
      if (carregarMais) {
        _carregandoMais = true;
      } else {
        _isLoading = true;
        _errorMessage = null;
      }
    });

    try {
      final resultado = await _friendshipService.listarSolicitacoesPendentes(
        cursor: carregarMais ? _nextCursor : null,
      );
      if (!mounted) return;
      setState(() {
        if (carregarMais) {
          final ids = _solicitacoes.map((item) => item.friendshipId).toSet();
          _solicitacoes.addAll(
            resultado.requests.where((item) => ids.add(item.friendshipId)),
          );
        } else {
          _solicitacoes = resultado.requests;
        }
        _nextCursor = resultado.nextCursor;
      });
    } catch (e, s) {
      final mensagem = e is FriendshipException
          ? e.message
          : 'Não foi possível carregar as solicitações. Verifique sua conexão.';
      if (e is! FriendshipException) {
        registrarErro('Carregar solicitações de amizade', e, s);
      }
      if (!mounted) return;
      if (carregarMais) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagem),
            backgroundColor: Colors.redAccent.shade700,
          ),
        );
      } else {
        setState(() => _errorMessage = mensagem);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _carregandoMais = false;
        });
      }
    }
  }

  Future<void> _aceitarSolicitacao(SolicitacaoAmizade solicitacao) async {
    final id = solicitacao.friendshipId;
    if (_processandoIds.contains(id)) return;

    setState(() {
      _processandoIds.add(id);
    });

    try {
      await _friendshipService.aceitarSolicitacaoAmizade(id);
      if (!mounted) return;

      // Solicitação resolvida deixa de aparecer como pendente
      setState(() {
        _solicitacoes.removeWhere((item) => item.friendshipId == id);
        _processandoIds.remove(id);
      });

      mostrarAviso(
        context,
        'Você e ${solicitacao.remetente.displayName} agora são amigos!',
        tom: Tom.sucesso,
      );
    } on FriendshipException catch (e) {
      if (!mounted) return;
      setState(() {
        _processandoIds.remove(id);
      });
      mostrarAviso(context, e.message, tom: Tom.destrutivo);
    } catch (e, s) {
      registrarErro('Aceitar solicitação de amizade', e, s);
      if (!mounted) return;
      setState(() {
        _processandoIds.remove(id);
      });
      mostrarAviso(
        context,
        'Não foi possível aceitar a solicitação. Tente novamente.',
        tom: Tom.destrutivo,
      );
    }
  }

  Future<void> _recusarSolicitacao(SolicitacaoAmizade solicitacao) async {
    final id = solicitacao.friendshipId;
    if (_processandoIds.contains(id)) return;

    setState(() {
      _processandoIds.add(id);
    });

    try {
      await _friendshipService.recusarSolicitacaoAmizade(id);
      if (!mounted) return;

      // Solicitação recusada deixa de aparecer como pendente
      setState(() {
        _solicitacoes.removeWhere((item) => item.friendshipId == id);
        _processandoIds.remove(id);
      });

      mostrarAviso(
        context,
        'Solicitação de ${solicitacao.remetente.displayName} recusada.',
      );
    } on FriendshipException catch (e) {
      if (!mounted) return;
      setState(() {
        _processandoIds.remove(id);
      });
      mostrarAviso(context, e.message, tom: Tom.destrutivo);
    } catch (e, s) {
      registrarErro('Recusar solicitação de amizade', e, s);
      if (!mounted) return;
      setState(() {
        _processandoIds.remove(id);
      });
      mostrarAviso(
        context,
        'Não foi possível recusar a solicitação. Tente novamente.',
        tom: Tom.destrutivo,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Solicitações de amizade'),
      leading: IconButton(
        key: const Key('btn_voltar_comunicacoes'),
        tooltip: 'Voltar',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          key: const Key('btn_ver_meus_amigos'),
          tooltip: 'Meus amigos',
          icon: const Icon(Icons.people_alt_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  TelaListaAmigos(friendshipService: _friendshipService),
            ),
          ),
        ),
        IconButton(
          key: const Key('btn_recarregar_comunicacoes'),
          tooltip: 'Recarregar',
          icon: const Icon(Icons.refresh),
          onPressed: _isLoading || _carregandoMais
              ? null
              : _carregarSolicitacoes,
        ),
      ],
    ),
    body: SafeArea(child: _buildBody()),
  );

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        key: Key('comunicacoes_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_errorMessage != null) {
      return SingleChildScrollView(
        key: const Key('comunicacoes_erro'),
        padding: const EdgeInsets.all(EspacosApp.e16),
        child: Column(
          children: [
            AvisoInline(_errorMessage!, Tom.destrutivo),
            BotaoSecundario(
              key: const Key('comunicacoes_tentar_novamente'),
              rotulo: 'Tentar novamente',
              onPressed: _carregarSolicitacoes,
            ),
          ],
        ),
      );
    }
    if (_solicitacoes.isEmpty && _nextCursor == null) {
      return const SingleChildScrollView(
        key: Key('comunicacoes_vazio'),
        padding: EdgeInsets.all(EspacosApp.e24),
        child: Column(
          children: [
            Icon(Icons.people_outline, color: CoresApp.textoSuave, size: 48),
            SizedBox(height: EspacosApp.e16),
            Text('Nenhuma pendência', style: TextoApp.corpoForte),
            SizedBox(height: EspacosApp.e8),
            Text(
              'Você não possui solicitações de amizade pendentes no momento.',
              style: TextoApp.secundario,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      key: const Key('lista_comunicacoes_amizade'),
      padding: const EdgeInsets.all(EspacosApp.e16),
      itemCount: _solicitacoes.length + (_nextCursor != null ? 1 : 0),
      separatorBuilder: (_, index) => const SizedBox(height: EspacosApp.e8),
      itemBuilder: (_, index) {
        if (index == _solicitacoes.length) {
          return BotaoTexto(
            key: const Key('comunicacoes_carregar_mais'),
            rotulo: 'Carregar mais',
            carregando: _carregandoMais,
            onPressed: () => _carregarSolicitacoes(carregarMais: true),
          );
        }
        return _buildCardSolicitacao(_solicitacoes[index]);
      },
    );
  }

  Widget _buildCardSolicitacao(SolicitacaoAmizade solicitacao) {
    final remetente = solicitacao.remetente;
    final processando = _processandoIds.contains(solicitacao.friendshipId);
    return Card(
      key: Key('card_solicitacao_${solicitacao.friendshipId}'),
      child: Padding(
        padding: const EdgeInsets.all(EspacosApp.e12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarDeIniciais(remetente.displayName),
                const SizedBox(width: EspacosApp.e12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        remetente.displayName,
                        key: Key('solicitacao_nome_${remetente.userId}'),
                        style: TextoApp.corpoForte,
                      ),
                      Text(
                        remetente.usernameComArroba,
                        key: Key('solicitacao_username_${remetente.userId}'),
                        style: TextoApp.secundario,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EspacosApp.e8),
            const TagDeStatus('Pendente', Tom.atencao),
            const SizedBox(height: EspacosApp.e8),
            Wrap(
              spacing: EspacosApp.e8,
              runSpacing: EspacosApp.e4,
              children: [
                BotaoPrimario(
                  key: Key('btn_aceitar_${remetente.userId}'),
                  rotulo: 'Aceitar',
                  pequeno: true,
                  carregando: processando,
                  onPressed: processando
                      ? null
                      : () => _aceitarSolicitacao(solicitacao),
                ),
                BotaoSecundario(
                  key: Key('btn_recusar_${remetente.userId}'),
                  rotulo: 'Recusar',
                  pequeno: true,
                  onPressed: processando
                      ? null
                      : () => _recusarSolicitacao(solicitacao),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
