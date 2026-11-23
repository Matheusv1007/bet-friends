import 'package:flutter/widgets.dart';
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

  @override
  bool updateShouldNotify(ApresentacaoDesafios oldWidget) => true;
}
