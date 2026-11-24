import 'dart:async';

import 'package:flutter/material.dart';

import '../tema/cores_app.dart';

/// Ação principal da tela: fundo verde, texto escuro.
class BotaoPrimario extends _Botao {
  const BotaoPrimario({
    super.key,
    required super.rotulo,
    required super.onPressed,
    super.icone,
    super.carregando,
    super.pequeno,
    super.larguraTotal,
  }) : super(tipo: _TipoDeBotao.primario);
}

/// Ação alternativa: contorno neutro, texto claro.
class BotaoSecundario extends _Botao {
  const BotaoSecundario({
    super.key,
    required super.rotulo,
    required super.onPressed,
    super.icone,
    super.carregando,
    super.pequeno,
    super.larguraTotal,
  }) : super(tipo: _TipoDeBotao.secundario);
}

/// Ação destrutiva (excluir, sair, cancelar desafio): contorno e texto coral.
class BotaoDestrutivo extends _Botao {
  const BotaoDestrutivo({
    super.key,
    required super.rotulo,
    required super.onPressed,
    super.icone,
    super.carregando,
    super.pequeno,
    super.larguraTotal,
  }) : super(tipo: _TipoDeBotao.destrutivo);
}

/// Ação de menor peso, como link ("Ver todas", "Criar conta"): texto verde.
class BotaoTexto extends _Botao {
  const BotaoTexto({
    super.key,
    required super.rotulo,
    required super.onPressed,
    super.icone,
    super.carregando,
    super.pequeno,
    super.larguraTotal,
  }) : super(tipo: _TipoDeBotao.texto);
}

enum _TipoDeBotao { primario, secundario, destrutivo, texto }

/// Base comum. Enquanto [carregando] é verdadeiro, ou enquanto o `Future`
/// devolvido por [onPressed] não termina, mostra um indicador no lugar do
/// ícone e ignora novos toques. [onPressed] nulo desabilita o botão.
abstract class _Botao extends StatefulWidget {
  const _Botao({
    super.key,
    required this.rotulo,
    required this.onPressed,
    required this.tipo,
    this.icone,
    this.carregando = false,
    this.pequeno = false,
    this.larguraTotal = false,
  });

  final String rotulo;
  final FutureOr<void> Function()? onPressed;
  final IconData? icone;
  final bool carregando;

  /// Altura visual 36 (o alvo de toque continua com 48).
  final bool pequeno;

  /// Ocupa toda a largura disponível.
  final bool larguraTotal;

  final _TipoDeBotao tipo;

  @override
  State<_Botao> createState() => _BotaoState();
}

class _BotaoState extends State<_Botao> {
  bool _executando = false;

  bool get _ocupado => widget.carregando || _executando;

  void _tocar() {
    if (_ocupado) return;
    final resultado = widget.onPressed!();
    if (resultado is Future) {
      setState(() => _executando = true);
      resultado.whenComplete(() {
        if (mounted) setState(() => _executando = false);
      });
    }
  }

  Color get _corDoConteudo => switch (widget.tipo) {
        _TipoDeBotao.primario => CoresApp.sobrePrimario,
        _TipoDeBotao.secundario => CoresApp.texto,
        _TipoDeBotao.destrutivo => CoresApp.destrutivo,
        _TipoDeBotao.texto => CoresApp.primario,
      };

  @override
  Widget build(BuildContext context) {
    final pequeno = widget.pequeno;
    final tamanhoDoIcone = pequeno ? 18.0 : 20.0;
    final Widget? marcador = _ocupado
        ? SizedBox.square(
            dimension: tamanhoDoIcone - 2,
            child: CircularProgressIndicator(strokeWidth: 2, color: _corDoConteudo),
          )
        : (widget.icone == null ? null : Icon(widget.icone, size: tamanhoDoIcone));
    final conteudo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (marcador != null) ...[marcador, const SizedBox(width: 8)],
        Flexible(
          child: Text(widget.rotulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    var estilo = widget.tipo == _TipoDeBotao.destrutivo
        ? OutlinedButton.styleFrom(
            foregroundColor: CoresApp.destrutivo,
            side: const BorderSide(color: CoresApp.destrutivo),
          )
        : const ButtonStyle();
    if (pequeno) {
      estilo = estilo.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(48, 36)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
      );
    }

    final aoTocar = widget.onPressed == null ? null : _tocar;
    final Widget botao = switch (widget.tipo) {
      _TipoDeBotao.primario => FilledButton(onPressed: aoTocar, style: estilo, child: conteudo),
      _TipoDeBotao.secundario ||
      _TipoDeBotao.destrutivo =>
        OutlinedButton(onPressed: aoTocar, style: estilo, child: conteudo),
      _TipoDeBotao.texto => TextButton(onPressed: aoTocar, style: estilo, child: conteudo),
    };

    final protegido = AbsorbPointer(absorbing: _ocupado, child: botao);
    return widget.larguraTotal
        ? SizedBox(width: double.infinity, child: protegido)
        : protegido;
  }
}
