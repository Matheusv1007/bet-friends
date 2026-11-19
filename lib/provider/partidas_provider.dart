import 'package:flutter/material.dart';
import '../models/partida_model.dart';
import '../services/api/partidas_service.dart';

/// Provider para gerenciamento do estado das partidas na Home e telas de criação de desafio.
///
/// Implementa as diretrizes de KAN-105 para evitar consultas redundantes ao Firestore:
/// - Cache com TTL na navegação Home → Criar Desafio → Home.
/// - Tratamento amigável de limites de requisições do Firestore.
/// - Cooldown para impedir consultas automáticas repetidas após atingir esse limite.
/// - Suporte a [forcar: true] para que o pull-to-refresh e o botão "Tentar novamente" continuem funcionando.
class PartidasProvider extends ChangeNotifier {
  final PartidasService _partidasService;

  List<PartidaModel> _partidas = [];
  Future<void>? _carregamento;
  bool _isLoading = false;
  bool _isAutoRefreshing = false;
  String? _errorMessage;
  String? _refreshErrorMessage;
  DateTime? _ultimaAtualizacao;

  // Controle de cache e rate limit (KAN-105)
  DateTime? _ultimoFetchSucesso;
  DateTime? _rateLimitCooldownAte;
  bool _isRateLimited = false;

  /// Janela de frescor dos dados em memória (5 minutos). Evita re-fetch redundante em transição de telas.
  static const Duration cacheTtl = Duration(minutes: 5);

  /// Cooldown após limite de requisições (60 segundos), pausando o polling automático.
  static const Duration rateLimitCooldown = Duration(seconds: 60);

  PartidasProvider({PartidasService? partidasService})
      : _partidasService = partidasService ?? PartidasService();

  List<PartidaModel> get partidas => _partidas;
  bool get isLoading => _isLoading;
  bool get isAutoRefreshing => _isAutoRefreshing;
  String? get errorMessage => _errorMessage;
  String? get refreshErrorMessage => _refreshErrorMessage;
  bool get hasRefreshError => _refreshErrorMessage != null;
  DateTime? get ultimaAtualizacao => _ultimaAtualizacao;
  bool get isRateLimited => _isRateLimited;

  /// Indica se os dados em memória precisam ser atualizados (vazios ou cache expirado).
  bool get deveAtualizar {
    if (_ultimoFetchSucesso == null) return true;
    return DateTime.now().difference(_ultimoFetchSucesso!) >= cacheTtl;
  }

  /// Exibe a data/hora da última atualização das partidas (RN-CACHE-002)
  String? get ultimaAtualizacaoFormatada {
    if (_ultimaAtualizacao == null) return null;
    final dt = _ultimaAtualizacao!.toLocal();
    final hora = dt.hour.toString().padLeft(2, '0');
    final minuto = dt.minute.toString().padLeft(2, '0');
    return 'Atualizado às $hora:$minuto';
  }

  /// Limpa a mensagem de erro de atualização em segundo plano / refresh
  void limparErroRefresh() {
    if (_refreshErrorMessage != null) {
      _refreshErrorMessage = null;
      notifyListeners();
    }
  }

  /// Busca as partidas através do repositório/Firestore ou serviço.
  /// - [silencioso]: se true, atualiza em segundo plano sem disparar loading em tela cheia.
  /// - [forcar]: se true, ignora o cacheTtl e o cooldown de rate limit (ex: pull-to-refresh ou retry).
  Future<void> carregarPartidas({
    int limit = 15,
    bool silencioso = false,
    bool forcar = false,
  }) {
    return _carregamento ??= _carregarPartidas(
      limit: limit, silencioso: silencioso, forcar: forcar,
    ).whenComplete(() => _carregamento = null);
  }

  Future<void> _carregarPartidas({
    required int limit,
    required bool silencioso,
    required bool forcar,
  }) async {
    // O TTL também vale para polling e resultados vazios.
    if (!forcar && !deveAtualizar) {
      return;
    }

    // 2. Proteção contra polling em rate-limit (KAN-105):
    // Se estiver em cooldown por limite de requisições, rejeita chamadas automáticas
    if (!forcar && _isRateLimited) {
      if (_rateLimitCooldownAte != null &&
          DateTime.now().isBefore(_rateLimitCooldownAte!)) {
        return;
      }
    }

    if (silencioso) {
      _isAutoRefreshing = true;
      notifyListeners();
    } else {
      _isLoading = true;
      if (_partidas.isEmpty) {
        _errorMessage = null;
      }
      _refreshErrorMessage = null;
      notifyListeners();
    }

    try {
      final novasPartidas = await _partidasService.getPartidas(limit: limit);
      _partidas = novasPartidas;

      // Recupera o timestamp de sincronização mais recente ou o instante da consulta
      DateTime? latestSynced;
      for (final p in novasPartidas) {
        if (p.syncedAt != null) {
          if (latestSynced == null || p.syncedAt!.isAfter(latestSynced)) {
            latestSynced = p.syncedAt;
          }
        }
      }
      _ultimaAtualizacao = latestSynced ?? DateTime.now();
      _ultimoFetchSucesso = DateTime.now();
      _isRateLimited = false;
      _rateLimitCooldownAte = null;
      _errorMessage = null;
      _refreshErrorMessage = null;
    } catch (e) {
      final formattedMsg = PartidasService.formatErrorMessage(e);
      final isRateLimitError = formattedMsg.contains('Limite de requisições');

      if (isRateLimitError) {
        _isRateLimited = true;
        _rateLimitCooldownAte = DateTime.now().add(rateLimitCooldown);
      }

      if (_partidas.isEmpty) {
        // Sem dados em cache: define o erro principal da tela
        _errorMessage = formattedMsg;
      } else {
        // Com dados em cache: preserva os dados existentes e sinaliza a falha no refresh (RN-CACHE-003)
        _refreshErrorMessage = 'Não foi possível atualizar os dados mais recentes. Exibindo dados anteriores.';
      }
    } finally {
      _isLoading = false;
      _isAutoRefreshing = false;
      notifyListeners();
    }
  }
}
