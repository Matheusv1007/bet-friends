import 'package:flutter/material.dart';

import '../models/partida_model.dart';
import '../services/api/partidas_rest_service.dart';
import '../widgets_homePage/cardDePartidas.dart';

/// Tela para atender à Atividade Prática Acadêmica: "Consumo de API REST GET".
///
/// Demonstração de:
/// - Requisição HTTP GET ao endpoint REST do backend BetFriends;
/// - Tratamento de status HTTP e decodificação JSON para [PartidaModel];
/// - Exibição de dados em formato de lista (ListView);
/// - Tratamento resiliente de falhas de comunicação sem travar o aplicativo;
/// - Ausência de tokens externos no client Flutter.
class TelaPartidasRest extends StatefulWidget {
  final PartidasRestService? restService;

  const TelaPartidasRest({super.key, this.restService});

  @override
  State<TelaPartidasRest> createState() => _TelaPartidasRestState();
}

class _TelaPartidasRestState extends State<TelaPartidasRest> {
  late final PartidasRestService _service;
  bool _isLoading = false;
  String? _errorMessage;
  List<PartidaModel> _partidas = [];

  @override
  void initState() {
    super.initState();
    _service = widget.restService ?? PartidasRestService();
    _carregarPartidas();
  }

  Future<void> _carregarPartidas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resultado = await _service.getPartidasRest();
      if (!mounted) return;
      setState(() {
        _partidas = resultado;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = PartidasRestService.formatErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgScaffold = Color(0xFF0B111D);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Partidas via REST (GET)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Recarregar via GET',
            icon: const Icon(Icons.refresh, color: Color(0xFF00D084)),
            onPressed: _isLoading ? null : _carregarPartidas,
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.85, -0.9),
            radius: 1.2,
            colors: [Color(0xFF0F2624), Color(0xFF0B111D), Color(0xFF0B111D)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Banner explicativo acadêmico
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF151E2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00D084).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      color: Color(0xFF00D084),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Atividade Prática - Consumo REST GET',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Endpoint /getMatchesRest • JSON parse para PartidaModel',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Conteúdo: Loading, Erro, Vazio ou Lista
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF00D084),
                  backgroundColor: const Color(0xFF151E2E),
                  onRefresh: _carregarPartidas,
                  child: _buildConteudo(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('rest_loading_indicator'),
          color: Color(0xFF00D084),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            key: const Key('rest_error_container'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF151E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 40,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Falha na comunicação REST',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const Key('rest_retry_button'),
                  onPressed: _carregarPartidas,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('TENTAR NOVAMENTE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D084),
                    foregroundColor: const Color(0xFF062319),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_partidas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            key: const Key('rest_empty_container'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF151E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
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
                  'Nenhuma partida retornada pelo endpoint REST',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const Key('rest_empty_refresh_button'),
                  onPressed: _carregarPartidas,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('ATUALIZAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D084),
                    foregroundColor: const Color(0xFF062319),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('rest_matches_list'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _partidas.length,
      itemBuilder: (context, index) {
        final partida = _partidas[index];
        return Carddepartidas(partida: partida);
      },
    );
  }
}
