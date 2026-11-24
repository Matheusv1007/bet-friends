import 'package:betfriends/tela_sobre/tela_informacoes_creditos.dart';
import 'package:betfriends/tema/tema.dart';
import 'package:flutter/material.dart';

/// Avatar com a inicial do nome que abre o menu da conta e indica o logout em andamento.
class MenuDaContaHome extends StatelessWidget {
  final bool saindo;
  final VoidCallback onLogout;

  /// Nome de exibição; sem ele, o avatar mostra um ícone de pessoa.
  final String? nome;

  const MenuDaContaHome({
    super.key,
    required this.saindo,
    required this.onLogout,
    this.nome,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = nome?.trim().characters.firstOrNull?.toUpperCase();
    return PopupMenuButton<String>(
      key: const Key('menu_conta'),
      tooltip: 'Menu da conta',
      enabled: !saindo,
      offset: const Offset(0, 48),
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
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          key: Key('menu_item_sobre'),
          value: 'sobre',
          child: Row(
            children: [
              Icon(Icons.info_outline, color: CoresApp.textoSuave, size: 20),
              SizedBox(width: EspacosApp.e12),
              Flexible(
                child: Text('Informações e Créditos', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'sair',
          child: Row(
            children: [
              Icon(Icons.logout, color: CoresApp.destrutivo, size: 20),
              SizedBox(width: EspacosApp.e12),
              Text('Sair da conta'),
            ],
          ),
        ),
      ],
      child: SizedBox.square(
        dimension: EspacosApp.alvoDeToque,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: CoresApp.superficie2,
              shape: BoxShape.circle,
            ),
            child: saindo
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : inicial == null
                    ? const Icon(Icons.person, color: CoresApp.textoSuave, size: 22)
                    : Text(
                        inicial,
                        key: const Key('home_avatar_inicial'),
                        style: TextoApp.corpoForte.copyWith(color: CoresApp.texto),
                      ),
          ),
        ),
      ),
    );
  }
}
