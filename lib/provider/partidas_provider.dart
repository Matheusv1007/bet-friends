import 'package:flutter/material.dart';
import '../models/partida_model.dart';
import '../services/api/partidas_service.dart';

class PartidasProvider extends ChangeNotifier {
  final PartidasService _partidasService = PartidasService();

  List<PartidaModel> _partidas = [];
  bool _isLoading = false;
  bool _isAutoRefreshing = false;
  String? _errorMessage;
  DateTime? _ultimaAtualizacao;

  List<PartidaModel> get partidas => _partidas;
  bool get isLoading => _isLoading;
  bool get isAutoRefreshing => _isAutoRefreshing;
  String? get errorMessage => _errorMessage;
  DateTime? get ultimaAtualizacao => _ultimaAtualizacao;

  /// Busca as partidas através do serviço da API.
  /// Se [silencioso] for true, atualiza em segundo plano sem piscar a tela com loading.
  Future<void> carregarPartidas({int limit = 10, bool silencioso = false}) async {
    if (silencioso) {
      _isAutoRefreshing = true;
      notifyListeners();
    } else {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final novasPartidas = await _partidasService.getPartidas(limit: limit);
      if (novasPartidas.isNotEmpty) {
        _partidas = novasPartidas;
      }
      _ultimaAtualizacao = DateTime.now();
      _errorMessage = null;
    } catch (e) {
      if (!silencioso) {
        _errorMessage = e.toString();
      }
    } finally {
      _isLoading = false;
      _isAutoRefreshing = false;
      notifyListeners();
    }
  }
}
