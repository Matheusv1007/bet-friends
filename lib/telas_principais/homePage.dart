import 'dart:async';

import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/tela_criar_desafio/tela_criar_desafio.dart';
import 'package:betfriends/widgets_homePage/appbarDasPartidas.dart';
import 'package:betfriends/widgets_homePage/cardDeDesafio.dart';
import 'package:betfriends/widgets_homePage/cardDeDesafiosAtivos.dart';
import 'package:betfriends/widgets_homePage/cardDePartidas.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _currentNavIndex = 0;
  Timer? _realTimeTimer;
  bool _mostrarTodas = false;

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
      minuto: '65:12',
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

    // 1. Dispara a primeira busca na API logo que a tela é montada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartidasProvider>().carregarPartidas();
    });

    // 2. POLLING EM TEMPO REAL: Atualiza os dados a cada 30 segundos silenciosamente
    _realTimeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<PartidasProvider>().carregarPartidas(silencioso: true);
      }
    });
  }

  @override
  void dispose() {
    // Cancela o timer quando a tela for fechada para economizar bateria e rede
    _realTimeTimer?.cancel();
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
                context.read<PartidasProvider>().carregarPartidas(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABEÇALHO PERSONALIZADO (Avatar, Saudação, Fichas e Logo)
                  _buildHeader(),

                  const SizedBox(height: 20),

                  // CARD DESAFIO RÁPIDO 1V1
                  const Carddedesafio(),

                  const SizedBox(height: 22),

                  // TÍTULO "PARTIDAS" E "Ver todas" (Com indicador de tempo real)
                  Appbardaspartidas(
                    onVerTodasPressed: () {
                      setState(() {
                        _mostrarTodas = !_mostrarTodas;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  // LISTA DINÂMICA DE PARTIDAS EM TEMPO REAL
                  Consumer<PartidasProvider>(
                    builder: (context, partidasProvider, child) {
                      // 1. Estado de carregando
                      if (partidasProvider.isLoading &&
                          partidasProvider.partidas.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(
                              color: Color(0xFF00D084),
                            ),
                          ),
                        );
                      }

                      // 2. Estado de erro
                      if (partidasProvider.errorMessage != null &&
                          partidasProvider.partidas.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
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
                                Icons.error_outline,
                                color: Color(0xFFEF4444),
                                size: 36,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Erro ao carregar partidas",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                partidasProvider.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF8E9CAB),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => context
                                    .read<PartidasProvider>()
                                    .carregarPartidas(),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text(
                                  "TENTAR NOVAMENTE",
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
                        );
                      }

                      // 3. Estado vazio (nenhuma partida encontrada)
                      if (partidasProvider.partidas.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
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
                                Icons.sports_soccer,
                                color: Color(0xFF64748B),
                                size: 36,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Nenhuma partida disponível",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Não encontramos partidas disponíveis no momento.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF8E9CAB),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => context
                                    .read<PartidasProvider>()
                                    .carregarPartidas(),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text(
                                  "ATUALIZAR",
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
                        );
                      }

                      // 4. Partidas carregadas com sucesso
                      final baseList = partidasProvider.partidas;
                      final listaParaExibir = _mostrarTodas
                          ? baseList
                          : baseList.take(3).toList();

                      return Column(
                        children: [
                          ...listaParaExibir.map((partida) {
                            return Carddepartidas(partida: partida);
                          }),
                          if (baseList.length > 3) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _mostrarTodas = !_mostrarTodas;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00D084),
                                  foregroundColor: const Color(0xFF062319),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  _mostrarTodas
                                      ? "MOSTRAR MENOS"
                                      : "MAIS PARTIDAS",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // SEÇÃO DESAFIOS ATIVOS
                  const DesafiosAtivosWidget(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),

      // BARRA DE NAVEGAÇÃO INFERIOR
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E1420),
          border: Border(top: BorderSide(color: Color(0xFF1B2536), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CriarDesafioScreen(),
                ),
              );
            } else {
              setState(() {
                _currentNavIndex = index;
              });
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF00D084),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_kabaddi_outlined),
              activeIcon: Icon(Icons.sports_kabaddi),
              label: "Desafios",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.military_tech_outlined),
              activeIcon: Icon(Icons.military_tech),
              label: "Ranking",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Perfil",
            ),
          ],
        ),
      ),
    );
  }

  /// Cabeçalho com o Avatar do Pedro, saldo de fichas e logo do BetFriends
  Widget _buildHeader() {
    return Row(
      children: [
        // Avatar circular do Pedro com anel sutil
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: const CircleAvatar(
            radius: 19,
            backgroundColor: Color(0xFF334155),
            child: Icon(Icons.person, color: Colors.white70, size: 24),
          ),
        ),
        const SizedBox(width: 12),

        // Textos "Olá, Pedro" e "1.500 fichas"
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Olá, Pedro",
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "1.500 fichas",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Logo BetFriends com escudo estilizado verde
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF0B2421),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00D084), width: 1.5),
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: Color(0xFF00D084),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "BetFriends",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
