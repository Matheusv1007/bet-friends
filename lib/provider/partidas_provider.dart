import 'package:flutter/material.dart';
import '../models/partida_model.dart';
import '../services/api/partidas_service.dart';

class PartidasProvider extends ChangeNotifier {
  final PartidasService _partidasService;

  List<PartidaModel> _partidas = [];
  bool _isLoading = false;
  bool _isAutoRefreshing = false;
  String? _errorMessage;
  String? _refreshErrorMessage;
  DateTime? _ultimaAtualizacao;

  PartidasProvider({PartidasService? partidasService})
      : _partidasService = partidasService ?? PartidasService();

  List<PartidaModel> get partidas => _partidas;
  bool get isLoading => _isLoading;
  bool get isAutoRefreshing => _isAutoRefreshing;
  String? get errorMessage => _errorMessage;
  String? get refreshErrorMessage => _refreshErrorMessage;
  bool get hasRefreshError => _refreshErrorMessage != null;
  DateTime? get ultimaAtualizacao => _ultimaAtualizacao;

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

  /// Busca as partidas através do repositório/Firestore.
  /// Se [silencioso] for true, atualiza em segundo plano sem disparar loading em tela cheia.
  Future<void> carregarPartidas({int limit = 15, bool silencioso = false}) async {
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
      _errorMessage = null;
      _refreshErrorMessage = null;
    } catch (e) {
      final formattedMsg = PartidasService.formatErrorMessage(e);
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
