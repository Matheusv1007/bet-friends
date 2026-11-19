import 'dart:async';

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/provider/auth_provider.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/services/registro_de_erros.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:betfriends/widgets_home_page/appbar_das_partidas.dart';
import 'package:betfriends/widgets_home_page/card_de_desafio.dart';
import 'package:betfriends/widgets_home_page/card_de_desafios_ativos.dart';
import 'package:betfriends/widgets_home_page/card_de_carteira.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:betfriends/services/auth_service.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/widgets_home_page/alerta_desafios_pendentes_home.dart';
import 'package:betfriends/widgets_home_page/barra_navegacao_home.dart';
import 'package:betfriends/widgets_home_page/cabecalho_home.dart';
import 'package:betfriends/widgets_home_page/lista_partidas_home.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Homepage extends StatefulWidget {
  final ChallengeService? challengeService;
  final AuthService? authService;
  final Duration? pollingInterval;

  /// Intervalo ajustado de polling em segundo plano (KAN-105: reduz consumo da API)
  static const Duration intervalPollingPadrao = Duration(minutes: 5);

  const Homepage({
    super.key,
    this.challengeService,
    this.authService,
    this.pollingInterval,
  });

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with WidgetsBindingObserver {
  int _currentNavIndex = 0;
  Timer? _realTimeTimer;
  bool _mostrarTodas = false;

  /// Perfil do usuário logado, usado só na saudação; `null` se indisponível.
  Stream<PerfilObservado>? _perfil;
  Stream<List<ChallengeModel>>? _desafios;

  // Lista de fallback com o design original (comentada, mantida apenas para testes futuros)
  /*
  final List<PartidaModel> _mockDesignPartidas = [
    PartidaModel(
      id: 'mock-1',
      timeMandante: 'Flamengo',
      timeVisitante: 'Vasco',
      golsMandante: 2,
      golsVisitante: 0,
      status: 'FINALIZADO',
    ),
    PartidaModel(
      id: 'mock-2',
      timeMandante: 'Vasco',
      timeVisitante: 'Fluminense',
      golsMandante: 1,
      golsVisitante: 1,
      status: 'EM ANDAMENTO',
    ),
    PartidaModel(
      id: 'mock-3',
      timeMandante: 'Volta Redonda',
      timeVisitante: 'SCCP',
      status: 'PRÓXIMO JOGO',
      horario: 'Amanhã 19:00',
    ),
  ];
  */

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _perfil = _observarPerfil();
    _desafios = _observarDesafios();

    // 1. Dispara a primeira busca na API logo que a tela é montada se necessário
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PartidasProvider>();
      if (provider.partidas.isEmpty || provider.deveAtualizar) {
        provider.carregarPartidas();
      }
    });

    // 2. POLLING EM TEMPO REAL AJUSTADO (KAN-105): Atualiza periodicamente com consumo reduzido
    _iniciarPolling();
  }

  void _iniciarPolling() {
    _realTimeTimer?.cancel();
    final solicitado = widget.pollingInterval ?? Homepage.intervalPollingPadrao;
    final intervalo = solicitado < Homepage.intervalPollingPadrao
        ? Homepage.intervalPollingPadrao : solicitado;
    _realTimeTimer = Timer.periodic(intervalo, (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        context.read<PartidasProvider>().carregarPartidas(silencioso: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _iniciarPolling();
    } else {
      _realTimeTimer?.cancel();
    }
  }

  Stream<List<ChallengeModel>>? _observarDesafios() {
    final service = widget.challengeService ?? context.read<ChallengeService?>();
    try {
      final s = service?.observarDesafios();
      return s == null ? null : (s.isBroadcast ? s : s.asBroadcastStream());
    } catch (e, s) {
      registrarErro('Observar desafios na página inicial', e, s);
      return Stream.error(e, s);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _perfil ??= _observarPerfil();
    _desafios ??= _observarDesafios();
  }

  Stream<PerfilObservado>? _observarPerfil() {
    // Leitura opcional, como no menu da conta: a Home também é montada sem o serviço
    final service = context.read<UserProfileService?>();
    try {
      final s = service?.observarPerfilAtual();
      return s == null ? null : (s.isBroadcast ? s : s.asBroadcastStream());
    } catch (e, s) {
      registrarErro('Observar perfil na página inicial', e, s);
      return null;
    }
  }

  @override
  void dispose() {
    // Cancela o timer quando a tela for fechada para economizar bateria e rede
    _realTimeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B111D),
      body: Container(
        decoration: const BoxDecoration(
          // Gradiente sutil com leve aura esmeralda no topo esquerdo
          gradient: RadialGradient(
            center: Alignment(-0.85, -0.9),
            radius: 1.2,
            colors: [Color(0xFF0F2624), Color(0xFF0B111D), Color(0xFF0B111D)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFF00D084),
            backgroundColor: const Color(0xFF151E2E),
            onRefresh: () =>
                context.read<PartidasProvider>().carregarPartidas(forcar: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABEÇALHO PERSONALIZADO (Avatar, Saudação, Fichas e Logo)
                  CabecalhoHome(
                    perfil: _perfil,
                    // Leitura opcional: a Home também é montada isoladamente em widget tests.
                    saindo: context.watch<AuthProvider?>()?.isSigningOut ?? false,
                    onLogout: _confirmarLogout,
                  ),

                  const SizedBox(height: 20),

                  // CARD DESAFIO RÁPIDO 1V1
                  const Carddedesafio(),

                  const SizedBox(height: 18),

                  // CARTEIRA BETCOINS REAL (KAN-69; RF-003, RN-BET-004)
                  StreamBuilder<PerfilObservado>(
                    stream: _perfil,
                    builder: (context, snapshot) {
                      final carteira = snapshot.hasError ? null : snapshot.data?.carteira;
                      if (carteira == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18.0),
                        child: Carddecarteira(
                          carteira: carteira,
                          semConexao: snapshot.data?.doCache ?? false,
                        ),
                      );
                    },
                  ),

                  // ALERTA DESTAQUE: DESAFIOS RECEBIDOS AGUARDANDO RESPOSTA (D-003, Plano Mestre v3.2)
                  StreamBuilder<List<ChallengeModel>>(
                    stream: _desafios,
                    builder: (context, snapshot) {
                      final desafios = snapshot.hasError ? null : snapshot.data;
                      final authProvider = context.watch<AuthProvider?>();
                      final currentUid = authProvider?.currentUser?.uid ??
                          widget.authService?.currentUser?.uid ??
                          context.read<AuthService?>()?.currentUser?.uid;

                      final pendentesRecebidos = desafios?.where((c) {
                        final isPending = c.status == StatusDesafio.pending;
                        final isChallenged = currentUid == null || c.challengedId == currentUid;
                        return isPending && isChallenged;
                      }).toList() ?? [];

                      if (pendentesRecebidos.isEmpty) return const SizedBox.shrink();

                      return AlertaDesafiosPendentesHome(
                        quantidade: pendentesRecebidos.length,
                      );
                    },
                  ),

                  // TÍTULO "PARTIDAS" E "Ver todas" (Com indicador de tempo real e última atualização)
                  Consumer<PartidasProvider>(
                    builder: (context, provider, _) {
                      return Appbardaspartidas(
                        ultimaAtualizacao: provider.ultimaAtualizacaoFormatada,
                        onVerTodasPressed: () {
                          setState(() {
                            _mostrarTodas = !_mostrarTodas;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // LISTA DINÂMICA DE PARTIDAS EM TEMPO REAL
                  Consumer<PartidasProvider>(
                    builder: (context, partidasProvider, child) {
                      return ListaPartidasHome(
                        partidas: partidasProvider.partidas,
                        isLoading: partidasProvider.isLoading,
                        errorMessage: partidasProvider.errorMessage,
                        hasRefreshError: partidasProvider.hasRefreshError,
                        refreshErrorMessage: partidasProvider.refreshErrorMessage,
                        mostrarTodas: _mostrarTodas,
                        onRecarregar: () => context
                            .read<PartidasProvider>()
                            .carregarPartidas(forcar: true),
                        onAlternarPartidas: () {
                          setState(() {
                            _mostrarTodas = !_mostrarTodas;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // SEÇÃO DESAFIOS ATIVOS
                  // SEÇÃO DESAFIOS RESUMO (D-003, Plano Mestre v3.2)
                  StreamBuilder<List<ChallengeModel>>(
                    stream: _desafios,
                    builder: (context, snapshot) {
                      final authProvider = context.watch<AuthProvider?>();
                      final currentUid = authProvider?.currentUser?.uid ??
                          widget.authService?.currentUser?.uid ??
                          context.read<AuthService?>()?.currentUser?.uid;

                      final service = widget.challengeService ?? context.read<ChallengeService?>();

                      return DesafiosAtivosWidget(
                        desafios: snapshot.hasError ? null : snapshot.data ?? const [],
                        carregando: _desafios != null &&
                            snapshot.connectionState == ConnectionState.waiting && !snapshot.hasError,
                        erro: snapshot.hasError,
                        onTentarNovamente: () => setState(() {
                          _desafios = _observarDesafios();
                        }),
                        currentUserId: currentUid,
                        challengeService: service,
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),

      // BARRA DE NAVEGAÇÃO INFERIOR
      bottomNavigationBar: BarraNavegacaoHome(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == 1) {
            final service = widget.challengeService ?? context.read<ChallengeService?>();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CriarDesafioScreen(
                  challengeService: service,
                ),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PerfilScreen()),
            );
          } else {
            setState(() {
              _currentNavIndex = index;
            });
          }
        },
      ),
    );
  }

  /// Pede confirmação e encerra a sessão. O retorno ao Login é feito pelo
  /// AuthGate; aqui só tratamos o cancelamento e a falha.
  Future<void> _confirmarLogout() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF151E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Sair da conta?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Você precisará entrar novamente para acessar o BetFriends.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Sair',
              style: TextStyle(
                color: Color(0xFFF87171),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    try {
      await context.read<AuthProvider>().signOut();
    } catch (e, s) {
      registrarErro('Sair da conta', e, s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível sair da conta. Tente novamente.',
          ),
        ),
      );
    }
  }

}
