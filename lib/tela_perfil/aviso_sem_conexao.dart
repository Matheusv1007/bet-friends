import 'package:flutter/material.dart';

import '../widgets/componentes.dart';

class AvisoSemConexao extends StatelessWidget {
  const AvisoSemConexao({super.key});

  @override
  Widget build(BuildContext context) {
    return const AvisoInline(
      'Sem conexão. Exibindo os últimos dados salvos neste aparelho; '
      'alterações ficam indisponíveis até a conexão voltar.',
      Tom.atencao,
      key: Key('perfil_sem_conexao'),
    );
  }
}
