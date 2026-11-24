import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/extrato_service.dart';
import '../services/friendship_service.dart';
import '../services/user_search_service.dart';
import '../tela_amigos/tela_buscar_usuarios.dart';
import '../tela_amigos/tela_comunicacoes_amizade.dart';
import '../tela_amigos/tela_lista_amigos.dart';
import '../tela_extrato/tela_extrato.dart';
import '../tela_sobre/tela_informacoes_creditos.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
import 'aviso_sem_conexao.dart';
import 'cabecalho_do_perfil.dart';
import 'editar_nome_dialog.dart';
import 'excluir_conta_dialog.dart';
import 'grupo_do_perfil.dart';
import 'linha_do_perfil.dart';

class DadosDoPerfil extends StatelessWidget {
  final UserProfile perfil;

  /// O perfil veio do cache: o servidor não confirmou o dado.
  final bool semConexao;

  const DadosDoPerfil({super.key, required this.perfil, required this.semConexao});

  static const _chevron = Icon(Icons.chevron_right);

  void _abrir(BuildContext context, Widget Function() tela) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela()));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        EspacosApp.margemDaTela,
        EspacosApp.e8,
        EspacosApp.margemDaTela,
        EspacosApp.e32,
      ),
      children: [
        if (semConexao) ...[
          const AvisoSemConexao(),
          const SizedBox(height: EspacosApp.e16),
        ],
        CabecalhoDoPerfil(perfil: perfil),
        const SizedBox(height: EspacosApp.e24),
        GrupoDoPerfil(
          titulo: 'Dados',
          linhas: [
            LinhaDoPerfil(
              rotulo: 'Nome de exibição',
              valor: perfil.displayName,
              chaveDoValor: const Key('perfil_dados_nome'),
              acao: BotaoTexto(
                key: const Key('perfil_editar_nome'),
                rotulo: 'Editar',
                pequeno: true,
                // Sem devolver o Future: o botão não deve ficar "ocupado" com o diálogo aberto
                onPressed: () {
                  _editarNome(context);
                },
              ),
            ),
            const Divider(),
            LinhaDoPerfil(
              rotulo: 'Nome de usuário',
              valor: '@${perfil.username}',
              chaveDoValor: const Key('perfil_dados_usuario'),
            ),
          ],
        ),
        const SizedBox(height: EspacosApp.e24),
        GrupoDoPerfil(
          titulo: 'Atividade',
          linhas: [
            LinhaDeLista(
              key: const Key('perfil_extrato'),
              leading: const Icon(Icons.receipt_long_outlined),
              titulo: 'Extrato de BetCoins',
              trailing: _chevron,
              divisor: true,
              onTap: () => _abrir(
                context,
                () => TelaExtrato(extratoService: context.read<ExtratoService?>()),
              ),
            ),
            LinhaDeLista(
              key: const Key('perfil_meus_amigos'),
              leading: const Icon(Icons.people_alt_outlined),
              titulo: 'Meus amigos',
              trailing: _chevron,
              divisor: true,
              onTap: () => _abrir(
                context,
                () => TelaListaAmigos(
                  friendshipService: context.read<FriendshipService?>(),
                ),
              ),
            ),
            LinhaDeLista(
              key: const Key('perfil_buscar_usuarios'),
              leading: const Icon(Icons.person_search_outlined),
              titulo: 'Buscar amigos',
              trailing: _chevron,
              divisor: true,
              onTap: () => _abrir(
                context,
                () => TelaBuscarUsuarios(
                  friendshipService: context.read<FriendshipService?>(),
                  searchService: context.read<UserSearchService?>(),
                ),
              ),
            ),
            LinhaDeLista(
              key: const Key('perfil_solicitacoes_amizade'),
              leading: const Icon(Icons.mail_outline),
              titulo: 'Solicitações de amizade',
              trailing: _chevron,
              onTap: () => _abrir(
                context,
                () => TelaComunicacoesAmizade(
                  friendshipService: context.read<FriendshipService?>(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: EspacosApp.e24),
        GrupoDoPerfil(
          titulo: 'Informações',
          linhas: [
            LinhaDeLista(
              key: const Key('perfil_informacoes_creditos'),
              leading: const Icon(Icons.info_outline),
              titulo: 'Informações e créditos',
              trailing: _chevron,
              onTap: () => _abrir(context, () => const TelaInformacoesCreditos()),
            ),
          ],
        ),
        const SizedBox(height: EspacosApp.e32),
        Semantics(
          header: true,
          child: Text(
            'ZONA DE RISCO',
            style: TextoApp.secao.copyWith(color: CoresApp.destrutivo),
          ),
        ),
        const SizedBox(height: EspacosApp.e4),
        const Text(
          'Ação permanente: apaga seu perfil e suas amizades.',
          style: TextoApp.secundario,
        ),
        const SizedBox(height: EspacosApp.e12),
        BotaoDestrutivo(
          key: const Key('perfil_excluir_conta'),
          rotulo: 'Excluir conta',
          larguraTotal: true,
          onPressed: () {
            _excluirConta(context);
          },
        ),
      ],
    );
  }

  Future<void> _excluirConta(BuildContext context) async {
    if (semConexao) {
      mostrarAviso(
        context,
        'Sem conexão. Conecte-se à internet para excluir a conta.',
        tom: Tom.atencao,
      );
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExcluirContaDialog(username: perfil.username),
    );
  }

  /// O novo nome aparece na tela pelo stream do perfil; aqui só se confirma
  /// o sucesso, depois que a gravação terminou.
  Future<void> _editarNome(BuildContext context) async {
    // Atalho de usabilidade: a garantia de não gravar offline é do repositório
    if (semConexao) {
      mostrarAviso(
        context,
        'Sem conexão. Conecte-se à internet para alterar o nome.',
        tom: Tom.atencao,
      );
      return;
    }
    final salvou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditarNomeDialog(nomeAtual: perfil.displayName),
    );
    if (salvou == true && context.mounted) {
      mostrarAviso(context, 'Nome de exibição atualizado.', tom: Tom.sucesso);
    }
  }
}
