import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/extrato_repository.dart';
import '../data/firestore/user_profile_repository.dart';
import '../models/carteira.dart';
import '../models/lancamento_do_extrato.dart';
import '../services/extrato_service.dart';
import '../services/registro_de_erros.dart';
import '../services/user_profile_service.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'formato_betcoins.dart';

/// Glifo simples de cada tipo de lançamento (todos os tipos têm um).
IconData glifoDoLancamento(TipoDoLancamento tipo) => switch (tipo) {
      TipoDoLancamento.saldoInicial => Icons.account_balance_wallet_outlined,
      TipoDoLancamento.reserva => Icons.lock_outline,
      TipoDoLancamento.liberacao => Icons.undo,
      TipoDoLancamento.premio => Icons.arrow_upward,
      TipoDoLancamento.perda => Icons.arrow_downward,
      TipoDoLancamento.reembolso => Icons.undo,
      TipoDoLancamento.bonus => Icons.card_giftcard_outlined,
      TipoDoLancamento.reposicao => Icons.add,
    };

/// Valor do lançamento com sinal: `+100` (crédito), `−50` (débito) ou `100`
/// (reserva, liberação e reembolso, que não alteram o total).
String valorDoLancamento(LancamentoDoExtrato item) {
  final numero = formatarBetCoins(item.amount);
  return switch (item.tipo.sinal) { 1 => '+$numero', -1 => '−$numero', _ => numero };
}

/// Crédito em verde, débito em coral e neutro para o que não altera o total.
Color corDoLancamento(TipoDoLancamento tipo) => switch (tipo.sinal) {
      1 => CoresApp.primario,
      -1 => CoresApp.destrutivo,
      _ => CoresApp.textoSuave,
    };

class TelaExtrato extends StatefulWidget {
  final ExtratoService? extratoService;

  /// Fonte do resumo da carteira; sem ela, usa o [UserProfileService] da
  /// árvore e, se também não houver, a tela omite o resumo.
  final UserProfileService? perfilService;

  const TelaExtrato({super.key, this.extratoService, this.perfilService});

  @override
  State<TelaExtrato> createState() => _TelaExtratoState();
}

class _TelaExtratoState extends State<TelaExtrato> {
  late final ExtratoService _service;
  final _itens = <LancamentoDoExtrato>[];
  final _ids = <String>{};
  // Referências locais à sessão da tela, sem mostrar IDs internos.
  final _desafios = <String, int>{};
  CursorDoExtrato? _cursor;
  bool _carregando = false;
  bool _temMais = true;
  bool _cache = false;
  int _ignorados = 0;
  String? _erro;
  Carteira? _carteira;
  StreamSubscription<Carteira?>? _assinaturaDaCarteira;

  @override
  void initState() {
    super.initState();
    _service = widget.extratoService ?? ExtratoService();
    _observarCarteira();
    _carregar();
  }

  @override
  void dispose() {
    _assinaturaDaCarteira?.cancel();
    super.dispose();
  }

  /// O resumo é complementar: sem serviço, sem sessão ou com falha de leitura,
  /// ele simplesmente não aparece.
  void _observarCarteira() {
    final servico = widget.perfilService ?? context.read<UserProfileService?>();
    if (servico == null) return;
    try {
      _assinaturaDaCarteira = servico.observarCarteiraAtual().listen(
        (carteira) {
          if (mounted) setState(() => _carteira = carteira);
        },
        onError: (Object _) {
          if (mounted) setState(() => _carteira = null);
        },
      );
    } on UserProfileException {
      // Sessão encerrada: o extrato em si trata o erro.
    }
  }

  Future<void> _carregar() async {
    if (_carregando) return;
    setState(() { _carregando = true; _erro = null; });
    try {
      final pagina = await _service.buscarDoUsuarioAtual(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        for (final item in pagina.itens) {
          if (_ids.add(item.id)) {
            _itens.add(item);
            final desafio = item.challengeId;
            if (desafio != null) _desafios.putIfAbsent(desafio, () => _desafios.length + 1);
          }
        }
        _cursor = pagina.proximoCursor;
        _temMais = pagina.temMais;
        _cache = pagina.doCache;
        _ignorados += pagina.ignorados;
      });
    } on ExtratoException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (e, s) {
      registrarErro('Consultar extrato', e, s);
      if (mounted) setState(() => _erro = 'Não foi possível consultar o extrato. Tente novamente.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final temNeutro = _itens.any((i) => i.tipo.sinal == 0);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Extrato de BetCoins'),
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('extrato_lista'),
          padding: const EdgeInsets.fromLTRB(
            EspacosApp.margemDaTela, EspacosApp.e8, EspacosApp.margemDaTela, EspacosApp.e32,
          ),
          children: [
            if (_carteira != null) ...[
              _Resumo(carteira: _carteira!),
              const SizedBox(height: EspacosApp.e24),
            ],
            if (_cache) ...[
              const AvisoInline(
                'Sem confirmação do servidor. O extrato pode estar incompleto.',
                Tom.atencao,
                key: Key('extrato_sem_confirmacao'),
              ),
              const SizedBox(height: EspacosApp.e12),
            ],
            if (_ignorados > 0) ...[
              const AvisoInline('Alguns lançamentos não puderam ser exibidos.', Tom.neutro),
              const SizedBox(height: EspacosApp.e12),
            ],
            Semantics(
              header: true,
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'LANÇAMENTOS', style: TextoApp.secao),
                  TextSpan(
                    text: '   mais recentes primeiro',
                    style: TextoApp.secundario.copyWith(fontSize: 12),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: EspacosApp.e8),
            if (_itens.isNotEmpty)
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < _itens.length; i++) ...[
                      if (i > 0) const Divider(),
                      _Lancamento(item: _itens[i], desafio: _desafios[_itens[i].challengeId]),
                    ],
                  ],
                ),
              ),
            if (_carregando)
              const Padding(
                padding: EdgeInsets.all(EspacosApp.e24),
                child: Center(child: CircularProgressIndicator(key: Key('extrato_carregando'))),
              ),
            if (_erro != null) ...[
              const SizedBox(height: EspacosApp.e12),
              AvisoInline(_erro!, Tom.destrutivo, key: const Key('extrato_erro')),
              _acao('Tentar novamente', 'extrato_tentar_novamente'),
            ] else if (!_carregando) ...[
              if (_itens.isEmpty && !_cache && _ignorados == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: EspacosApp.e24),
                  child: Text(
                    'Nenhum lançamento ainda.',
                    key: Key('extrato_vazio'),
                    textAlign: TextAlign.center,
                    style: TextoApp.secundario,
                  ),
                ),
              if (_temMais) _acao('Carregar mais', 'extrato_carregar_mais')
              else if (_cache) _acao('Tentar novamente', 'extrato_tentar_novamente')
              else if (_itens.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: EspacosApp.e16),
                  child: Text(
                    'Fim do extrato.',
                    key: Key('extrato_fim'),
                    textAlign: TextAlign.center,
                    style: TextoApp.secundario,
                  ),
                ),
            ],
            if (temNeutro)
              const Padding(
                padding: EdgeInsets.only(top: EspacosApp.e8),
                child: Text(
                  'Reserva e reembolso não alteram o total.',
                  key: Key('extrato_nota_total'),
                  textAlign: TextAlign.center,
                  style: TextoApp.secundario,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _acao(String rotulo, String chave) => Center(
        child: BotaoTexto(key: Key(chave), rotulo: rotulo, onPressed: _carregar),
      );
}

class _Resumo extends StatelessWidget {
  final Carteira carteira;
  const _Resumo({required this.carteira});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('extrato_resumo'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _campo('Disponível', carteira.saldoDisponivel, CrossAxisAlignment.start)),
        Expanded(child: _campo('Reservado', carteira.saldoReservado, CrossAxisAlignment.center)),
        Expanded(child: _campo('Total', carteira.saldoTotal, CrossAxisAlignment.end)),
      ],
    );
  }

  Widget _campo(String rotulo, int valor, CrossAxisAlignment alinhamento) => Column(
        crossAxisAlignment: alinhamento,
        children: [
          Text(rotulo, style: TextoApp.secundario),
          Text(
            formatarBetCoins(valor),
            style: TextoApp.placar.copyWith(color: CoresApp.texto, fontFeatures: const []),
          ),
        ],
      );
}

class _Lancamento extends StatelessWidget {
  final LancamentoDoExtrato item;
  final int? desafio;
  const _Lancamento({required this.item, required this.desafio});

  String _data() {
    final d = item.createdAt.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    final ano = d.year == DateTime.now().year ? '' : '/${d.year}';
    final data = '${dois(d.day)}/${dois(d.month)}$ano · ${dois(d.hour)}:${dois(d.minute)}';
    return desafio == null ? data : '$data · Desafio $desafio';
  }

  @override
  Widget build(BuildContext context) {
    final cor = corDoLancamento(item.tipo);
    return Padding(
      key: Key('extrato_item_${item.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: EspacosApp.e16, vertical: EspacosApp.e12,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: CoresApp.superficie2),
            child: Icon(glifoDoLancamento(item.tipo), size: 18, color: cor),
          ),
          const SizedBox(width: EspacosApp.e12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.tipo.rotulo, style: TextoApp.corpoForte.copyWith(color: CoresApp.texto)),
                Text(_data(), style: TextoApp.secundario),
              ],
            ),
          ),
          const SizedBox(width: EspacosApp.e12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valorDoLancamento(item),
                key: Key('extrato_valor_${item.id}'),
                style: TextoApp.corpoForte.copyWith(color: item.tipo.sinal == 0 ? CoresApp.texto : cor),
              ),
              Text('total ${formatarBetCoins(item.saldoTotalDepois)}', style: TextoApp.secundario),
            ],
          ),
        ],
      ),
    );
  }
}
