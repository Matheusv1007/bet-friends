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
  List<PartidaModel> _partidasDaHome = [];
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

  /// Número máximo de partidas na Home, somando todos os campeonatos.
  static const int limiteDaHome = 15;

  /// Todas as partidas carregadas, de todos os campeonatos, ordenadas por
  /// horário. É o conjunto usado pela escolha de partida do Criar Desafio.
  List<PartidaModel> get partidas => _partidas;

  /// Seleção da Home: até [limiteDaHome] partidas, na ordem ao vivo, agendadas
  /// e finalizadas recentes, com os campeonatos intercalados (nenhum ocupa a
  /// lista sozinho quando há partidas de outros).
  List<PartidaModel> get partidasDaHome => _partidasDaHome;
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

  /// Busca as partidas de todos os campeonatos através do repositório/Firestore ou serviço.
  /// - [silencioso]: se true, atualiza em segundo plano sem disparar loading em tela cheia.
  /// - [forcar]: se true, ignora o cacheTtl e o cooldown de rate limit (ex: pull-to-refresh ou retry).
  Future<void> carregarPartidas({
    bool silencioso = false,
    bool forcar = false,
  }) {
    return _carregamento ??= _carregarPartidas(
      silencioso: silencioso, forcar: forcar,
    ).whenComplete(() => _carregamento = null);
  }

  Future<void> _carregarPartidas({
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
      final novasPartidas = await _partidasService.getPartidas();
      _partidas = novasPartidas;
      _partidasDaHome = selecionarParaHome(novasPartidas);

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

  /// Escolhe até [limite] partidas para a Home sem deixar um campeonato ocupar tudo.
  ///
  /// A cota é repartida em rodadas: cada campeonato cede sua melhor partida
  /// restante (ao vivo, depois agendadas, depois finalizadas recentes) até
  /// completar o [limite]. A lista final segue a ordem de prioridade: ao vivo,
  /// agendadas (mais próximas primeiro), finalizadas (mais recentes primeiro)
  /// e demais, intercalando os campeonatos por horário.
  @visibleForTesting
  static List<PartidaModel> selecionarParaHome(
    List<PartidaModel> partidas, {
    int limite = limiteDaHome,
  }) {
    final prioridade = <PartidaModel, int>{};
    for (var i = 0; i < partidas.length; i++) {
      prioridade[partidas[i]] = i;
    }
    int comparar(PartidaModel a, PartidaModel b) {
      final porGrupo = _grupoDaHome(a).compareTo(_grupoDaHome(b));
      if (porGrupo != 0) return porGrupo;
      final tempo = _instante(a).compareTo(_instante(b));
      // Finalizadas: a mais recente primeiro.
      final ordenado = _grupoDaHome(a) == 2 ? -tempo : tempo;
      return ordenado != 0 ? ordenado : prioridade[a]!.compareTo(prioridade[b]!);
    }

    final filas = <String, List<PartidaModel>>{};
    for (final p in partidas) {
      (filas[p.competitionCode ?? 'BSA'] ??= []).add(p);
    }
    for (final fila in filas.values) {
      fila.sort(comparar);
    }

    final escolhidas = <PartidaModel>[];
    for (var rodada = 0; escolhidas.length < limite; rodada++) {
      final cabecas = [
        for (final fila in filas.values)
          if (rodada < fila.length) fila[rodada],
      ];
      if (cabecas.isEmpty) break;
      cabecas.sort(comparar);
      escolhidas.addAll(cabecas.take(limite - escolhidas.length));
    }
    return escolhidas..sort(comparar);
  }

  /// 0 = ao vivo, 1 = agendada, 2 = finalizada, 3 = demais (mesma ordem de prioridade da Home).
  static int _grupoDaHome(PartidaModel p) {
    if (p.isAoVivo) return 0;
    if (p.isAgendado) return 1;
    if (p.isFinalizado) return 2;
    return 3;
  }

  static DateTime _instante(PartidaModel p) =>
      p.startsAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
