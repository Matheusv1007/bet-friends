import 'package:flutter/widgets.dart';
import '../models/challenge_model.dart';
import '../models/partida_model.dart';

/// Dados públicos compartilhados pelos cards e pelo detalhe, sem expor IDs.
class ApresentacaoDesafios extends InheritedWidget {
  final String? currentUserId;
  final Map<String, String> nomes;
  final Map<String, PartidaModel> partidas;

  const ApresentacaoDesafios({
    super.key,
    required super.child,
    this.currentUserId,
    this.nomes = const {},
    this.partidas = const {},
  });

  static ApresentacaoDesafios? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ApresentacaoDesafios>();

  String nome(String uid) => uid == currentUserId ? 'Você' : nomes[uid] ?? 'Jogador';

  String partida(String id) {
    final p = partidas[id];
    if (p == null) return 'Partida indisponível';
    return '${p.timeMandante} x ${p.timeVisitante}, ${p.horario ?? 'horário a confirmar'}';
  }

  /// "Internacional x Vitória"; com placar ("Arsenal 2 x 1 Chelsea") quando [comPlacar] e houver gols.
  String confronto(String id, {bool comPlacar = false}) {
    final p = partidas[id];
    if (p == null) return 'Partida indisponível';
    final gm = p.golsMandante, gv = p.golsVisitante;
    if (comPlacar && gm != null && gv != null) {
      return '${p.timeMandante} $gm x $gv ${p.timeVisitante}';
    }
    return '${p.timeMandante} x ${p.timeVisitante}';
  }

  /// Liga e horário da partida ("Brasileirão · Hoje 22:39"), ou `null` se nada for conhecido.
  String? contextoDaPartida(String id, {bool comHorario = true}) {
    final p = partidas[id];
    if (p == null) return null;
    final partes = [
      if (p.campeonato != null && p.campeonato!.trim().isNotEmpty) p.campeonato!,
      if (comHorario) p.horario ?? 'horário a confirmar',
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  /// Palpite com o nome do time ("Internacional", "Empate"); sem a partida, o rótulo genérico.
  String palpite(Palpite palpite, String matchId) {
    final p = partidas[matchId];
    if (p == null) return palpite.label;
    return switch (palpite) {
      Palpite.homeWin => p.timeMandante,
      Palpite.draw => 'Empate',
      Palpite.awayWin => p.timeVisitante,
    };
  }

  @override
  bool updateShouldNotify(ApresentacaoDesafios oldWidget) => true;
}
