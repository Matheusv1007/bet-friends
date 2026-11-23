import 'package:flutter/material.dart';

import '../models/partida_model.dart';
import '../tela_criar_desafio/tela_criar_desafio.dart';
import 'escudo_do_time.dart';

/// Modal para exibição detalhada de uma partida com dados normalizados do domínio (KAN-43; RF-008, RN-MAT-005, RNF-005, RNF-013).
///
/// Diretrizes:
/// - Exibe mandante e visitante com destaque.
/// - Data e hora no fuso horário do dispositivo (RN-MAT-005).
/// - Status exibido a partir do enum/domínio interno (RF-008, RNF-013).
/// - Placar e resultado normalizado apresentados quando disponíveis.
/// - Nenhum enum ou payload bruto do provedor externo é exposto (RN-MAT-002, RNF-013).
class DetalhesDaPartidaDialog extends StatelessWidget {
  final PartidaModel partida;

  const DetalhesDaPartidaDialog({
    super.key,
    required this.partida,
  });

  /// Exibe o diálogo de detalhes da partida.
  static Future<void> exibir(BuildContext context, PartidaModel partida) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => DetalhesDaPartidaDialog(partida: partida),
    );
  }

  Color _corParaStatus(StatusPartida status) {
    switch (status) {
      case StatusPartida.agendada:
        return const Color(0xFF8A9BB5);
      case StatusPartida.emAndamento:
        return const Color(0xFFFFA726);
      case StatusPartida.finalizada:
        return const Color(0xFF00D084);
      case StatusPartida.adiada:
        return const Color(0xFFF59E0B);
      case StatusPartida.cancelada:
        return const Color(0xFFEF4444);
      case StatusPartida.suspensa:
      case StatusPartida.revisaoNecessaria:
        return const Color(0xFFA855F7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusCor = _corParaStatus(partida.statusDominio);
    final temPlacar = partida.golsMandante != null && partida.golsVisitante != null;
    final resultadoDescricao = partida.resultadoNormalizadoDescricao;

    return AlertDialog(
      backgroundColor: const Color(0xFF151E2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusCor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.sports_soccer,
              color: statusCor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detalhes da Partida',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${partida.campeonato ?? 'Brasileirão Série A'}${partida.matchday != null ? ' • Rodada ${partida.matchday}' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF8A9BB5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bloco do Confronto e Placar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  // Mandante
                  Expanded(
                    child: Column(
                      children: [
                        EscudoDoTime(
                          key: const Key('detalhes_partida_escudo_mandante'),
                          url: partida.logoMandante,
                          nome: partida.timeMandante,
                          tamanho: 48,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          partida.timeMandante,
                          key: const Key('detalhes_partida_mandante'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Mandante',
                          style: TextStyle(
                            color: Color(0xFF8A9BB5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Placar ou vs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        if (temPlacar) ...[
                          Text(
                            partida.placarTexto,
                            key: const Key('detalhes_partida_placar'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'VS',
                            style: TextStyle(
                              color: Color(0xFF8A9BB5),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Visitante
                  Expanded(
                    child: Column(
                      children: [
                        EscudoDoTime(
                          key: const Key('detalhes_partida_escudo_visitante'),
                          url: partida.logoVisitante,
                          nome: partida.timeVisitante,
                          tamanho: 48,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          partida.timeVisitante,
                          key: const Key('detalhes_partida_visitante'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Visitante',
                          style: TextStyle(
                            color: Color(0xFF8A9BB5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Informações Normalizadas do Domínio
            // 1. Data e Hora no fuso local
            _buildLinhaInfo(
              icone: Icons.access_time_rounded,
              titulo: 'Data e Hora (Local)',
              valor: partida.dataHoraLocalFormatada,
              valorKey: const Key('detalhes_partida_data_hora'),
              corValor: Colors.white,
            ),
            const SizedBox(height: 10),

            // 2. Status no Domínio Interno
            _buildLinhaInfo(
              icone: Icons.flag_rounded,
              titulo: 'Status',
              valor: partida.statusDominio.rotulo,
              valorKey: const Key('detalhes_partida_status'),
              corValor: statusCor,
            ),
            const SizedBox(height: 10),

            // 3. Resultado Normalizado (quando disponível)
            if (resultadoDescricao != null) ...[
              _buildLinhaInfo(
                icone: Icons.emoji_events_rounded,
                titulo: 'Resultado Oficial',
                valor: resultadoDescricao,
                valorKey: const Key('detalhes_partida_resultado'),
                corValor: const Color(0xFF00D084),
              ),
              const SizedBox(height: 10),
            ] else if (!temPlacar) ...[
              Container(
                key: const Key('detalhes_partida_sem_placar'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF8A9BB5),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Partida ainda não iniciada ou sem placar confirmado.',
                        style: TextStyle(
                          color: Color(0xFF8A9BB5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Botão para criar desafio na partida (se elegível)
            if (partida.podeCriarDesafio) ...[
              const SizedBox(height: 6),
              ElevatedButton.icon(
                key: const Key('btn_desafiar_partida'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CriarDesafioScreen(
                        preSelectedMatchId: partida.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text(
                  'DESAFIAR NESTA PARTIDA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D084),
                  foregroundColor: const Color(0xFF062319),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('btn_fechar_detalhes_partida'),
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Fechar',
            style: TextStyle(
              color: Color(0xFF00D084),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinhaInfo({
    required IconData icone,
    required String titulo,
    required String valor,
    required Key valorKey,
    required Color corValor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icone, color: const Color(0xFF8A9BB5), size: 18),
          const SizedBox(width: 10),
          Text(
            titulo,
            style: const TextStyle(
              color: Color(0xFF8A9BB5),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              valor,
              key: valorKey,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: corValor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
