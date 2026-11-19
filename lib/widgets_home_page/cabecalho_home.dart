import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/models/carteira.dart';
import 'package:betfriends/widgets_home_page/card_de_carteira.dart';
import 'package:betfriends/widgets_home_page/menu_da_conta_home.dart';
import 'package:flutter/material.dart';

/// Cabeçalho com o avatar, saudação, saldo e logo do BetFriends.
class CabecalhoHome extends StatelessWidget {
  final Stream<PerfilObservado>? perfil;
  final bool saindo;
  final VoidCallback onLogout;

  const CabecalhoHome({
    super.key,
    required this.perfil,
    required this.saindo,
    required this.onLogout,
  });

  void _exibirDetalhesCarteira(BuildContext context, Carteira carteira, bool semConexao) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Carddecarteira(carteira: carteira, semConexao: semConexao),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar circular com anel sutil; abre o menu da conta
        MenuDaContaHome(saindo: saindo, onLogout: onLogout),
        const SizedBox(width: 12),

        Expanded(
          child: StreamBuilder<PerfilObservado>(
            stream: perfil,
            builder: (context, snapshot) {
              final nome = snapshot.hasError ? null : snapshot.data?.perfil?.displayName;
              final carteira = snapshot.hasError ? null : snapshot.data?.carteira;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome do perfil quando disponível; sem perfil, sem conexão ou
                  // com erro, uma saudação neutra
                  Text(
                    nome == null ? "Olá!" : "Olá, $nome",
                    key: const Key('home_saudacao'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Exibição da carteira real (KAN-69; RF-003, RN-BET-004)
                  if (carteira == null)
                    const Text(
                      "Saldo indisponível",
                      key: Key('home_saldo'),
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    GestureDetector(
                      key: const Key('home_saldo_interativo'),
                      onTap: () => _exibirDetalhesCarteira(
                        context,
                        carteira,
                        snapshot.data?.doCache ?? false,
                      ),
                      child: Text(
                        "${carteira.saldoDisponivel} BetCoins",
                        key: const Key('home_saldo'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        const SizedBox(width: 12),

        // Logo BetFriends com escudo estilizado verde
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF0B2421),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00D084), width: 1.5),
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: Color(0xFF00D084),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "BetFriends",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
