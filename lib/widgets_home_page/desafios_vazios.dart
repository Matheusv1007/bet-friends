import 'package:flutter/material.dart';

import '../tema/tema.dart';
import '../widgets/componentes.dart';

/// Sem nenhum desafio: convite para criar o primeiro.
class DesafiosVazios extends StatelessWidget {
  final VoidCallback onCriarDesafio;

  const DesafiosVazios({super.key, required this.onCriarDesafio});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('home_desafios_em_aberto'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloDeSecao('Desafios'),
        const SizedBox(height: EspacosApp.e8),
        Container(
          key: const Key('home_desafios_vazio'),
          padding: const EdgeInsets.all(EspacosApp.e20),
          decoration: const BoxDecoration(
            color: CoresApp.superficie1,
            borderRadius: RaiosApp.bordaCartao,
          ),
          child: Column(
            children: [
              Text(
                'Nenhum desafio no momento',
                textAlign: TextAlign.center,
                style: TextoApp.corpoForte.copyWith(color: CoresApp.texto),
              ),
              const SizedBox(height: EspacosApp.e4),
              const Text(
                'Desafie um amigo em uma partida para começar a apostar BetCoins.',
                textAlign: TextAlign.center,
                style: TextoApp.secundario,
              ),
              const SizedBox(height: EspacosApp.e16),
              BotaoPrimario(
                key: const Key('btn_home_criar_desafio'),
                rotulo: 'Criar desafio',
                icone: Icons.add,
                pequeno: true,
                onPressed: onCriarDesafio,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
