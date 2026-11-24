import 'package:flutter/material.dart';

import '../models/carteira.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';

/// Saldo da Home (RF-003, RN-BET-004): disponível em destaque, reservado e
/// total numa linha de apoio, link para o extrato e o atalho "Novo desafio".
/// Somente leitura: o app nunca altera saldos.
class BlocoDeSaldo extends StatelessWidget {
  /// `null` quando a carteira não está disponível.
  final Carteira? carteira;

  /// Os dados vieram do cache, sem confirmação do servidor.
  final bool semConexao;
  final VoidCallback onExtrato;
  final VoidCallback onNovoDesafio;

  const BlocoDeSaldo({
    super.key,
    required this.carteira,
    required this.onExtrato,
    required this.onNovoDesafio,
    this.semConexao = false,
  });

  /// Milhar com ponto ("1.000").
  static String formatar(int valor) {
    final digitos = valor.abs().toString();
    final buffer = StringBuffer(valor < 0 ? '-' : '');
    for (var i = 0; i < digitos.length; i++) {
      if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digitos[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final carteira = this.carteira;
    final apoio = TextoApp.secundario;
    final apoioForte = TextoApp.secundario.copyWith(
      color: CoresApp.texto,
      fontWeight: FontWeight.w600,
    );

    return Container(
      key: const Key('home_bloco_saldo'),
      padding: const EdgeInsets.fromLTRB(
        EspacosApp.e16,
        EspacosApp.e4,
        EspacosApp.e4,
        EspacosApp.e16,
      ),
      decoration: const BoxDecoration(
        color: CoresApp.superficie1,
        borderRadius: RaiosApp.bordaCartao,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: EspacosApp.e8,
            runSpacing: EspacosApp.e4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('SALDO DISPONÍVEL', style: TextoApp.secao),
              if (semConexao)
                const Tooltip(
                  message: 'Sem conexão: últimos dados salvos neste aparelho',
                  child: Text(
                    'Sem conexão',
                    key: Key('home_saldo_sem_conexao'),
                    style: TextoApp.secundario,
                  ),
                ),
              BotaoTexto(
                key: const Key('home_extrato'),
                rotulo: 'Extrato',
                pequeno: true,
                onPressed: onExtrato,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: EspacosApp.e12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: EspacosApp.e12,
              runSpacing: EspacosApp.e8,
              children: [
                if (carteira == null)
                  Text(
                    'Saldo indisponível',
                    key: const Key('home_saldo'),
                    style: TextoApp.corpoForte.copyWith(
                      color: CoresApp.textoSuave,
                    ),
                  )
                else
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: EspacosApp.e4,
                    children: [
                      Text(
                        formatar(carteira.saldoDisponivel),
                        key: const Key('home_saldo'),
                        // Tabular só sem o ponto de milhar, que ganharia largura de dígito
                        style:
                            (carteira.saldoDisponivel < 1000
                                    ? TextoApp.saldo
                                    : TextoApp.saldo.copyWith(
                                        fontFeatures: const [],
                                      ))
                                .copyWith(color: CoresApp.texto),
                      ),
                      Text(
                        'BetCoins',
                        style: TextoApp.secundario.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                BotaoPrimario(
                  key: const Key('home_novo_desafio'),
                  rotulo: 'Novo desafio',
                  icone: Icons.add,
                  pequeno: true,
                  onPressed: onNovoDesafio,
                ),
              ],
            ),
          ),
          if (carteira != null)
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Reservado '),
                  TextSpan(
                    text: formatar(carteira.saldoReservado),
                    style: apoioForte,
                  ),
                  const TextSpan(text: '  ·  Total '),
                  TextSpan(
                    text: formatar(carteira.saldoTotal),
                    style: apoioForte,
                  ),
                ],
              ),
              key: const Key('home_saldo_reservado_total'),
              style: apoio,
            ),
        ],
      ),
    );
  }
}
