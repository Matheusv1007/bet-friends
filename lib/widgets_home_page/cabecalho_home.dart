import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/tema/tema.dart';
import 'package:betfriends/widgets/componentes.dart';
import 'package:betfriends/widgets_home_page/menu_da_conta_home.dart';
import 'package:flutter/material.dart';

const _diasDaSemana = [
  'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira',
  'Sexta-feira', 'Sábado', 'Domingo',
];

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho',
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// "Domingo, 23 de novembro".
String dataPorExtenso(DateTime data) =>
    '${_diasDaSemana[data.weekday - 1]}, ${data.day} de ${_meses[data.month - 1]}';

/// Cabeçalho da Home: logo e avatar da conta; abaixo, a saudação e a data.
class CabecalhoHome extends StatelessWidget {
  final Stream<PerfilObservado>? perfil;
  final bool saindo;
  final VoidCallback onLogout;

  /// Data exibida; padrão: hoje.
  final DateTime? hoje;

  const CabecalhoHome({
    super.key,
    required this.perfil,
    required this.saindo,
    required this.onLogout,
    this.hoje,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PerfilObservado>(
      stream: perfil,
      builder: (context, snapshot) {
        // Sem perfil, sem conexão ou com erro, uma saudação neutra
        final nome = snapshot.hasError ? null : snapshot.data?.perfil?.displayName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LogoBetFriends(altura: 22),
                const Spacer(),
                MenuDaContaHome(saindo: saindo, onLogout: onLogout, nome: nome),
              ],
            ),
            const SizedBox(height: EspacosApp.e8),
            Text(
              nome == null ? 'Olá!' : 'Olá, $nome',
              key: const Key('home_saudacao'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextoApp.tituloDeTela.copyWith(color: CoresApp.texto),
            ),
            Text(
              dataPorExtenso(hoje ?? DateTime.now()),
              key: const Key('home_data'),
              style: TextoApp.secundario,
            ),
          ],
        );
      },
    );
  }
}
