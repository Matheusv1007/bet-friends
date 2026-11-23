import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/extrato_service.dart';
import '../tela_extrato/tela_extrato.dart';
import '../services/friendship_service.dart';
import '../services/user_search_service.dart';
import '../tela_amigos/tela_buscar_usuarios.dart';
import '../tela_amigos/tela_comunicacoes_amizade.dart';
import '../tela_amigos/tela_lista_amigos.dart';
import '../tela_sobre/tela_informacoes_creditos.dart';
import 'aviso_sem_conexao.dart';
import 'cabecalho_do_perfil.dart';
import 'editar_nome_dialog.dart';
import 'excluir_conta_dialog.dart';
import 'linha_do_perfil.dart';

class DadosDoPerfil extends StatelessWidget {
  final UserProfile perfil;

  /// O perfil veio do cache: o servidor não confirmou o dado.
  final bool semConexao;

  const DadosDoPerfil({super.key, required this.perfil, required this.semConexao});

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        if (semConexao) ...[
          const AvisoSemConexao(),
          const SizedBox(height: 20),
        ],
        CabecalhoDoPerfil(perfil: perfil),
        const SizedBox(height: 28),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              LinhaDoPerfil(
                icone: Icons.badge_outlined,
                rotulo: 'Nome de exibição',
                valor: perfil.displayName,
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
              LinhaDoPerfil(
                icone: Icons.alternate_email,
                rotulo: 'Nome de usuário',
                valor: perfil.username,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('perfil_editar_nome'),
            onPressed: () => _editarNome(context),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              'EDITAR NOME',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryGreen,
              side: const BorderSide(color: primaryGreen, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('perfil_extrato'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TelaExtrato(
                  extratoService: context.read<ExtratoService?>(),
                ),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Extrato de BetCoins',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            style: ElevatedButton.styleFrom(
              backgroundColor: cardBg,
              foregroundColor: primaryGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: primaryGreen.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('perfil_meus_amigos'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TelaListaAmigos(
                  friendshipService: context.read<FriendshipService?>(),
                ),
              ),
            ),
            icon: const Icon(Icons.people_alt_outlined, size: 18),
            label: const Text(
              'MEUS AMIGOS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF151E2E),
              foregroundColor: primaryGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: primaryGreen.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('perfil_buscar_usuarios'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TelaBuscarUsuarios(
                  friendshipService: context.read<FriendshipService?>(),
                  searchService: context.read<UserSearchService?>(),
                ),
              ),
            ),
            icon: const Icon(Icons.person_search, size: 18),
            label: const Text(
              'BUSCAR AMIGOS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF151E2E),
              foregroundColor: primaryGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: primaryGreen.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('perfil_solicitacoes_amizade'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TelaComunicacoesAmizade(
                  friendshipService: context.read<FriendshipService?>(),
                ),
              ),
            ),
            icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
            label: const Text(
              'SOLICITAÇÕES DE AMIZADE',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF151E2E),
              foregroundColor: primaryGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: primaryGreen.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: TextButton.icon(
            key: const Key('perfil_informacoes_creditos'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TelaInformacoesCreditos(),
              ),
            ),
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text(
              'INFORMAÇÕES E CRÉDITOS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('perfil_excluir_conta'),
            onPressed: () => _excluirConta(context),
            icon: const Icon(Icons.warning_amber_rounded, size: 20),
            label: const Text(
              'Excluir conta',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _excluirConta(BuildContext context) async {
    if (semConexao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sem conexão. Conecte-se à internet para excluir a conta.'),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sem conexão. Conecte-se à internet para alterar o nome.'),
        ),
      );
      return;
    }
    final salvou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditarNomeDialog(nomeAtual: perfil.displayName),
    );
    if (salvou == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome de exibição atualizado.')),
      );
    }
  }
}
