import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/historico_de_desafios_repository.dart';
import '../data/firestore/partidas_repository.dart';
import '../models/challenge_model.dart';
import '../models/desafio_encerrado.dart';
import '../models/partida_model.dart';
import '../services/historico_de_desafios_service.dart';
import '../services/registro_de_erros.dart';
import '../tela_extrato/formato_betcoins.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import '../widgets_home_page/apresentacao_desafios.dart';
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
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Histórico de desafios'),
        ),
        body: SafeArea(
          child: _apresentar(ListView(
            key: const Key('lista_historico_desafios'),
            padding: const EdgeInsets.fromLTRB(
              EspacosApp.margemDaTela, EspacosApp.e8, EspacosApp.margemDaTela, EspacosApp.e32,
            ),
            children: [
              if (_itens.isNotEmpty) ...[
                Semantics(
                  header: true,
                  child: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'FINALIZADOS', style: TextoApp.secao),
                    if (!_temMais)
                      TextSpan(
                        text: '   ${_itens.length} ${_itens.length == 1 ? 'desafio' : 'desafios'}',
                        style: TextoApp.secundario.copyWith(fontSize: 12),
                      ),
                  ])),
                ),
                const SizedBox(height: EspacosApp.e8),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < _itens.length; i++) ...[
                        if (i > 0) const Divider(),
                        _LinhaDoHistorico(
                          desafio: _itens[i],
                          onTap: () => _detalhes(_itens[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_carregando)
                const Padding(
                  padding: EdgeInsets.all(EspacosApp.e24),
                  child: Center(child: CircularProgressIndicator(key: Key('historico_carregando'))),
                )
              else if (_erro != null) ...[
                const SizedBox(height: EspacosApp.e12),
                AvisoInline(_erro!, Tom.destrutivo, key: const Key('historico_erro')),
                Center(
                  child: BotaoTexto(
                    key: const Key('historico_tentar_novamente'),
                    rotulo: 'Tentar novamente',
                    onPressed: _carregar,
                  ),
                ),
              ] else if (_itens.isEmpty && !_temMais)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: EspacosApp.e24),
                  child: Text(
                    'Você ainda não tem desafios encerrados',
                    key: Key('historico_vazio'),
                    textAlign: TextAlign.center,
                    style: TextoApp.secundario,
                  ),
                )
              else if (_temMais)
                Center(
                  child: BotaoTexto(
                    key: const Key('historico_carregar_mais'),
                    rotulo: 'Carregar mais',
                    onPressed: _carregar,
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(EspacosApp.e16),
                  child: Text(
                    'Fim do histórico',
                    key: Key('historico_fim'),
                    textAlign: TextAlign.center,
                    style: TextoApp.secundario,
                  ),
                ),
            ],
          )),
        ),
      );
}

/// Desfecho do desafio para o usuário: rótulo, valor e cor (verde só na
/// vitória, coral só na perda; o resto é neutro).
({String rotulo, String valor, Color cor}) resultadoDoHistorico(
  ChallengeModel c,
  String? uid,
  String Function(String) nome,
) {
  const neutro = CoresApp.textoSuave;
  switch (c.status) {
    case StatusDesafio.finished:
      final vencedor = c.winnerId;
      if (vencedor == null) {
        return (rotulo: 'Ninguém acertou', valor: '0', cor: neutro);
      }
      if (uid == null || !c.temParticipante(uid)) {
        return (rotulo: 'Vencedor: ${nome(vencedor)}', valor: '0', cor: neutro);
      }
      final valor = formatarBetCoins(c.amount);
      return vencedor == uid
          ? (rotulo: 'Você venceu', valor: '+$valor', cor: CoresApp.primario)
          : (rotulo: 'Você perdeu', valor: '−$valor', cor: CoresApp.destrutivo);
    case StatusDesafio.rejected:
      return (rotulo: 'Recusado', valor: '0', cor: neutro);
    case StatusDesafio.expired:
      return (rotulo: 'Expirado', valor: '0', cor: neutro);
    default:
      return (rotulo: c.motivoDoCancelamento ?? c.status.label, valor: '0', cor: neutro);
  }
}

class _LinhaDoHistorico extends StatelessWidget {
  final ChallengeModel desafio;
  final VoidCallback onTap;

  const _LinhaDoHistorico({required this.desafio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dados = ApresentacaoDesafios.of(context);
    final c = desafio;
    String nome(String uid) => dados?.nome(uid) ?? 'Jogador';
    final partida = dados?.partidas[c.matchId];
    final confronto = partida == null
        ? 'Partida indisponível'
        : partida.golsMandante != null && partida.golsVisitante != null
            ? '${partida.timeMandante} ${partida.golsMandante} x ${partida.golsVisitante} ${partida.timeVisitante}'
            : '${partida.timeMandante} x ${partida.timeVisitante}';
    final data = (c.finishedAt ?? c.createdAt).toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    final meta = [
      if (partida != null) partida.nomeDoCampeonato,
      '${dois(data.day)}/${dois(data.month)}',
      'aposta ${formatarBetCoins(c.amount)}',
    ].join(' · ');
    final resultado = resultadoDoHistorico(c, dados?.currentUserId, nome);

    return Container(
      key: Key('card_desafio_finalizado_${c.id}'),
      child: InkWell(
        key: Key('btn_detalhes_desafio_finalizado_${c.id}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: EspacosApp.alvoDeToque),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: EspacosApp.e16, vertical: EspacosApp.e12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${nome(c.challengerId)} x ${nome(c.challengedId)}',
                        style: TextoApp.corpoForte.copyWith(color: CoresApp.texto),
                      ),
                      const SizedBox(height: EspacosApp.e4),
                      Text(confronto, style: TextoApp.corpo.copyWith(color: CoresApp.texto)),
                      Text(meta, style: TextoApp.secundario),
                    ],
                  ),
                ),
                const SizedBox(width: EspacosApp.e12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        resultado.rotulo,
                        textAlign: TextAlign.end,
                        style: TextoApp.secundario.copyWith(color: resultado.cor),
                      ),
                      Text(
                        resultado.valor,
                        style: TextoApp.placar.copyWith(
                          color: resultado.cor == CoresApp.textoSuave ? CoresApp.texto : resultado.cor,
                          fontFeatures: const [],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
