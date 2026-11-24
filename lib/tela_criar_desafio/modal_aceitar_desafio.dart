import 'package:flutter/material.dart';

import '../data/firestore/challenge_repository.dart';
import '../models/challenge_model.dart';
import '../services/challenge_service.dart';
import '../services/registro_de_erros.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';

/// Recusa [desafio] (vira REJECTED e a reserva do criador é liberada) e avisa
/// o resultado. Devolve `true` quando o servidor confirmou. Usada pelo modal e
/// pelo "Recusar" da lista de recebidos, depois da confirmação.
Future<bool> recusarDesafioComAviso(
  BuildContext context,
  ChallengeService service,
  ChallengeModel desafio,
) {
  return _responderDesafio(
    context,
    () => service.recusarDesafio(challengeId: desafio.id),
    sucesso: 'Desafio recusado.',
    falha: 'Não foi possível recusar o desafio. Tente novamente.',
  );
}

/// Executa [acao] e mostra o aviso de sucesso ou de falha; `true` em caso de sucesso.
Future<bool> _responderDesafio(
  BuildContext context,
  Future<void> Function() acao, {
  required String sucesso,
  required String falha,
}) async {
  String mensagem;
  var ok = false;
  try {
    await acao();
    mensagem = sucesso;
    ok = true;
  } on ChallengeException catch (e) {
    mensagem = e.message;
  } catch (e, s) {
    registrarErro('Responder ao desafio', e, s);
    mensagem = falha;
  }
  if (context.mounted) {
    mostrarAviso(context, mensagem, tom: ok ? Tom.sucesso : Tom.destrutivo);
  }
  return ok;
}

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
      isDismissible: false,
      enableDrag: false,
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

  // Palpites permitidos para o desafiado: todos EXCETO o do criador (RN-PRD-003)
  List<Palpite> get _opcoesPermitidas =>
      Palpite.values.where((p) => p != widget.desafio.challengerPrediction).toList();

  @override
  void initState() {
    super.initState();
    _challengeService = widget.challengeService ?? ChallengeService();
    final opcoes = _opcoesPermitidas;
    if (opcoes.isNotEmpty) _palpiteSelecionado = opcoes.first;
  }

  Future<void> _confirmarAceite() {
    final palpite = _palpiteSelecionado;
    if (palpite == null) return Future.value();

    return _executar(
      () => _responderDesafio(
        context,
        () => _challengeService.aceitarDesafio(
          challengeId: widget.desafio.id,
          challengedPrediction: palpite,
        ),
        sucesso: 'Desafio aceito com sucesso! Suas BetCoins foram reservadas.',
        falha: 'Não foi possível aceitar o desafio. Tente novamente.',
      ),
    );
  }

  Future<void> _recusar() =>
      _executar(() => recusarDesafioComAviso(context, _challengeService, widget.desafio));

  /// Executa [acao] com os botões travados e fecha o modal com `true` em caso de sucesso.
  Future<void> _executar(Future<bool> Function() acao) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final ok = await acao();
      if (ok && mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.desafio;
    final nome = widget.nomeCriador;

    return PopScope(
      canPop: !_isSubmitting,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: EspacosApp.e20,
            right: EspacosApp.e20,
            top: EspacosApp.e12,
            bottom: MediaQuery.of(context).viewInsets.bottom + EspacosApp.e20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aceitar desafio',
                      style: TextoApp.tituloDeBarra.copyWith(color: CoresApp.texto),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close, color: CoresApp.textoSuave),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: EspacosApp.e8),

              // Resumo do desafio em linhas
              Container(
                decoration: const BoxDecoration(
                  color: CoresApp.superficie2,
                  borderRadius: RaiosApp.bordaCartao,
                ),
                child: Column(
                  children: [
                    if (nome != null) _LinhaDoResumo('Desafiado por', nome),
                    if (widget.descricaoPartida != null)
                      _LinhaDoResumo('Partida', widget.descricaoPartida!),
                    _LinhaDoResumo(
                      'Valor apostado',
                      '${d.amount} BetCoins',
                      chave: const Key('modal_aceitar_valor'),
                    ),
                    _LinhaDoResumo(
                      nome == null ? 'Palpite do criador' : 'Palpite de ${nome.split(' ').first}',
                      d.challengerPrediction.label,
                      chave: const Key('modal_aceitar_palpite_criador'),
                    ),
                    _LinhaDoResumo('Prêmio se acertar', '+${d.amount} BetCoins', divisor: false),
                  ],
                ),
              ),
              const SizedBox(height: EspacosApp.e20),

              // Seleção do palpite do desafiado (diferente do criador: RN-PRD-003)
              const TituloDeSecao('Seu palpite'),
              const Text(
                'Escolha um palpite diferente do palpite do criador.',
                style: TextoApp.secundario,
              ),
              const SizedBox(height: EspacosApp.e8),
              _SeletorDePalpite(
                opcoes: _opcoesPermitidas,
                selecionado: _palpiteSelecionado,
                onChanged: _isSubmitting ? null : (p) => setState(() => _palpiteSelecionado = p),
              ),
              const SizedBox(height: EspacosApp.e24),

              BotaoPrimario(
                key: const Key('btn_confirmar_aceite'),
                rotulo: 'Confirmar e aceitar',
                larguraTotal: true,
                onPressed: _isSubmitting ? null : _confirmarAceite,
              ),
              const SizedBox(height: EspacosApp.e8),

              // Recusa: o desafio vira REJECTED e a reserva do criador é liberada
              BotaoDestrutivo(
                key: const Key('btn_recusar_desafio'),
                rotulo: 'Recusar desafio',
                larguraTotal: true,
                onPressed: _isSubmitting ? null : _recusar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaDoResumo extends StatelessWidget {
  final String rotulo;
  final String valor;
  final bool divisor;
  final Key? chave;

  const _LinhaDoResumo(this.rotulo, this.valor, {this.divisor = true, this.chave});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: chave,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: EspacosApp.e12, vertical: EspacosApp.e8),
      decoration: divisor
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: CoresApp.filete)))
          : null,
      child: Row(
        children: [
          Text(rotulo, style: TextoApp.secundario),
          const SizedBox(width: EspacosApp.e12),
          // Nomes e partidas longos quebram em até 2 linhas, sem estourar a linha
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextoApp.corpoForte.copyWith(color: CoresApp.texto),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grupo segmentado com apenas os palpites permitidos.
class _SeletorDePalpite extends StatelessWidget {
  final List<Palpite> opcoes;
  final Palpite? selecionado;
  final ValueChanged<Palpite>? onChanged;

  const _SeletorDePalpite({required this.opcoes, required this.selecionado, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspacosApp.e4),
      decoration: BoxDecoration(
        color: CoresApp.superficie2,
        borderRadius: RaiosApp.bordaBotao,
        border: Border.all(color: CoresApp.contorno),
      ),
      child: Row(
        children: [
          for (final p in opcoes)
            Expanded(
              child: Semantics(
                button: true,
                selected: p == selecionado,
                inMutuallyExclusiveGroup: true,
                child: Material(
                  color: p == selecionado ? CoresApp.primario : Colors.transparent,
                  borderRadius: RaiosApp.bordaChip,
                  child: InkWell(
                    key: Key('palpite_aceite_${p.valor}'),
                    borderRadius: RaiosApp.bordaChip,
                    onTap: onChanged == null ? null : () => onChanged!(p),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: EspacosApp.alvoDeToque),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: EspacosApp.e8, vertical: EspacosApp.e4),
                      child: Text(
                        p.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextoApp.corpoForte.copyWith(
                          color: p == selecionado ? CoresApp.sobrePrimario : CoresApp.texto,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
