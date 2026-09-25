import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/partida_model.dart';
import '../provider/partidas_provider.dart';
import '../telas_principais/homePage.dart';

class CriarDesafioScreen extends StatefulWidget {
  const CriarDesafioScreen({super.key});

  @override
  State<CriarDesafioScreen> createState() => _CriarDesafioScreenState();
}

class _CriarDesafioScreenState extends State<CriarDesafioScreen> {
  int valor = 50;
  String? partidaId;
  final amigos = <int>{0};

  @override
  void initState() {
    super.initState();
    // Garante o carregamento das partidas reais da API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PartidasProvider>();
      if (provider.partidas.isEmpty) {
        provider.carregarPartidas();
      }
    });
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
                      children: const [
                        Text(
                          'SALDO DISPONÍVEL',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '1.500 fichas',
                          style: TextStyle(
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

              // Lista dinâmica com partidas reais da API
              Consumer<PartidasProvider>(
                builder: (context, partidasProvider, child) {
                  if (partidasProvider.isLoading &&
                      partidasProvider.partidas.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(color: primaryGreen),
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
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.sports_soccer,
                            color: Color(0xFF64748B),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nenhuma partida encontrada no momento',
                            style: TextStyle(color: textMuted, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () =>
                                partidasProvider.carregarPartidas(),
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

                  // Seleciona a primeira partida se nenhuma estiver selecionada
                  if (partidaId == null && partidas.isNotEmpty) {
                    partidaId = partidas.first.id;
                  }

                  return Column(
                    children: partidas.map((PartidaModel p) {
                      final sel = partidaId == p.id;
                      final horarioOuStatus = p.horario ?? p.status;

                      return GestureDetector(
                        onTap: () => setState(() => partidaId = p.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF0E2924) : cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel
                                  ? primaryGreen
                                  : Colors.white.withValues(alpha: 0.05),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sports_soccer,
                                size: 20,
                                color: sel
                                    ? primaryGreen
                                    : const Color(0xFF64748B),
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
                                color: sel
                                    ? primaryGreen
                                    : const Color(0xFF64748B),
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

              // Seção Valor do Desafio
              const Text(
                'VALOR DO DESAFIO',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                      'Fichas apostadas',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$valor fichas',
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
                      onTap: () => setState(() => valor = v),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? primaryGreen : cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? primaryGreen
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$v',
                          style: TextStyle(
                            color:
                                sel ? const Color(0xFF062319) : Colors.white,
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
                'CONVIDAR AMIGO',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar amigo...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                  filled: true,
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: primaryGreen),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...['Lucas Silva', 'Guilherme Santos'].asMap().entries.map((e) {
                final sel = amigos.contains(e.key);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 15,
                        backgroundColor: Color(0xFF334155),
                        child: Icon(
                          Icons.person_outline,
                          size: 17,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(
                          () => sel
                              ? amigos.remove(e.key)
                              : amigos.add(e.key),
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: sel ? 10 : 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                sel ? primaryGreen : const Color(0xFF0F2624),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: primaryGreen
                                  .withValues(alpha: sel ? 1.0 : 0.3),
                            ),
                          ),
                          child: sel
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Color(0xFF062319),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Adicionado',
                                      style: TextStyle(
                                        color: Color(0xFF062319),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Convidar',
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: const Color(0xFF062319),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
            child: const Text(
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
}
