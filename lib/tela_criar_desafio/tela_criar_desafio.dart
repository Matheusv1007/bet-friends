import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/challenge_repository.dart';
import '../models/challenge_model.dart';
import '../models/partida_model.dart';
import '../provider/partidas_provider.dart';
import '../services/challenge_service.dart';
import '../services/registro_de_erros.dart';
import '../services/user_profile_service.dart';
import '../models/carteira.dart';
import '../telas_principais/home_page.dart';
import 'saldo_desafio.dart';
import 'seletor_valor_desafio.dart';
import 'enviar_desafio.dart';
import 'seletor_palpite_desafio.dart';
import 'seletor_amigo_desafio.dart';
import 'seletor_partida_desafio.dart';

class CriarDesafioScreen extends StatefulWidget {
  final String? preSelectedFriendId;
  final String? preSelectedFriendName;
  final String? preSelectedMatchId;
  final ChallengeService? challengeService;
  final List<AmigoItem>? amigosIniciais;
  final int? saldoInicial;
  final UserProfileService? userProfileService;

  const CriarDesafioScreen({
    super.key,
    this.preSelectedFriendId,
    this.preSelectedFriendName,
    this.preSelectedMatchId,
    this.challengeService,
    this.amigosIniciais,
    this.saldoInicial,
    this.userProfileService,
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
  StreamSubscription<Carteira?>? _carteiraSubscription;
  String? _erroSaldo;
  String? _erroAmigos;

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
      if (widget.saldoInicial == null) _observarSaldo();
      if (widget.amigosIniciais == null) _carregarAmigos();
    });
  }

  void _observarSaldo() {
    _carteiraSubscription?.cancel();
    setState(() => _erroSaldo = null);
    try {
      final service = widget.userProfileService ??
          context.read<UserProfileService?>() ?? UserProfileService();
      _carteiraSubscription = service.observarCarteiraAtual().listen((carteira) {
        if (!mounted) return;
        setState(() {
          saldoDisponivel = carteira?.saldoDisponivel;
          _erroSaldo = carteira == null ? 'Carteira indisponível.' : null;
        });
      }, onError: (Object e, StackTrace s) {
        registrarErro('Observar saldo para criar desafio', e, s);
        if (mounted) {
          setState(() {
            saldoDisponivel = null;
            _erroSaldo = 'Não foi possível carregar o saldo.';
          });
        }
      });
    } catch (e, s) {
      registrarErro('Observar saldo para criar desafio', e, s);
      setState(() => _erroSaldo = 'Não foi possível carregar o saldo.');
    }
  }

  Future<void> _carregarAmigos() async {
    setState(() { isLoadingAmigos = true; _erroAmigos = null; });
    try {
      final amigos = await _challengeService.listarAmigosAceitos();
      if (!mounted) return;
      setState(() {
        amigosAceitos = amigos;
        if (amigoId == null && amigos.isNotEmpty) {
          amigoId = amigos.first.uid;
          amigoNome = amigos.first.displayName;
        }
      });
    } catch (e, s) {
      registrarErro('Carregar amigos para criar desafio', e, s);
      if (mounted) {
        setState(() => _erroAmigos = 'Não foi possível carregar os amigos.');
      }
    } finally {
      if (mounted) setState(() => isLoadingAmigos = false);
    }
  }

  @override
  void dispose() {
    _carteiraSubscription?.cancel();
    super.dispose();
  }

  void _reconciliarSelecao(List<PartidaModel> elegiveis) {
    final selecionada = partidaId;
    if (selecionada == null || elegiveis.any((p) => p.id == selecionada)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || partidaId != selecionada) return;
      setState(() => partidaId = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('A partida selecionada não está mais disponível. Escolha outra partida.'),
      ));
    });
  }

  Future<void> _enviarDesafio() async {
    if (isSubmitting) return;
    final elegiveis = context.read<PartidasProvider>().partidas
        .where((p) => p.podeCriarDesafio).toList();
    if (partidaId != null && !elegiveis.any((p) => p.id == partidaId)) {
      _reconciliarSelecao(elegiveis);
      return;
    }
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
    } catch (e, s) {
      registrarErro('Criar desafio', e, s);
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
    const primaryGreen = Color(0xFF00D084);

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
              if (_erroSaldo == null)
                SaldoDesafio(saldoDisponivel: saldoDisponivel)
              else
                Column(children: [
                  Text(_erroSaldo!, style: const TextStyle(color: Colors.white)),
                  TextButton(onPressed: _observarSaldo,
                    child: const Text('Tentar novamente: saldo')),
                ]),
              const SizedBox(height: 22),

              // Seção Escolha a Partida
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ESCOLHA A PARTIDA',
                    style: TextStyle(
                      color: Color(0xFF8E9CAB),
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
                      return TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                        onPressed: () => provider.carregarPartidas(forcar: true),
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
                  final partidas = partidasProvider.partidas;
                  final elegiveis = partidas.where((p) => p.podeCriarDesafio).toList();
                  if (!partidasProvider.isLoading && partidasProvider.errorMessage == null) {
                    _reconciliarSelecao(elegiveis);
                  }
                  return SeletorPartidaDesafio(
                    isLoading: partidasProvider.isLoading,
                    errorMessage: partidasProvider.errorMessage,
                    partidas: partidas,
                    elegiveis: elegiveis,
                    partidaId: partidaId,
                    onRecarregar: () =>
                        partidasProvider.carregarPartidas(forcar: true),
                    onChanged: (id) => setState(() => partidaId = id),
                  );
                },
              ),
              const SizedBox(height: 18),

              // Seção Palpite do Criador (RN-PRD-001)
              const Text(
                'SEU PALPITE NO JOGO',
                style: TextStyle(
                  color: Color(0xFF8E9CAB),
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Consumer<PartidasProvider>(
                builder: (context, provider, _) {
                  PartidaModel? partidaAtual;
                  for (final partida in provider.partidas) {
                    if (partida.id == partidaId) {
                      partidaAtual = partida;
                      break;
                    }
                  }

                  final labelMandante = partidaAtual != null ? 'Vitória ${partidaAtual.timeMandante}' : 'Mandante';
                  final labelVisitante = partidaAtual != null ? 'Vitória ${partidaAtual.timeVisitante}' : 'Visitante';

                  return SeletorPalpiteDesafio(
                    palpiteSelecionado: palpiteSelecionado,
                    labelMandante: labelMandante,
                    labelVisitante: labelVisitante,
                    onChanged: (palpite) =>
                        setState(() => palpiteSelecionado = palpite),
                  );
                },
              ),
              const SizedBox(height: 22),

              // Seção Valor do Desafio
              SeletorValorDesafio(
                valor: valor,
                onChanged: (novoValor) => setState(() => valor = novoValor),
              ),
              const SizedBox(height: 22),

              // Seção Convidar Amigo
              if (_erroAmigos != null)
                Column(children: [
                  Text(_erroAmigos!, style: const TextStyle(color: Colors.white)),
                  TextButton(onPressed: _carregarAmigos,
                    child: const Text('Tentar novamente: amigos')),
                ]),
              SeletorAmigoDesafio(
                isLoadingAmigos: isLoadingAmigos,
                amigosAceitos: amigosAceitos,
                amigoId: amigoId,
                amigoNome: amigoNome,
                onChanged: (uid, nome) => setState(() {
                  amigoId = uid;
                  amigoNome = nome;
                }),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EnviarDesafio(
        isSubmitting: isSubmitting,
        onPressed: _enviarDesafio,
      ),
    );
  }

}
