import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/historico_de_desafios_repository.dart';
import '../data/firestore/partidas_repository.dart';
import '../models/challenge_model.dart';
import '../models/desafio_encerrado.dart';
import '../models/partida_model.dart';
import '../services/historico_de_desafios_service.dart';
import '../services/registro_de_erros.dart';
import '../widgets_home_page/apresentacao_desafios.dart';
import '../widgets_home_page/desafios_finalizados_secao.dart';
import '../widgets_home_page/detalhes_do_desafio_dialog.dart';

class TelaHistoricoDesafios extends StatefulWidget {
  final HistoricoDeDesafiosService? historicoService;
  final FirestorePartidasRepository? partidasRepository;
  final String? currentUserId;
  final Map<String, String> nomes;
  final Map<String, PartidaModel> partidas;

  const TelaHistoricoDesafios({
    super.key,
    this.historicoService,
    this.partidasRepository,
    required this.currentUserId,
    this.nomes = const {},
    this.partidas = const {},
  });

  @override
  State<TelaHistoricoDesafios> createState() => _TelaHistoricoDesafiosState();
}

class _TelaHistoricoDesafiosState extends State<TelaHistoricoDesafios> {
  late final HistoricoDeDesafiosService _service;
  late final FirestorePartidasRepository _partidasRepository;
  late final Map<String, PartidaModel> _partidas;
  final _itens = <ChallengeModel>[];
  final _ids = <String>{};
  final _partidasConsultadas = <String>{};
  CursorDoHistorico? _cursor;
  bool _carregando = false;
  bool _temMais = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _service = widget.historicoService ??
        context.read<HistoricoDeDesafiosService?>() ??
        HistoricoDeDesafiosService();
    _partidasRepository = widget.partidasRepository ?? FirestorePartidasRepository();
    _partidas = Map.of(widget.partidas);
    _carregar();
  }

  Future<void> _carregar() async {
    if (_carregando) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final pagina = await _service.buscarDoUsuarioAtual(cursor: _cursor);
      if (!mounted) return;
      // Uma resposta do cache não confirma nem uma lista vazia nem seu fim.
      if (pagina.doCache) {
        throw const HistoricoException(
          HistoricoErrorCode.unavailable,
          'Não foi possível confirmar o histórico. Verifique sua conexão e tente novamente.',
        );
      }
      setState(() {
        for (final item in pagina.itens) {
          if (_ids.add(item.id)) _itens.add(_apresentarDesafio(item));
        }
        _cursor = pagina.proximoCursor;
        _temMais = pagina.temMais;
      });
      for (final item in pagina.itens) {
        if (!_partidas.containsKey(item.matchId) &&
            _partidasConsultadas.add(item.matchId)) {
          _carregarPartida(item.matchId);
        }
      }
    } on HistoricoException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.code == HistoricoErrorCode.indiceAusente
          ? 'O histórico ainda não está disponível neste ambiente. É necessário configurar o índice de consulta.'
          : e.message);
    } catch (e, s) {
      registrarErro('Carregar histórico de desafios', e, s);
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível carregar o histórico. Tente novamente.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarPartida(String id) async {
    try {
      final partida = await _partidasRepository.buscarPorId(id);
      if (mounted && partida != null) setState(() => _partidas[id] = partida);
    } catch (e, s) {
      registrarErro('Carregar descrição da partida no histórico', e, s);
    }
  }

  // Adapta apenas os campos: resultado e efeito continuam sendo apresentados
  // pelo mesmo modelo, cards e diálogo utilizados pela Home.
  ChallengeModel _apresentarDesafio(DesafioEncerrado c) => ChallengeModel(
        id: c.id,
        challengerId: c.challengerId,
        challengedId: c.challengedId,
        participants: [c.challengerId, c.challengedId],
        matchId: c.matchId,
        challengerPrediction: Palpite.deValor(c.challengerPrediction)!,
        challengedPrediction: Palpite.deValor(c.challengedPrediction),
        amount: c.amount,
        status: StatusDesafio.deValor(c.status.valor)!,
        winnerId: c.winnerId,
        settledResult: Palpite.deValor(c.settledResult),
        cancelReason: c.cancelReason,
        createdAt: c.createdAt,
        acceptedAt: c.acceptedAt,
        startedAt: c.startedAt,
        finishedAt: c.finishedAt,
        updatedAt: c.finishedAt,
      );

  ApresentacaoDesafios _apresentar(Widget child) => ApresentacaoDesafios(
        currentUserId: widget.currentUserId,
        nomes: widget.nomes,
        partidas: _partidas,
        child: child,
      );

  void _detalhes(ChallengeModel desafio) {
    showDialog<void>(
      context: context,
      builder: (_) => _apresentar(DetalhesDoDesafioDialog(desafio: desafio)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B111D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B111D),
          foregroundColor: Colors.white,
          title: const Text('Histórico de desafios'),
        ),
        body: _apresentar(ListView(
          key: const Key('lista_historico_desafios'),
          padding: const EdgeInsets.all(16),
          children: [
            DesafiosFinalizadosSecao(
              desafios: _itens,
              currentUserId: widget.currentUserId,
              exibirCabecalho: false,
              onDetalhes: _detalhes,
            ),
            if (_carregando)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(
                  key: Key('historico_carregando'),
                  color: Color(0xFF00D084),
                )),
              )
            else if (_erro != null) ...[
              Text(_erro!, key: const Key('historico_erro'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8E9CAB))),
              TextButton(
                key: const Key('historico_tentar_novamente'),
                onPressed: _carregar,
                style: _estiloBotao,
                child: const Text('Tentar novamente'),
              ),
            ] else if (_itens.isEmpty && !_temMais)
              const Text('Você ainda não tem desafios encerrados',
                key: Key('historico_vazio'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E9CAB)))
            else if (_temMais)
              TextButton(
                key: const Key('historico_carregar_mais'),
                onPressed: _carregar,
                style: _estiloBotao,
                child: const Text('Carregar mais'),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Fim do histórico', key: Key('historico_fim'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8E9CAB))),
              ),
          ],
        )),
      );

  ButtonStyle get _estiloBotao => TextButton.styleFrom(
        foregroundColor: const Color(0xFF00D084),
        minimumSize: const Size(48, 48),
      );
}
