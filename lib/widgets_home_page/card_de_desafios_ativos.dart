import 'package:flutter/material.dart';

import '../data/firestore/challenge_repository.dart';
import '../models/challenge_model.dart';
import '../services/challenge_service.dart';
import '../tela_criar_desafio/modal_aceitar_desafio.dart';
import '../tela_criar_desafio/tela_criar_desafio.dart';

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

  Widget _buildDesafioItem({
    required String jogador1,
    required String jogador2,
    required VoidCallback onTap,
    String? subtitulo,
    String? statusLabel,
    Color? statusColor,
    String? botaoLabel,
    Key? itemKey,
    Key? botaoKey,
  }) {
    return Container(
      key: itemKey,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatares sobrepostos dos dois jogadores
          SizedBox(
            width: 48,
            height: 32,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF151E2E),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(0xFF334155),
                      child: Icon(Icons.person, size: 18, color: Colors.white70),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF151E2E),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(0xFF475569),
                      child: Icon(Icons.person, size: 18, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Nomes e subtítulo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$jogador1 x $jogador2",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      color: Color(0xFF8E9CAB),
                      fontSize: 11.5,
                    ),
                  ),
                ],
                if (statusLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor ?? const Color(0xFF00D084),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Botão de ação
          GestureDetector(
            key: botaoKey,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2425),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (statusColor ?? const Color(0xFF00D084)).withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Text(
                botaoLabel ?? "Detalhes do Desafio",
                style: TextStyle(
                  color: statusColor ?? const Color(0xFF00D084),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemonstrativo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Os desafios abaixo são exemplos fixos até existir o backend de desafios
        Row(
          children: [
            const Text(
              "DESAFIOS ATIVOS",
              style: TextStyle(
                color: Color(0xFF8E9CAE),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "DEMONSTRATIVO",
                key: Key('desafios_ativos_demonstrativo'),
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildDesafioItem(
          jogador1: "Pedro",
          jogador2: "Lucas",
          onTap: () {},
        ),
        _buildDesafioItem(
          jogador1: "Guilherme",
          jogador2: "Gustavo",
          onTap: () {},
        ),
      ],
    );
  }

  void _exibirDetalhesDesafio(BuildContext context, ChallengeModel c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Detalhes do Desafio",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Partida: #${c.matchId}", style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text("Aposta: ${c.amount} BetCoins", style: const TextStyle(color: Color(0xFF00D084), fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("Status: ${c.status.label}", style: const TextStyle(color: Colors.white70)),
            if (c.motivoDoCancelamento != null) ...[
              const SizedBox(height: 6),
              Text(c.motivoDoCancelamento!, style: const TextStyle(color: Color(0xFFF59E0B))),
            ],
            const SizedBox(height: 6),
            Text("Criador: ${c.challengerId} (${c.challengerPrediction.label})", style: const TextStyle(color: Colors.white70)),
            if (c.challengedPrediction != null) ...[
              const SizedBox(height: 6),
              Text("Desafiado: ${c.challengedId} (${c.challengedPrediction!.label})", style: const TextStyle(color: Colors.white70)),
            ],
            if (c.winnerId != null) ...[
              const SizedBox(height: 8),
              Text("Vencedor: ${c.winnerId}", style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fechar", style: TextStyle(color: Color(0xFF00D084))),
          ),
        ],
      ),
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
      return _buildDemonstrativo();
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
      return Column(
        key: const Key('home_desafios_em_aberto'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DESAFIOS EM ABERTO",
            style: TextStyle(
              color: Color(0xFF8E9CAE),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('home_desafios_vazio'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF151E2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sports_kabaddi,
                  color: Color(0xFF64748B),
                  size: 36,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Nenhum desafio no momento",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Crie um desafio com seus amigos para começar a apostar BetCoins!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8E9CAB),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const Key('btn_home_criar_desafio'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CriarDesafioScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    "CRIAR DESAFIO",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D084),
                    foregroundColor: const Color(0xFF062319),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. DESTAQUE: DESAFIOS RECEBIDOS AGUARDANDO RESPOSTA
        if (pendentesRecebidos.isNotEmpty) ...[
          Container(
            key: const Key('home_desafios_recebidos_pendentes'),
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      color: Color(0xFFF59E0B),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "DESAFIOS RECEBIDOS",
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      key: const Key('badge_desafios_pendentes'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B2213),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        "AGUARDANDO SUA RESPOSTA",
                        style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...pendentesRecebidos.map((c) {
                  return Container(
                    key: Key('card_desafio_pendente_${c.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151E2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFF2B2213),
                          child: Icon(Icons.sports_kabaddi, color: Color(0xFFF59E0B), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Desafio de ${c.challengerId}",
                                key: Key('desafio_pendente_challenger_${c.id}'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Partida #${c.matchId} • ${c.amount} BetCoins",
                                key: Key('desafio_pendente_info_${c.id}'),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Palpite rival: ${c.challengerPrediction.label}",
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          key: Key('btn_responder_desafio_${c.id}'),
                          onPressed: () {
                            ModalAceitarDesafio.exibir(
                              context: context,
                              desafio: c,
                              nomeCriador: c.challengerId,
                              challengeService: challengeService,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF0D131F),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "RESPONDER",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        // 1b. DESAFIOS ENVIADOS AGUARDANDO O AMIGO (o criador ainda pode cancelar)
        if (pendentesEnviados.isNotEmpty) ...[
          Container(
            key: const Key('home_desafios_enviados_pendentes'),
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF151E2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DESAFIOS ENVIADOS",
                  style: TextStyle(
                    color: Color(0xFF8E9CAE),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                ...pendentesEnviados.map((c) {
                  return Container(
                    key: Key('card_desafio_enviado_${c.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1420),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Aguardando ${c.challengedId}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Partida #${c.matchId} • ${c.amount} BetCoins",
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Seu palpite: ${c.challengerPrediction.label}",
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          key: Key('btn_cancelar_desafio_${c.id}'),
                          onPressed: () => _confirmarCancelamento(context, c),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "CANCELAR",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        // 2. DESAFIOS EM ABERTO
        Row(
          children: [
            const Text(
              "DESAFIOS EM ABERTO",
              key: Key('home_desafios_em_aberto'),
              style: TextStyle(
                color: Color(0xFF8E9CAE),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00D084).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF00D084).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                "${desafiosEmAberto.length} ATIVO(S)",
                style: const TextStyle(
                  color: Color(0xFF00D084),
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (desafiosEmAberto.isEmpty)
          Container(
            key: const Key('home_desafios_em_aberto_vazio'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF151E2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.sports_kabaddi, color: Color(0xFF64748B), size: 24),
                SizedBox(width: 12),
                Text(
                  "Nenhum desafio em aberto",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ...desafiosEmAberto.map((c) {
            return _buildDesafioItem(
              itemKey: Key('card_desafio_aberto_${c.id}'),
              botaoKey: Key('btn_detalhes_desafio_${c.id}'),
              jogador1: c.challengerId,
              jogador2: c.challengedId,
              subtitulo: "Partida #${c.matchId} • ${c.amount} BetCoins",
              statusLabel: c.status.label,
              statusColor: const Color(0xFF00D084),
              botaoLabel: "Detalhes do Desafio",
              onTap: () => _exibirDetalhesDesafio(context, c),
            );
          }),

        // 3. DESTAQUE: DESAFIOS RECENTEMENTE FINALIZADOS
        if (desafiosFinalizados.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                "DESAFIOS FINALIZADOS",
                key: Key('home_desafios_finalizados'),
                style: TextStyle(
                  color: Color(0xFF8E9CAE),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const Key('badge_desafios_finalizados'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: const Text(
                  "RESULTADOS",
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...desafiosFinalizados.map((c) {
            final venceu = currentUserId != null && c.winnerId == currentUserId;
            final resultadoLabel = c.winnerId != null
                ? (venceu ? "Você venceu!" : "Vencedor: ${c.winnerId}")
                : c.motivoDoCancelamento ?? "Status: ${c.status.label}";
            final resultadoColor = venceu
                ? const Color(0xFF00D084)
                : (c.winnerId != null ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8));

            return _buildDesafioItem(
              itemKey: Key('card_desafio_finalizado_${c.id}'),
              botaoKey: Key('btn_detalhes_desafio_finalizado_${c.id}'),
              jogador1: c.challengerId,
              jogador2: c.challengedId,
              subtitulo: "Partida #${c.matchId} • ${c.amount} BetCoins",
              statusLabel: resultadoLabel,
              statusColor: resultadoColor,
              botaoLabel: "Resultado",
              onTap: () => _exibirDetalhesDesafio(context, c),
            );
          }),
        ],
      ],
    );
  }
}
