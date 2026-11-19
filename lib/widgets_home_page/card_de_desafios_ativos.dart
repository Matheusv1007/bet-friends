import 'package:flutter/material.dart';

import '../data/firestore/challenge_repository.dart';
import '../models/challenge_model.dart';
import '../services/challenge_service.dart';
import '../tela_criar_desafio/modal_aceitar_desafio.dart';
import '../tela_criar_desafio/tela_criar_desafio.dart';
import 'desafios_demonstrativo.dart';
import 'desafios_em_aberto_secao.dart';
import 'desafios_enviados_card.dart';
import 'desafios_finalizados_secao.dart';
import 'desafios_recebidos_card.dart';
import 'desafios_vazios.dart';
import 'detalhes_do_desafio_dialog.dart';

/// Widget de resumo de desafios na Home (D-003, Plano Mestre v3.2).
///
/// Apresenta dados reais agregados a partir do [ChallengeService]:
/// - Desafios recebidos aguardando resposta (destacados);
/// - Desafios enviados aguardando o amigo, que o criador pode cancelar;
/// - Desafios em aberto (aceitos, em andamento, aguardando resultado);
/// - Desafios recentemente finalizados (destacados);
/// - Modo demonstrativo quando os dados de desafios não estiverem disponíveis.
class DesafiosAtivosWidget extends StatelessWidget {
  final List<ChallengeModel>? desafios;
  final String? currentUserId;
  final ChallengeService? challengeService;

  const DesafiosAtivosWidget({
    super.key,
    this.desafios,
    this.currentUserId,
    this.challengeService,
  });

  void _exibirDetalhesDesafio(BuildContext context, ChallengeModel c) {
    showDialog(
      context: context,
      builder: (ctx) => DetalhesDoDesafioDialog(desafio: c),
    );
  }

  /// Pede confirmação e cancela um desafio pendente criado pelo usuário; o backend libera a reserva.
  Future<void> _confirmarCancelamento(BuildContext context, ChallengeModel c) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Cancelar desafio?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "As ${c.amount} BetCoins reservadas voltam para o seu saldo disponível.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            key: const Key('btn_manter_desafio'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Manter", style: TextStyle(color: Color(0xFF00D084))),
          ),
          TextButton(
            key: const Key('btn_confirmar_cancelamento'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Cancelar desafio", style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmou != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    var mensagem = 'Desafio cancelado. Suas BetCoins foram liberadas.';
    var cor = const Color(0xFF00D084);
    try {
      await (challengeService ?? ChallengeService()).cancelarDesafio(challengeId: c.id);
    } on ChallengeException catch (e) {
      mensagem = e.message;
      cor = const Color(0xFFEF4444);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = desafios;
    if (lista == null) {
      return const DesafiosDemonstrativo();
    }

    final pendentesRecebidos = lista.where((c) {
      final isPending = c.status == StatusDesafio.pending;
      final isChallenged = currentUserId == null || c.challengedId == currentUserId;
      return isPending && isChallenged;
    }).toList();

    final desafiosEmAberto = lista.where((c) {
      return c.status == StatusDesafio.accepted ||
          c.status == StatusDesafio.inProgress ||
          c.status == StatusDesafio.waitingResult;
    }).toList();

    final desafiosFinalizados = lista.where((c) {
      return c.status == StatusDesafio.finished || c.status.isTerminal;
    }).toList();

    final pendentesEnviados = lista.where((c) {
      return c.status == StatusDesafio.pending &&
          currentUserId != null &&
          c.challengerId == currentUserId;
    }).toList();

    // Se a lista estiver vazia
    if (lista.isEmpty) {
      return DesafiosVazios(
        onCriarDesafio: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CriarDesafioScreen(),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. DESTAQUE: DESAFIOS RECEBIDOS AGUARDANDO RESPOSTA
        if (pendentesRecebidos.isNotEmpty)
          DesafiosRecebidosCard(
            desafios: pendentesRecebidos,
            onResponder: (c) {
              ModalAceitarDesafio.exibir(
                context: context,
                desafio: c,
                nomeCriador: c.challengerId,
                challengeService: challengeService,
              );
            },
          ),
        // 1b. DESAFIOS ENVIADOS AGUARDANDO O AMIGO (o criador ainda pode cancelar)
        if (pendentesEnviados.isNotEmpty)
          DesafiosEnviadosCard(
            desafios: pendentesEnviados,
            onCancelar: (c) => _confirmarCancelamento(context, c),
          ),
        // 2. DESAFIOS EM ABERTO
        DesafiosEmAbertoSecao(
          desafios: desafiosEmAberto,
          onDetalhes: (c) => _exibirDetalhesDesafio(context, c),
        ),
        // 3. DESTAQUE: DESAFIOS RECENTEMENTE FINALIZADOS
        if (desafiosFinalizados.isNotEmpty)
          DesafiosFinalizadosSecao(
            desafios: desafiosFinalizados,
            currentUserId: currentUserId,
            onDetalhes: (c) => _exibirDetalhesDesafio(context, c),
          ),
      ],
    );
  }
}
