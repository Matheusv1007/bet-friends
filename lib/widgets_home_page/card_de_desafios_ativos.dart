import 'package:flutter/material.dart';
import '../data/firestore/partidas_repository.dart';
import 'package:provider/provider.dart';
import '../models/partida_model.dart';
import '../provider/partidas_provider.dart';
import '../services/registro_de_erros.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'apresentacao_desafios.dart';

import '../data/firestore/challenge_repository.dart';
import '../models/challenge_model.dart';
import '../services/challenge_service.dart';
import '../tela_criar_desafio/modal_aceitar_desafio.dart';
import '../tela_criar_desafio/tela_criar_desafio.dart';
import '../tela_historico/tela_historico_desafios.dart';
import 'desafios_em_aberto_secao.dart';
import 'desafios_enviados_card.dart';
import 'desafios_finalizados_secao.dart';
import 'desafios_recebidos_card.dart';
import 'desafios_vazios.dart';
import 'detalhes_do_desafio_dialog.dart';

/// Widget de resumo de desafios na Home (D-003, Plano Mestre v3.2).
///
/// Apresenta dados reais agregados a partir do [ChallengeService]:
/// - Desafios recebidos aguardando resposta (destacados);
/// - Desafios enviados aguardando o amigo, que o criador pode cancelar;
/// - Desafios em aberto (aceitos, em andamento, aguardando resultado);
/// - Desafios recentemente finalizados (destacados);
/// - Estados explícitos de carregamento, falha e lista vazia.
class DesafiosAtivosWidget extends StatefulWidget {
  final List<ChallengeModel>? desafios;
  final String? currentUserId;
  final ChallengeService? challengeService;
  final bool carregando;
  final bool erro;
  final VoidCallback? onTentarNovamente;

  /// Chave da seção Recebidos, para o aviso de pendência rolar até ela.
  final GlobalKey? chaveRecebidos;

  const DesafiosAtivosWidget({
    super.key,
    this.desafios,
    this.currentUserId,
    this.challengeService,
    this.carregando = false,
    this.erro = false,
    this.onTentarNovamente,
    this.chaveRecebidos,
  });

  @override
  State<DesafiosAtivosWidget> createState() => _DesafiosAtivosWidgetState();
}

class _DesafiosAtivosWidgetState extends State<DesafiosAtivosWidget>
    with WidgetsBindingObserver {
  final _nomes = <String, String>{};
  final _cancelando = <String>{};
  final _recusando = <String>{};
  final _partidas = <String, PartidaModel>{};
  final _consultadas = <String>{};
  final _uidsConsultados = <String>{};
  bool _carregandoNomes = false;

  Set<String> get _uidsDesconhecidos => {
    for (final c in widget.desafios ?? <ChallengeModel>[])
      for (final uid in [c.challengerId, c.challengedId])
        if (uid != widget.currentUserId && !_nomes.containsKey(uid)) uid,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregarNomes();
  }

  @override
  void didUpdateWidget(covariant DesafiosAtivosWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUserId != widget.currentUserId) {
      _nomes.clear();
      _uidsConsultados.clear();
    }
    if (_uidsDesconhecidos.any((uid) => !_uidsConsultados.contains(uid))) {
      _carregarNomes();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _carregarNomes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _carregarNomes() async {
    final servico = widget.challengeService;
    if (_carregandoNomes || servico == null) return;
    final usuario = widget.currentUserId;
    _carregandoNomes = true;
    _uidsConsultados.addAll(_uidsDesconhecidos);
    try {
      final amigos = await servico.listarAmigosAceitos();
      if (!mounted || usuario != widget.currentUserId) return;
      setState(() {
        // Preserva nomes públicos já vistos mesmo após a remoção da amizade.
        for (final amigo in amigos) {
          if (amigo.displayName.trim().isNotEmpty) {
            _nomes[amigo.uid] = amigo.displayName;
          }
        }
      });
    } catch (e, s) {
      registrarErro('Carregar nomes dos adversários', e, s);
    } finally {
      _carregandoNomes = false;
      if (mounted) {
        setState(() {});
        // Desafios podem ter chegado enquanto a consulta estava em andamento.
        if (_uidsDesconhecidos.any((uid) => !_uidsConsultados.contains(uid))) {
          _carregarNomes();
        }
      }
    }
  }

  Future<void> _carregarPartida(String id) async {
    try {
      final partida = await FirestorePartidasRepository().buscarPorId(id);
      if (partida != null && mounted) {
        setState(() => _partidas[id] = partida);
      }
    } catch (e, s) {
      registrarErro('Carregar descrição da partida', e, s);
    }
  }

  ApresentacaoDesafios _apresentar(Widget child) => ApresentacaoDesafios(
    currentUserId: widget.currentUserId, nomes: _nomes,
    partidas: _partidas, child: child,
  );

  void _exibirDetalhesDesafio(BuildContext context, ChallengeModel c) {
    showDialog(
      context: context,
      builder: (ctx) => _apresentar(DetalhesDoDesafioDialog(desafio: c)),
    );
  }

  /// Pergunta "sim ou não" com a ação destrutiva à direita; `true` só se confirmou.
  Future<bool> _confirmar(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    required String manter,
    required String confirmar,
    required Key chaveManter,
    required Key chaveConfirmar,
  }) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem, style: TextoApp.corpo.copyWith(color: CoresApp.textoSuave)),
        actions: [
          TextButton(
            key: chaveManter,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(manter),
          ),
          TextButton(
            key: chaveConfirmar,
            style: TextButton.styleFrom(foregroundColor: CoresApp.destrutivo),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmar),
          ),
        ],
      ),
    );
    return confirmou == true;
  }

  /// Pede confirmação e cancela um desafio pendente criado pelo usuário; o backend libera a reserva.
  Future<void> _confirmarCancelamento(BuildContext context, ChallengeModel c) async {
    if (!_cancelando.add(c.id)) return;
    setState(() {});
    try {
      final confirmou = await _confirmar(
        context,
        titulo: 'Cancelar desafio?',
        mensagem: 'As ${c.amount} BetCoins reservadas voltam para o seu saldo disponível.',
        manter: 'Manter',
        confirmar: 'Cancelar desafio',
        chaveManter: const Key('btn_manter_desafio'),
        chaveConfirmar: const Key('btn_confirmar_cancelamento'),
      );
      if (!confirmou || !context.mounted) return;

      var mensagem = 'Desafio cancelado. Suas BetCoins foram liberadas.';
      var tom = Tom.sucesso;
      try {
        await (widget.challengeService ?? ChallengeService()).cancelarDesafio(challengeId: c.id);
      } on ChallengeException catch (e) {
        mensagem = e.message;
        tom = Tom.destrutivo;
      }
      if (context.mounted) mostrarAviso(context, mensagem, tom: tom);
    } finally {
      if (mounted) setState(() => _cancelando.remove(c.id));
    }
  }

  /// Pede confirmação e só então recusa o desafio recebido, pela mesma rotina do modal de aceite.
  Future<void> _confirmarRecusa(BuildContext context, ChallengeModel c, String nome) async {
    if (!_recusando.add(c.id)) return;
    setState(() {});
    try {
      final confirmou = await _confirmar(
        context,
        titulo: 'Recusar desafio?',
        mensagem: 'O desafio de $nome será recusado e as BetCoins reservadas por ele voltam para o saldo dele.',
        manter: 'Voltar',
        confirmar: 'Recusar',
        chaveManter: const Key('btn_manter_recebido'),
        chaveConfirmar: const Key('btn_confirmar_recusa'),
      );
      if (!confirmou || !context.mounted) return;
      await recusarDesafioComAviso(
        context,
        widget.challengeService ?? ChallengeService(),
        c,
      );
    } finally {
      if (mounted) setState(() => _recusando.remove(c.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = widget.desafios;
    final partidasProvider = context.watch<PartidasProvider?>();
    for (final partida in partidasProvider?.partidas ?? <PartidaModel>[]) {
      _partidas[partida.id] = partida;
    }
    for (final c in lista ?? <ChallengeModel>[]) {
      if (!_partidas.containsKey(c.matchId) && _consultadas.add(c.matchId)) {
        _carregarPartida(c.matchId);
      }
    }
    if (widget.erro) {
      return Container(
        key: const Key('home_desafios_erro'),
        padding: const EdgeInsets.all(EspacosApp.e16),
        decoration: const BoxDecoration(
          color: CoresApp.superficie1,
          borderRadius: RaiosApp.bordaCartao,
        ),
        child: Column(
          children: [
            Text(
              'Não foi possível carregar os desafios.',
              textAlign: TextAlign.center,
              style: TextoApp.corpo.copyWith(color: CoresApp.texto),
            ),
            const SizedBox(height: EspacosApp.e8),
            BotaoSecundario(
              rotulo: 'Tentar novamente',
              icone: Icons.refresh,
              pequeno: true,
              onPressed: widget.onTentarNovamente,
            ),
          ],
        ),
      );
    }
    if (widget.carregando || lista == null) {
      return const Padding(
        padding: EdgeInsets.all(EspacosApp.e24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final pendentesRecebidos = lista.where((c) {
      final isPending = c.status == StatusDesafio.pending;
      final isChallenged = widget.currentUserId == null || c.challengedId == widget.currentUserId;
      return isPending && isChallenged;
    }).toList();

    final desafiosEmAberto = lista.where((c) {
      return c.status == StatusDesafio.accepted ||
          c.status == StatusDesafio.inProgress ||
          c.status == StatusDesafio.waitingResult;
    }).toList();

    final desafiosFinalizados = lista.where((c) {
      return c.status == StatusDesafio.finished || c.status.isTerminal;
    }).toList();

    final pendentesEnviados = lista.where((c) {
      return c.status == StatusDesafio.pending &&
          widget.currentUserId != null &&
          c.challengerId == widget.currentUserId;
    }).toList();

    // Se a lista estiver vazia
    if (lista.isEmpty) {
      return DesafiosVazios(
        onCriarDesafio: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CriarDesafioScreen(
                challengeService: widget.challengeService,
              ),
            ),
          );
        },
      );
    }

    return _apresentar(Builder(builder: (context) {
      final dados = ApresentacaoDesafios.of(context)!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_uidsDesconhecidos.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: BotaoTexto(
                key: const Key('home_atualizar_nomes'),
                rotulo: _carregandoNomes ? 'Atualizando nomes...' : 'Atualizar nomes',
                icone: Icons.refresh,
                pequeno: true,
                onPressed: _carregandoNomes ? null : _carregarNomes,
              ),
            ),
          // 1. DESTAQUE: DESAFIOS RECEBIDOS AGUARDANDO RESPOSTA
          if (pendentesRecebidos.isNotEmpty)
            KeyedSubtree(
              key: widget.chaveRecebidos,
              child: DesafiosRecebidosCard(
                desafios: pendentesRecebidos,
                recusando: _recusando,
                onResponder: (c) {
                  ModalAceitarDesafio.exibir(
                    context: context,
                    desafio: c,
                    nomeCriador: dados.nome(c.challengerId),
                    descricaoPartida: dados.partida(c.matchId),
                    challengeService: widget.challengeService,
                  );
                },
                onRecusar: (c) => _confirmarRecusa(context, c, dados.nome(c.challengerId)),
              ),
            ),
          // 1b. DESAFIOS ENVIADOS AGUARDANDO O AMIGO (o criador ainda pode cancelar)
          if (pendentesEnviados.isNotEmpty)
            DesafiosEnviadosCard(
              desafios: pendentesEnviados,
              cancelando: _cancelando,
              onCancelar: (c) => _confirmarCancelamento(context, c),
            ),
          // 2. DESAFIOS EM ABERTO
          DesafiosEmAbertoSecao(
            desafios: desafiosEmAberto,
            onDetalhes: (c) => _exibirDetalhesDesafio(context, c),
          ),
          // 3. DESTAQUE: DESAFIOS RECENTEMENTE FINALIZADOS
          if (desafiosFinalizados.isNotEmpty)
            DesafiosFinalizadosSecao(
              desafios: desafiosFinalizados,
              currentUserId: widget.currentUserId,
              onDetalhes: (c) => _exibirDetalhesDesafio(context, c),
              onVerTodos: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TelaHistoricoDesafios(
                    currentUserId: widget.currentUserId,
                    nomes: _nomes,
                    partidas: _partidas,
                  ),
                ),
              ),
            ),
        ],
      );
    }));
  }
}
