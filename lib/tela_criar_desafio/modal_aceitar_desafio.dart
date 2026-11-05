import 'package:flutter/material.dart';

import '../data/firestore/challenge_repository.dart';
import '../models/challenge_model.dart';
import '../services/challenge_service.dart';

/// Modal para aceitar um desafio pendente (RF-011).
///
/// Critérios de Aceitação:
/// - Somente o desafiado pode aceitar (RN-CHL-004);
/// - Desafio precisa estar PENDING (RN-CHL-008);
/// - Desafiado escolhe HOME_WIN, DRAW ou AWAY_WIN (RN-PRD-001);
/// - Palpite do desafiado é diferente do palpite do criador (RN-PRD-003);
/// - Saldo disponível do desafiado é suficiente (RN-BET-004);
/// - Valor do desafio não pode ser alterado (RN-CHL-024);
/// - Reserva do desafiado é concluída antes da mudança de estado (RN-CHL-016);
/// - Estado passa para ACCEPTED apenas após sucesso da reserva (RN-CHL-016).
class ModalAceitarDesafio extends StatefulWidget {
  final ChallengeModel desafio;
  final String? nomeCriador;
  final String? descricaoPartida;
  final ChallengeService? challengeService;

  const ModalAceitarDesafio({
    super.key,
    required this.desafio,
    this.nomeCriador,
    this.descricaoPartida,
    this.challengeService,
  });

  static Future<bool?> exibir({
    required BuildContext context,
    required ChallengeModel desafio,
    String? nomeCriador,
    String? descricaoPartida,
    ChallengeService? challengeService,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ModalAceitarDesafio(
        desafio: desafio,
        nomeCriador: nomeCriador,
        descricaoPartida: descricaoPartida,
        challengeService: challengeService,
      ),
    );
  }

  @override
  State<ModalAceitarDesafio> createState() => _ModalAceitarDesafioState();
}

class _ModalAceitarDesafioState extends State<ModalAceitarDesafio> {
  late final ChallengeService _challengeService;
  Palpite? _palpiteSelecionado;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _challengeService = widget.challengeService ?? ChallengeService();

    // Palpites permitidos para o desafiado: todos EXCETO o do criador (RN-PRD-003)
    final opcoesDisponiveis = Palpite.values
        .where((p) => p != widget.desafio.challengerPrediction)
        .toList();

    if (opcoesDisponiveis.isNotEmpty) {
      _palpiteSelecionado = opcoesDisponiveis.first;
    }
  }

  Future<void> _confirmarAceite() async {
    if (_palpiteSelecionado == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _challengeService.aceitarDesafio(
        challengeId: widget.desafio.id,
        challengedPrediction: _palpiteSelecionado!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desafio aceito com sucesso! Suas BetCoins foram reservadas.'),
          backgroundColor: Color(0xFF00D084),
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } on ChallengeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível aceitar o desafio. Tente novamente.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00D084);
    const cardBg = Color(0xFF0E1420);
    const textMuted = Color(0xFF8E9CAB);

    final opcoesPermitidas = Palpite.values
        .where((p) => p != widget.desafio.challengerPrediction)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra superior de fechar / título
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Aceitar Desafio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: textMuted),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Informações do desafio
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.nomeCriador != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Desafiado por ${widget.nomeCriador}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (widget.descricaoPartida != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.sports_soccer, size: 16, color: textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.descricaoPartida!,
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    const Icon(Icons.monetization_on_outlined, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Text(
                      'Valor apostado: ${widget.desafio.amount} BetCoins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.sports_score, size: 16, color: Color(0xFF60A5FA)),
                    const SizedBox(width: 8),
                    Text(
                      'Palpite do criador: ${widget.desafio.challengerPrediction.label}',
                      style: const TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seleção do palpite do desafiado (diferente do criador: RN-PRD-003)
          const Text(
            'ESCOLHA SEU PALPITE',
            style: TextStyle(
              color: textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'O palpite do desafiado deve ser diferente do palpite do criador.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: opcoesPermitidas.map((p) {
              final sel = _palpiteSelecionado == p;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _palpiteSelecionado = p),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? primaryGreen : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? primaryGreen : Colors.white.withValues(alpha: 0.08),
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sel ? const Color(0xFF062319) : Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Botão Confirmar Aceite
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: const Color(0xFF062319),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isSubmitting ? null : _confirmarAceite,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF062319),
                      ),
                    )
                  : const Text(
                      'CONFIRMAR E ACEITAR',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
