import 'package:flutter/material.dart';

import '../data/firestore/extrato_repository.dart';
import '../models/lancamento_do_extrato.dart';
import '../services/extrato_service.dart';
import '../services/registro_de_erros.dart';

class TelaExtrato extends StatefulWidget {
  final ExtratoService? extratoService;
  const TelaExtrato({super.key, this.extratoService});

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

  @override
  void initState() {
    super.initState();
    _service = widget.extratoService ?? ExtratoService();
    _carregar();
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B111D),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0B111D),
      foregroundColor: Colors.white,
      title: const Text('Extrato de BetCoins'),
    ),
    body: SafeArea(
      child: ListView(
        key: const Key('extrato_lista'),
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Mais recentes primeiro. Referências de desafios válidas nesta tela.',
            style: TextStyle(color: Color(0xFF8E9CAB))),
          if (_cache) const Text('Sem confirmação do servidor. O extrato pode estar incompleto.',
            style: TextStyle(color: Color(0xFF8E9CAB))),
          if (_ignorados > 0) const Text('Alguns lançamentos não puderam ser exibidos.',
            style: TextStyle(color: Color(0xFF8E9CAB))),
          for (final item in _itens) _item(item),
          if (_carregando) const Center(child: CircularProgressIndicator(
            key: Key('extrato_carregando'), color: Color(0xFF00D084))),
          if (_erro != null) ...[
            Text(_erro!, key: const Key('extrato_erro'), style: const TextStyle(color: Color(0xFF8E9CAB))),
            _botao('Tentar novamente', 'extrato_tentar_novamente'),
          ] else if (!_carregando) ...[
            if (_itens.isEmpty && !_cache && _ignorados == 0)
              const Text('Nenhum lançamento ainda.', key: Key('extrato_vazio'), style: TextStyle(color: Colors.white)),
            if (_temMais) _botao('Carregar mais', 'extrato_carregar_mais')
            else if (_cache) _botao('Tentar novamente', 'extrato_tentar_novamente')
            else if (_itens.isNotEmpty)
              const Text('Fim do extrato.', key: Key('extrato_fim'), style: TextStyle(color: Color(0xFF8E9CAB))),
          ],
        ],
      ),
    ),
  );

  Widget _botao(String texto, String chave) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: OutlinedButton(
      key: Key(chave), onPressed: _carregar,
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: const Color(0xFF00D084)),
      child: Text(texto),
    ),
  );

  Widget _item(LancamentoDoExtrato item) {
    final data = item.createdAt.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    final cor = switch (item.tipo.sinal) {
      1 => const Color(0xFF00D084),
      -1 => const Color(0xFFEF4444),
      _ => const Color(0xFF8E9CAB),
    };
    return Card(
      key: Key('extrato_item_${item.id}'),
      color: const Color(0xFF151E2E),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.tipo.rotulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('${dois(data.day)}/${dois(data.month)}/${data.year} ${dois(data.hour)}:${dois(data.minute)}', style: const TextStyle(color: Color(0xFF8E9CAB))),
          Text(item.valorFormatado, style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
          if (item.tipo.explicacao.isNotEmpty) Text(item.tipo.explicacao, style: const TextStyle(color: Color(0xFF8E9CAB))),
          Text('Saldo total após: ${item.saldoTotalDepois} BC', style: const TextStyle(color: Colors.white)),
          if (item.challengeId != null) Text('Desafio ${_desafios[item.challengeId]}', style: const TextStyle(color: Color(0xFF8E9CAB))),
        ]),
      ),
    );
  }
}
