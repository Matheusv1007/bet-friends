import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/firestore/challenge_repository.dart';
import '../models/challenge_model.dart';
import '../models/campeonato.dart';
import '../models/partida_model.dart';
import '../provider/partidas_provider.dart';
import '../services/challenge_service.dart';
import '../services/registro_de_erros.dart';
import '../services/user_profile_service.dart';
import '../models/carteira.dart';
import '../telas_principais/home_page.dart';
import '../tema/tema.dart';
import '../widgets/componentes.dart';
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
  bool _mostrarTodasPartidas = false;
  Campeonato? _filtroCampeonato;
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
      final service =
          widget.userProfileService ??
          context.read<UserProfileService?>() ??
          UserProfileService();
      _carteiraSubscription = service.observarCarteiraAtual().listen(
        (carteira) {
          if (!mounted) return;
          setState(() {
            saldoDisponivel = carteira?.saldoDisponivel;
            _erroSaldo = carteira == null ? 'Carteira indisponível.' : null;
          });
        },
        onError: (Object e, StackTrace s) {
          registrarErro('Observar saldo para criar desafio', e, s);
          if (mounted) {
            setState(() {
              saldoDisponivel = null;
              _erroSaldo = 'Não foi possível carregar o saldo.';
            });
          }
        },
      );
    } catch (e, s) {
      registrarErro('Observar saldo para criar desafio', e, s);
      setState(() => _erroSaldo = 'Não foi possível carregar o saldo.');
    }
  }

  Future<void> _carregarAmigos() async {
    setState(() {
      isLoadingAmigos = true;
      _erroAmigos = null;
    });
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
    if (selecionada == null || elegiveis.any((p) => p.id == selecionada)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || partidaId != selecionada) return;
      setState(() => partidaId = null);
      mostrarAviso(
        context,
        'A partida selecionada não está mais disponível. Escolha outra partida.',
        tom: Tom.atencao,
      );
    });
  }

  void _avisarErro(String texto, {int segundos = 2}) => mostrarAviso(
    context,
    texto,
    tom: Tom.destrutivo,
    duracao: Duration(seconds: segundos),
  );

  Future<void> _enviarDesafio() async {
    if (isSubmitting) return;
    final elegiveis = context
        .read<PartidasProvider>()
        .partidas
        .where((p) => p.podeCriarDesafio)
        .toList();
    if (partidaId != null && !elegiveis.any((p) => p.id == partidaId)) {
      _reconciliarSelecao(elegiveis);
      return;
    }
    if (partidaId == null) {
      _avisarErro('Selecione uma partida válida para criar o desafio.');
      return;
    }

    if (amigoId == null) {
      _avisarErro('Selecione um amigo para desafiar.');
      return;
    }

    if (valor < 10 || valor > 500) {
      _avisarErro('O valor deve ser entre 10 e 500 BetCoins.');
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

      mostrarAviso(
        context,
        'Desafio criado com sucesso! BetCoins reservadas.',
        tom: Tom.sucesso,
        duracao: const Duration(seconds: 3),
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
      _avisarErro(e.message, segundos: 3);
    } catch (e, s) {
      registrarErro('Criar desafio', e, s);
      if (!mounted) return;
      _avisarErro(
        'Não foi possível criar o desafio. Tente novamente.',
        segundos: 3,
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  void _voltar() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Homepage()),
        (route) => false,
      );
    }
  }

  static const _entreSecoes = SizedBox(height: EspacosApp.e24);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: _voltar,
        ),
        title: const Text('Criar desafio'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            EspacosApp.margemDaTela,
            EspacosApp.e8,
            EspacosApp.margemDaTela,
            EspacosApp.e24,
          ),
          children: [
            // Campeonato e partida
            Consumer<PartidasProvider>(
              builder: (context, partidasProvider, child) {
                final partidas = partidasProvider.partidas;
                final elegiveis = partidas
                    .where((p) => p.podeCriarDesafio)
                    .toList();
                if (!partidasProvider.isLoading &&
                    partidasProvider.errorMessage == null) {
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
                  mostrarTodas: _mostrarTodasPartidas,
                  onAlternarMostrarTodas: () => setState(
                    () => _mostrarTodasPartidas = !_mostrarTodasPartidas,
                  ),
                  filtro: _filtroCampeonato,
                  onFiltroChanged: (campeonato) => setState(() {
                    _filtroCampeonato = campeonato;
                    _mostrarTodasPartidas = false;
                  }),
                  acaoDoTitulo: partidasProvider.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(EspacosApp.e12),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : BotaoTexto(
                          rotulo: 'Atualizar',
                          pequeno: true,
                          onPressed: () =>
                              partidasProvider.carregarPartidas(forcar: true),
                        ),
                );
              },
            ),
            _entreSecoes,

            // Palpite do criador (RN-PRD-001)
            const TituloDeSecao('Seu palpite'),
            const SizedBox(height: EspacosApp.e8),
            Consumer<PartidasProvider>(
              builder: (context, provider, _) {
                PartidaModel? partidaAtual;
                for (final partida in provider.partidas) {
                  if (partida.id == partidaId) {
                    partidaAtual = partida;
                    break;
                  }
                }

                return SeletorPalpiteDesafio(
                  palpiteSelecionado: palpiteSelecionado,
                  labelMandante: partidaAtual?.timeMandante ?? 'Mandante',
                  labelVisitante: partidaAtual?.timeVisitante ?? 'Visitante',
                  onChanged: (palpite) =>
                      setState(() => palpiteSelecionado = palpite),
                );
              },
            ),
            _entreSecoes,

            // Valor do desafio, com o saldo disponível ao lado
            TituloDeSecao(
              'Valor',
              acao: _erroSaldo == null
                  ? SaldoDesafio(saldoDisponivel: saldoDisponivel)
                  : null,
            ),
            const SizedBox(height: EspacosApp.e8),
            if (_erroSaldo != null) ...[
              AvisoInline(
                _erroSaldo!,
                Tom.destrutivo,
                acao: BotaoTexto(
                  rotulo: 'Recarregar saldo',
                  pequeno: true,
                  onPressed: _observarSaldo,
                ),
              ),
              const SizedBox(height: EspacosApp.e8),
            ],
            SeletorValorDesafio(
              valor: valor,
              onChanged: (novoValor) => setState(() => valor = novoValor),
            ),
            _entreSecoes,

            // Amigo
            if (_erroAmigos != null) ...[
              AvisoInline(
                _erroAmigos!,
                Tom.destrutivo,
                acao: BotaoTexto(
                  rotulo: 'Recarregar amigos',
                  pequeno: true,
                  onPressed: _carregarAmigos,
                ),
              ),
              const SizedBox(height: EspacosApp.e8),
            ],
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
          ],
        ),
      ),
      bottomNavigationBar: EnviarDesafio(
        isSubmitting: isSubmitting,
        onPressed: _enviarDesafio,
      ),
    );
  }
}
