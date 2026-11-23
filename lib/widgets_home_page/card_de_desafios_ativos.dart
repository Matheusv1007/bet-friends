import 'package:flutter/material.dart';
import '../data/firestore/partidas_repository.dart';
import 'package:provider/provider.dart';
import '../models/partida_model.dart';
import '../provider/partidas_provider.dart';
import '../services/registro_de_erros.dart';
import 'apresentacao_desafios.dart';

import '../data/firestore/challenge_repository.dart';
import '../models/challenge_model.dart';
import '../services/challenge_service.dart';
import '../tela_criar_desafio/modal_aceitar_desafio.dart';
import '../tela_criar_desafio/tela_criar_desafio.dart';
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

  const DesafiosAtivosWidget({
    super.key,
    this.desafios,
    this.currentUserId,
    this.challengeService,
    this.carregando = false,
    this.erro = false,
    this.onTentarNovamente,
  });

  @override
  State<DesafiosAtivosWidget> createState() => _DesafiosAtivosWidgetState();
}

class _DesafiosAtivosWidgetState extends State<DesafiosAtivosWidget>
    with WidgetsBindingObserver {
  final _nomes = <String, String>{};
  final _cancelando = <String>{};
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

  /// Pede confirmação e cancela um desafio pendente criado pelo usuário; o backend libera a reserva.
  Future<void> _confirmarCancelamento(BuildContext context, ChallengeModel c) async {
    if (!_cancelando.add(c.id)) return;
    setState(() {});
    try {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Cancelar desafio?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "As ${c.amount} BetCoins reservadas voltam para o seu saldo disponível.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            key: const Key('btn_manter_desafio'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Manter", style: TextStyle(color: Color(0xFF00D084))),
          ),
          TextButton(
            key: const Key('btn_confirmar_cancelamento'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Cancelar desafio", style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmou != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    var mensagem = 'Desafio cancelado. Suas BetCoins foram liberadas.';
    var cor = const Color(0xFF00D084);
    try {
      await (widget.challengeService ?? ChallengeService()).cancelarDesafio(challengeId: c.id);
    } on ChallengeException catch (e) {
      mensagem = e.message;
      cor = const Color(0xFFEF4444);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        duration: const Duration(seconds: 3),
      ),
    );
    } finally {
      if (mounted) setState(() => _cancelando.remove(c.id));
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
      return Column(children: [
        const Text('Não foi possível carregar os desafios.',
          style: TextStyle(color: Colors.white)),
        TextButton(onPressed: widget.onTentarNovamente,
          child: const Text('Tentar novamente')),
      ]);
    }
    if (widget.carregando || lista == null) {
      return const Center(child: CircularProgressIndicator());
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

    return _apresentar(Builder(builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_uidsDesconhecidos.isNotEmpty)
          TextButton(
            key: const Key('home_atualizar_nomes'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00D084),
              minimumSize: const Size(48, 48),
            ),
            onPressed: _carregandoNomes ? null : _carregarNomes,
            child: Text(_carregandoNomes ? 'Atualizando nomes...' : 'Atualizar nomes'),
          ),
        // 1. DESTAQUE: DESAFIOS RECEBIDOS AGUARDANDO RESPOSTA
        if (pendentesRecebidos.isNotEmpty)
          DesafiosRecebidosCard(
            desafios: pendentesRecebidos,
            onResponder: (c) {
              ModalAceitarDesafio.exibir(
                context: context,
                desafio: c,
                nomeCriador: _apresentar(const SizedBox()).nome(c.challengerId),
                descricaoPartida: _apresentar(const SizedBox()).partida(c.matchId),
                challengeService: widget.challengeService,
              );
            },
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
          ),
      ],
    )));
  }
}
