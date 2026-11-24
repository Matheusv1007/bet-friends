import 'dart:async';

import 'package:flutter/material.dart';

import '../models/carteira.dart';
import '../services/bonus_recuperacao_service.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';

/// A elegibilidade local é uma indicação; a decisão final é sempre do servidor.
class BonusRecuperacaoCard extends StatefulWidget {
  final Carteira carteira;
  final BonusRecuperacaoService? service;

  const BonusRecuperacaoCard({super.key, required this.carteira, this.service});

  @override
  State<BonusRecuperacaoCard> createState() => _BonusRecuperacaoCardState();
}

class _BonusRecuperacaoCardState extends State<BonusRecuperacaoCard> {
  final _service = BonusRecuperacaoService();
  bool _resgatando = false;
  DateTime? _confirmadoAte;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _agendarAtualizacao();
  }

  @override
  void didUpdateWidget(covariant BonusRecuperacaoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _agendarAtualizacao();
  }

  DateTime? get _proxima => _confirmadoAte ?? widget.carteira.proximaRecuperacaoEm;

  void _agendarAtualizacao() {
    _timer?.cancel();
    final proxima = _proxima;
    if (proxima == null) return;
    final espera = proxima.difference(DateTime.now());
    if (espera > Duration.zero) {
      _timer = Timer(espera, () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resgatar() async {
    if (_resgatando) return;
    setState(() => _resgatando = true);
    String mensagem;
    var tom = Tom.destrutivo;
    try {
      final resultado = await (widget.service ?? _service).resgatar();
      _confirmadoAte = resultado.proximaRecuperacaoEm;
      _agendarAtualizacao();
      mensagem = 'Bônus resgatado! +${resultado.amount} BetCoins.';
      tom = Tom.sucesso;
    } on BonusRecuperacaoException catch (e) {
      mensagem = e.message;
    } catch (_) {
      mensagem = 'Não foi possível confirmar o bônus. Verifique a carteira antes de tentar novamente.';
    }
    if (!mounted) return;
    setState(() => _resgatando = false);
    mostrarAviso(context, mensagem, tom: tom);
  }

  @override
  Widget build(BuildContext context) {
    final carteira = widget.carteira;
    if (carteira.saldoReservado != 0 || carteira.saldoDisponivel >= 10) {
      return const SizedBox.shrink();
    }
    final agora = DateTime.now();
    final proxima = _proxima;
    if (!_resgatando && proxima != null && proxima.isAfter(agora)) {
      final local = proxima.toLocal();
      String dois(int n) => n.toString().padLeft(2, '0');
      return Padding(
        padding: const EdgeInsets.only(top: EspacosApp.e12),
        child: Text(
          'Bônus de recuperação disponível em ${dois(local.day)}/${dois(local.month)}/${local.year} às ${dois(local.hour)}:${dois(local.minute)}.',
          key: const Key('bonus_recuperacao_intervalo'),
          style: TextoApp.secundario,
        ),
      );
    }
    if (!_resgatando && !carteira.podeResgatarBonus(agora)) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('bonus_recuperacao_card'),
      margin: const EdgeInsets.only(top: EspacosApp.e12),
      padding: const EdgeInsets.all(EspacosApp.e16),
      decoration: const BoxDecoration(
        color: CoresApp.superficie1,
        borderRadius: RaiosApp.bordaCartao,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bônus de recuperação', style: TextoApp.corpoForte.copyWith(color: CoresApp.texto)),
          const SizedBox(height: EspacosApp.e4),
          const Text(
            'Seu saldo acabou. Resgate BetCoins para voltar a desafiar.',
            style: TextoApp.secundario,
          ),
          const SizedBox(height: EspacosApp.e12),
          FilledButton(
            key: const Key('resgatar_bonus_recuperacao'),
            onPressed: _resgatando ? null : _resgatar,
            child: _resgatando
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: EspacosApp.e12),
                      Flexible(child: Text('Resgatando bônus…')),
                    ],
                  )
                : const Text('Resgatar +100 BetCoins', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
