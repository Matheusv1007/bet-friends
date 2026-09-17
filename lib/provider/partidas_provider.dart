import 'package:flutter/material.dart';
import '../models/partida_model.dart';
import '../services/api/partidas_service.dart';

class PartidasProvider extends ChangeNotifier {
  final PartidasService _partidasService = PartidasService();

  List<PartidaModel> _partidas = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PartidaModel> get partidas => _partidas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Busca as partidas através do serviço da API e notifica a interface
  Future<void> carregarPartidas({int limit = 5}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _partidas = await _partidasService.getPartidas(limit: limit);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
