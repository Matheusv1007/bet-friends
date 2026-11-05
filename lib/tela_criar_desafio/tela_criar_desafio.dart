import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/challenge_repository.dart';
import '../models/challenge_model.dart';
import '../models/partida_model.dart';
import '../provider/partidas_provider.dart';
import '../services/challenge_service.dart';
import '../telas_principais/homePage.dart';

class CriarDesafioScreen extends StatefulWidget {
  final String? preSelectedFriendId;
  final String? preSelectedFriendName;
  final String? preSelectedMatchId;
  final ChallengeService? challengeService;
  final List<AmigoItem>? amigosIniciais;
  final int? saldoInicial;

  const CriarDesafioScreen({
    super.key,
    this.preSelectedFriendId,
    this.preSelectedFriendName,
    this.preSelectedMatchId,
    this.challengeService,
    this.amigosIniciais,
    this.saldoInicial,
  });

  @override
  State<CriarDesafioScreen> createState() => _CriarDesafioScreenState();
}

class _CriarDesafioScreenState extends State<CriarDesafioScreen> {
  late final ChallengeService _challengeService;

  int valor = 50;
  String? partidaId;
  Palpite palpiteSelecionado = Palpite.homeWin;
  String? amigoId;
  String? amigoNome;

  List<AmigoItem> amigosAceitos = [];
  bool isLoadingAmigos = false;
  bool isSubmitting = false;

  int? saldoDisponivel;

  @override
  void initState() {
    super.initState();
    _challengeService = widget.challengeService ?? ChallengeService();

    partidaId = widget.preSelectedMatchId;
    amigoId = widget.preSelectedFriendId;
    amigoNome = widget.preSelectedFriendName;

    if (widget.amigosIniciais != null) {
      amigosAceitos = widget.amigosIniciais!;
    }
    if (widget.saldoInicial != null) {
      saldoDisponivel = widget.saldoInicial;
    }

    // Garante o carregamento das partidas reais da API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PartidasProvider>();
      if (provider.partidas.isEmpty) {
        provider.carregarPartidas();
      }
      _carregarAmigosESaldo();
    });
  }

  Future<void> _carregarAmigosESaldo() async {
    setState(() => isLoadingAmigos = true);

    try {
      final saldo = await _challengeService.buscarSaldoDisponivel();
      final amigos = await _challengeService.listarAmigosAceitos();

      if (mounted) {
        setState(() {
          if (saldo != null) {
            saldoDisponivel = saldo;
          }
          if (amigos.isNotEmpty) {
            amigosAceitos = amigos;
            if (amigoId == null) {
              amigoId = amigos.first.uid;
              amigoNome = amigos.first.displayName;
            }
          }
        });
      }
    } catch (_) {
      // Falha silenciosa de carregamento inicial
    } finally {
      if (mounted) {
        setState(() => isLoadingAmigos = false);
      }
    }
  }

  void _reconciliarSelecao(List<PartidaModel> elegiveis) {
    if (elegiveis.isEmpty) {
      if (partidaId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && partidaId != null) {
            setState(() => partidaId = null);
          }
        });
      }
      return;
    }

    final atualAindaExiste = elegiveis.any((p) => p.id == partidaId);
    if (!atualAindaExiste) {
      final primeiroId = elegiveis.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && partidaId != primeiroId) {
          setState(() => partidaId = primeiroId);
        }
      });
    }
  }

  Future<void> _enviarDesafio() async {
    if (partidaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma partida válida para criar o desafio.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (amigoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um amigo para desafiar.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (valor < 10 || valor > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O valor deve ser entre 10 e 500 BetCoins.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await _challengeService.criarDesafio(
        challengedId: amigoId!,
        matchId: partidaId!,
        challengerPrediction: palpiteSelecionado,
        amount: valor,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desafio criado com sucesso! BetCoins reservadas.'),
          backgroundColor: Color(0xFF00D084),
          duration: Duration(seconds: 3),
        ),
      );

      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Homepage()),
          (route) => false,
        );
      }
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
          content: Text('Não foi possível criar o desafio. Tente novamente.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgScaffold = Color(0xFF0B111D);
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const Homepage()),
                (route) => false,
              );
            }
          },
        ),
        title: const Text(
          'Criar Desafio',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFF1B2536), height: 1),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.85, -0.9),
            radius: 1.2,
            colors: [
              Color(0xFF0F2624),
              Color(0xFF0B111D),
              Color(0xFF0B111D),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // Card de Saldo Disponível
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2624),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryGreen.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SALDO DISPONÍVEL',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          saldoDisponivel != null ? '$saldoDisponivel BetCoins' : 'Carregando...',
                          key: const Key('criar_desafio_saldo'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Seção Escolha a Partida
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ESCOLHA A PARTIDA',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Consumer<PartidasProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading) {
                        return const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryGreen,
                          ),
                        );
                      }
                      return GestureDetector(
                        onTap: () => provider.carregarPartidas(),
                        child: const Row(
                          children: [
                            Icon(Icons.refresh, size: 14, color: primaryGreen),
                            SizedBox(width: 4),
                            Text(
                              'Atualizar',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Lista dinâmica com partidas
              Consumer<PartidasProvider>(
                builder: (context, partidasProvider, child) {
                  if (partidasProvider.isLoading && partidasProvider.partidas.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(color: primaryGreen),
                      ),
                    );
                  }

                  if (partidasProvider.errorMessage != null && partidasProvider.partidas.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFFEF4444)),
                          const SizedBox(height: 12),
                          const Text(
                            'Erro ao carregar partidas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            partidasProvider.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: textMuted, fontSize: 12.5),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => partidasProvider.carregarPartidas(),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Tentar novamente'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: const Color(0xFF062319),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final partidas = partidasProvider.partidas;

                  if (partidas.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.sports_soccer, size: 32, color: Color(0xFF64748B)),
                          const SizedBox(height: 8),
                          const Text(
                            'Nenhuma partida encontrada no momento',
                            style: TextStyle(color: textMuted, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => partidasProvider.carregarPartidas(),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Carregar partidas'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: const Color(0xFF062319),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final elegiveis = partidas.where((p) => p.podeCriarDesafio).toList();
                  _reconciliarSelecao(elegiveis);

                  if (elegiveis.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Nenhuma partida agendada disponível para apostas no momento.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textMuted, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  final partidaAtivaId = partidaId ?? elegiveis.first.id;

                  return Column(
                    children: elegiveis.map((PartidaModel p) {
                      final sel = partidaAtivaId == p.id;
                      final horarioOuStatus = p.horario ?? p.status;

                      return GestureDetector(
                        onTap: () => setState(() => partidaId = p.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF0E2924) : cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel ? primaryGreen : Colors.white.withValues(alpha: 0.05),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sports_soccer,
                                size: 20,
                                color: sel ? primaryGreen : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.timeMandante,
                                  style: TextStyle(
                                    color: sel ? primaryGreen : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    'x',
                                    style: TextStyle(
                                      color: sel ? primaryGreen : textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    horarioOuStatus,
                                    style: const TextStyle(
                                      color: textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Text(
                                  p.timeVisitante,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    color: sel ? primaryGreen : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.sports_soccer,
                                size: 20,
                                color: sel ? primaryGreen : const Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 18),

              // Seção Palpite do Criador (RN-PRD-001)
              const Text(
                'SEU PALPITE NO JOGO',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Consumer<PartidasProvider>(
                builder: (context, provider, _) {
                  PartidaModel? partidaAtual;
                  try {
                    partidaAtual = provider.partidas.firstWhere((p) => p.id == partidaId);
                  } catch (_) {
                    partidaAtual = provider.partidas.isNotEmpty
                        ? provider.partidas.first
                        : null;
                  }

                  final labelMandante = partidaAtual != null ? 'Vitória ${partidaAtual.timeMandante}' : 'Mandante';
                  final labelVisitante = partidaAtual != null ? 'Vitória ${partidaAtual.timeVisitante}' : 'Visitante';

                  return Row(
                    children: [
                      _buildPredictionButton(
                        Palpite.homeWin,
                        labelMandante,
                        key: const Key('palpite_home_win'),
                      ),
                      const SizedBox(width: 8),
                      _buildPredictionButton(
                        Palpite.draw,
                        'Empate',
                        key: const Key('palpite_draw'),
                      ),
                      const SizedBox(width: 8),
                      _buildPredictionButton(
                        Palpite.awayWin,
                        labelVisitante,
                        key: const Key('palpite_away_win'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),

              // Seção Valor do Desafio
              const Text(
                'VALOR DO DESAFIO (BetCoins)',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BetCoins apostadas',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$valor BetCoins',
                      key: const Key('valor_selecionado_label'),
                      style: const TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [10, 25, 50, 100].map((v) {
                  final sel = valor == v;
                  return Expanded(
                    child: GestureDetector(
                      key: Key('chip_valor_$v'),
                      onTap: () => setState(() => valor = v),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? primaryGreen : cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel ? primaryGreen : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$v',
                          style: TextStyle(
                            color: sel ? const Color(0xFF062319) : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // Seção Convidar Amigo
              const Text(
                'SELECIONE O AMIGO',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              if (isLoadingAmigos)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: primaryGreen),
                  ),
                )
              else if (amigosAceitos.isEmpty && amigoId == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Você ainda não possui amigos aceitos. Adicione amigos na aba Amigos para poder criar desafios.',
                    style: TextStyle(color: textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                if (amigoId != null && !amigosAceitos.any((a) => a.uid == amigoId))
                  _buildAmigoCard(
                    uid: amigoId!,
                    displayName: amigoNome ?? 'Amigo Selecionado',
                    isSelected: true,
                  ),
                ...amigosAceitos.map((amigo) {
                  final sel = amigoId == amigo.uid;
                  return _buildAmigoCard(
                    uid: amigo.uid,
                    displayName: amigo.displayName,
                    username: amigo.username,
                    isSelected: sel,
                  );
                }),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0E1420),
          border: Border(
            top: BorderSide(
              color: Color(0xFF1B2536),
              width: 1,
            ),
          ),
        ),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            key: const Key('btn_enviar_desafio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: const Color(0xFF062319),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: isSubmitting ? null : _enviarDesafio,
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF062319),
                    ),
                  )
                : const Text(
                    'ENVIAR DESAFIO',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionButton(Palpite p, String label, {Key? key}) {
    final sel = palpiteSelecionado == p;
    const primaryGreen = Color(0xFF00D084);
    const cardBg = Color(0xFF151E2E);

    return Expanded(
      child: GestureDetector(
        key: key,
        onTap: () => setState(() => palpiteSelecionado = p),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
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
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: sel ? const Color(0xFF062319) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmigoCard({
    required String uid,
    required String displayName,
    String? username,
    required bool isSelected,
  }) {
    const primaryGreen = Color(0xFF00D084);
    const cardBg = Color(0xFF151E2E);

    return GestureDetector(
      key: Key('amigo_item_$uid'),
      onTap: () => setState(() {
        amigoId = uid;
        amigoNome = displayName;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0E2924) : cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFF334155),
              child: Icon(Icons.person_outline, size: 17, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: isSelected ? primaryGreen : Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (username != null)
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: Color(0xFF8E9CAB),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? primaryGreen : const Color(0xFF64748B),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
