import 'package:flutter/material.dart';

import '../data/firestore/friendship_repository.dart';
import '../models/friendship_model.dart';
import '../services/friendship_service.dart';

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

  const TelaComunicacoesAmizade({
    super.key,
    this.friendshipService,
  });

  @override
  State<TelaComunicacoesAmizade> createState() => _TelaComunicacoesAmizadeState();
}

class _TelaComunicacoesAmizadeState extends State<TelaComunicacoesAmizade> {
  late final FriendshipService _friendshipService;

  bool _isLoading = true;
  String? _errorMessage;
  List<SolicitacaoAmizade> _solicitacoes = [];
  final Set<String> _processandoIds = {};

  @override
  void initState() {
    super.initState();
    _friendshipService = widget.friendshipService ?? FriendshipService();
    _carregarSolicitacoes();
  }

  Future<void> _carregarSolicitacoes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resultado = await _friendshipService.listarSolicitacoesPendentes();
      if (!mounted) return;
      setState(() {
        _solicitacoes = resultado;
        _isLoading = false;
      });
    } on FriendshipException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível carregar as solicitações. Verifique sua conexão.';
        _isLoading = false;
      });
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snackbar_sucesso'),
          content: Text('Você e ${solicitacao.remetente.displayName} agora são amigos!'),
          backgroundColor: const Color(0xFF0F2624),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FriendshipException catch (e) {
      if (!mounted) return;
      setState(() {
        _processandoIds.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snackbar_erro'),
          content: Text(e.message),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processandoIds.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snackbar_erro'),
          content: const Text('Não foi possível aceitar a solicitação. Tente novamente.'),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
        ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snackbar_recusada'),
          content: Text('Solicitação de ${solicitacao.remetente.displayName} recusada.'),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FriendshipException catch (e) {
      if (!mounted) return;
      setState(() {
        _processandoIds.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snackbar_erro'),
          content: Text(e.message),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processandoIds.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snackbar_erro'),
          content: const Text('Não foi possível recusar a solicitação. Tente novamente.'),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgScaffold = Color(0xFF0B111D);
    const primaryGreen = Color(0xFF00D084);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: bgScaffold,
        elevation: 0,
        title: const Text(
          'COMUNICAÇÕES DE AMIZADE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          key: const Key('btn_voltar_comunicacoes'),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            key: const Key('btn_recarregar_comunicacoes'),
            icon: const Icon(Icons.refresh, color: primaryGreen, size: 22),
            onPressed: _carregarSolicitacoes,
            tooltip: 'Recarregar',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);

    if (_isLoading) {
      return const Center(
        key: Key('comunicacoes_loading'),
        child: CircularProgressIndicator(color: primaryGreen),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const Key('comunicacoes_erro'),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFF87171),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                key: const Key('comunicacoes_tentar_novamente'),
                onPressed: _carregarSolicitacoes,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF151E2E),
                  foregroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: primaryGreen.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_solicitacoes.isEmpty) {
      return Center(
        key: const Key('comunicacoes_vazio'),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF151E2E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: const Icon(
                  Icons.people_outline,
                  color: textMuted,
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Nenhuma pendência',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Você não possui solicitações de amizade pendentes no momento.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('lista_comunicacoes_amizade'),
      itemCount: _solicitacoes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _solicitacoes[index];
        return _buildCardSolicitacao(item);
      },
    );
  }

  Widget _buildCardSolicitacao(SolicitacaoAmizade solicitacao) {
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);
    final emProcessamento = _processandoIds.contains(solicitacao.friendshipId);

    final remetente = solicitacao.remetente;
    final primeiraLetra = remetente.displayName.isNotEmpty
        ? remetente.displayName.substring(0, 1).toUpperCase()
        : 'U';

    return Container(
      key: Key('card_solicitacao_${solicitacao.friendshipId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar com inicial
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF0F2624),
                child: Text(
                  primeiraLetra,
                  style: const TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Identificação pública do remetente (RN-PROF-002)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remetente.displayName,
                      key: Key('solicitacao_nome_${remetente.userId}'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      remetente.usernameComArroba,
                      key: Key('solicitacao_username_${remetente.userId}'),
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Tag de status Pendente
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2012),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'PENDENTE',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Ações: Aceitar e Recusar
          if (emProcessamento)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryGreen,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                // Botão Recusar
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('btn_recusar_${remetente.userId}'),
                    onPressed: () => _recusarSolicitacao(solicitacao),
                    icon: const Icon(Icons.close, size: 16, color: Color(0xFFF87171)),
                    label: const Text(
                      'Recusar',
                      style: TextStyle(
                        color: Color(0xFFF87171),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFFF87171).withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Botão Aceitar
                Expanded(
                  child: ElevatedButton.icon(
                    key: Key('btn_aceitar_${remetente.userId}'),
                    onPressed: () => _aceitarSolicitacao(solicitacao),
                    icon: const Icon(Icons.check, size: 16, color: Color(0xFF062319)),
                    label: const Text(
                      'Aceitar',
                      style: TextStyle(
                        color: Color(0xFF062319),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
