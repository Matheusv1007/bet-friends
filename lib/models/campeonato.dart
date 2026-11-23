/// Campeonatos sincronizados na coleção `matches` (campo `competitionCode`).
///
/// A ordem de declaração é a ordem de exibição do app. Um código fora desta
/// lista nunca quebra a interface: [nomeDoCodigo] devolve o próprio código.
enum Campeonato {
  brasileirao('BSA', 'Brasileirão Série A'),
  premierLeague('PL', 'Premier League'),
  serieA('SA', 'Serie A'),
  laLiga('PD', 'La Liga');

  final String codigo;
  final String nome;
  const Campeonato(this.codigo, this.nome);

  /// Campeonatos suportados, na ordem de exibição.
  static const List<Campeonato> suportados = values;

  /// Códigos dos campeonatos suportados, na ordem de exibição.
  static List<String> get codigosSuportados =>
      [for (final c in suportados) c.codigo];

  /// Campeonato do [codigo] (sem diferenciar caixa), ou `null` se for desconhecido.
  static Campeonato? deCodigo(String? codigo) {
    final normalizado = codigo?.trim().toUpperCase();
    for (final c in suportados) {
      if (c.codigo == normalizado) return c;
    }
    return null;
  }

  /// Nome legível do campeonato; para código desconhecido, devolve o próprio [codigo].
  static String nomeDoCodigo(String codigo) =>
      deCodigo(codigo)?.nome ?? codigo;
}
