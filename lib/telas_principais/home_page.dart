import 'dart:async';

import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/provider/auth_provider.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/services/extrato_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/services/registro_de_erros.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/tela_extrato/tela_extrato.dart';
import 'package:betfriends/tela_perfil/tela_perfil.dart';
import 'package:betfriends/tema/tema.dart';
import 'package:betfriends/widgets/componentes.dart';
import 'package:betfriends/widgets_home_page/appbar_das_partidas.dart';
import 'package:betfriends/widgets_home_page/bloco_de_saldo.dart';
import 'package:betfriends/widgets_home_page/card_de_desafios_ativos.dart';
import 'package:betfriends/widgets_home_page/bonus_recuperacao.dart';
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

  /// Seção "Recebidos", alvo do "Responder" do aviso de pendência.
  final _chaveRecebidos = GlobalKey();

  /// Perfil do usuário logado (saudação e carteira); `null` se indisponível.
  Stream<PerfilObservado>? _perfil;
  Stream<List<ChallengeModel>>? _desafios;

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
      return Stream<List<ChallengeModel>>.error(e, s).asBroadcastStream();
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

  String? _uidAtual(BuildContext context) =>
      context.watch<AuthProvider?>()?.currentUser?.uid ??
      widget.authService?.currentUser?.uid ??
      context.read<AuthService?>()?.currentUser?.uid;

  ChallengeService? get _challengeService =>
      widget.challengeService ?? context.read<ChallengeService?>();

  void _abrirCriarDesafio() {
    final service = _challengeService;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CriarDesafioScreen(challengeService: service),
      ),
    );
  }

  void _abrirExtrato() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaExtrato(extratoService: context.read<ExtratoService?>()),
      ),
    );
  }

  void _rolarParaRecebidos() {
    final alvo = _chaveRecebidos.currentContext;
    if (alvo == null) return;
    Scrollable.ensureVisible(
      alvo,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: CoresApp.primario,
          backgroundColor: CoresApp.superficie1,
          onRefresh: () =>
              context.read<PartidasProvider>().carregarPartidas(forcar: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              EspacosApp.margemDaTela, EspacosApp.e8, EspacosApp.margemDaTela, EspacosApp.e24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CABEÇALHO: logo, avatar da conta, saudação e data
                CabecalhoHome(
                  perfil: _perfil,
                  // Leitura opcional: a Home também é montada isoladamente em widget tests.
                  saindo: context.watch<AuthProvider?>()?.isSigningOut ?? false,
                  onLogout: _confirmarLogout,
                ),

                const SizedBox(height: EspacosApp.e16),

                // SALDO E BÔNUS DE RECUPERAÇÃO (KAN-69; RF-003, RN-BET-004)
                StreamBuilder<PerfilObservado>(
                  stream: _perfil,
                  builder: (context, snapshot) {
                    final carteira = snapshot.hasError ? null : snapshot.data?.carteira;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BlocoDeSaldo(
                          carteira: carteira,
                          semConexao: !snapshot.hasError && (snapshot.data?.doCache ?? false),
                          onExtrato: _abrirExtrato,
                          onNovoDesafio: _abrirCriarDesafio,
                        ),
                        if (carteira != null) BonusRecuperacaoCard(carteira: carteira),
                      ],
                    );
                  },
                ),

                // AVISO ÚNICO: DESAFIOS RECEBIDOS AGUARDANDO RESPOSTA (D-003, Plano Mestre v3.2)
                StreamBuilder<List<ChallengeModel>>(
                  stream: _desafios,
                  builder: (context, snapshot) {
                    final desafios = snapshot.hasError ? null : snapshot.data;
                    final currentUid = _uidAtual(context);

                    final pendentesRecebidos = desafios?.where((c) {
                      final isPending = c.status == StatusDesafio.pending;
                      final isChallenged = currentUid == null || c.challengedId == currentUid;
                      return isPending && isChallenged;
                    }).length ?? 0;

                    if (pendentesRecebidos == 0) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(top: EspacosApp.e12),
                      child: AlertaDesafiosPendentesHome(
                        quantidade: pendentesRecebidos,
                        onResponder: _rolarParaRecebidos,
                      ),
                    );
                  },
                ),

                const SizedBox(height: EspacosApp.e16),

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

                const SizedBox(height: EspacosApp.e8),

                // LISTA DINÂMICA DE PARTIDAS EM TEMPO REAL
                Consumer<PartidasProvider>(
                  builder: (context, partidasProvider, child) {
                    return ListaPartidasHome(
                      partidas: partidasProvider.partidasDaHome,
                      isLoading: partidasProvider.isLoading,
                      errorMessage: partidasProvider.errorMessage,
                      hasRefreshError: partidasProvider.hasRefreshError,
                      refreshErrorMessage: partidasProvider.refreshErrorMessage,
                      mostrarTodas: _mostrarTodas,
                      onRecarregar: () => context
                          .read<PartidasProvider>()
                          .carregarPartidas(forcar: true),
                    );
                  },
                ),

                const SizedBox(height: EspacosApp.e24),

                // DESAFIOS: RECEBIDOS, ENVIADOS, EM ABERTO E FINALIZADOS (D-003, Plano Mestre v3.2)
                StreamBuilder<List<ChallengeModel>>(
                  stream: _desafios,
                  builder: (context, snapshot) {
                    return DesafiosAtivosWidget(
                      desafios: snapshot.hasError ? null : snapshot.data ?? const [],
                      carregando: _desafios != null &&
                          snapshot.connectionState == ConnectionState.waiting && !snapshot.hasError,
                      erro: snapshot.hasError,
                      onTentarNovamente: () => setState(() {
                        _desafios = _observarDesafios();
                      }),
                      currentUserId: _uidAtual(context),
                      challengeService: _challengeService,
                      chaveRecebidos: _chaveRecebidos,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      // BARRA DE NAVEGAÇÃO INFERIOR
      bottomNavigationBar: BarraNavegacaoHome(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == 1) {
            _abrirCriarDesafio();
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
        title: const Text('Sair da conta?'),
        content: Text(
          'Você precisará entrar novamente para acessar o BetFriends.',
          style: TextoApp.corpo.copyWith(color: CoresApp.textoSuave),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: CoresApp.destrutivo),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
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
      mostrarAviso(
        context,
        'Não foi possível sair da conta. Tente novamente.',
        tom: Tom.destrutivo,
      );
    }
  }
}
