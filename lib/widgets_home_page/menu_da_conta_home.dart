import 'package:betfriends/tela_sobre/tela_informacoes_creditos.dart';
import 'package:flutter/material.dart';

/// Avatar que abre o menu da conta e indica o logout em andamento.
class MenuDaContaHome extends StatelessWidget {
  final bool saindo;
  final VoidCallback onLogout;

  const MenuDaContaHome({
    super.key,
    required this.saindo,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('menu_conta'),
      tooltip: 'Menu da conta',
      enabled: !saindo,
      color: const Color(0xFF151E2E),
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF1B2536)),
      ),
      onSelected: (opcao) {
        if (opcao == 'sair') {
          onLogout();
        } else if (opcao == 'sobre') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TelaInformacoesCreditos(),
            ),
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          key: const Key('menu_item_sobre'),
          value: 'sobre',
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF00D084), size: 20),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Informações e Créditos',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'sair',
          child: Row(
            children: [
              Icon(Icons.logout, color: Color(0xFFF87171), size: 20),
              SizedBox(width: 10),
              Text(
                'Sair da conta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: 19,
          backgroundColor: const Color(0xFF334155),
          child: saindo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00D084),
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.person, color: Colors.white70, size: 24),
        ),
      ),
    );
  }
}
