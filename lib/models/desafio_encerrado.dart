import 'package:cloud_firestore/cloud_firestore.dart';

/// Estados terminais de `challenges` (Plano §7), os únicos do histórico.
enum StatusEncerrado {
  finished('FINISHED'),
  rejected('REJECTED'),
  expired('EXPIRED'),
  cancelled('CANCELLED');

  final String valor;
  const StatusEncerrado(this.valor);

  static StatusEncerrado? deValor(Object? valor) {
    for (final s in values) {
      if (s.valor == valor) return s;
    }
    return null;
  }
}

/// Desafio encerrado, como persistido em `challenges/{id}` (KAN-89;
/// docs/firestore-schema.md §3.5).
///
/// Só lê o que o backend gravou. O vencedor e o resultado nunca são calculados
/// aqui: `winnerId` nulo em `FINISHED` significa empate estrutural.
class DesafioEncerrado {
  static const _palpites = {'HOME_WIN', 'DRAW', 'AWAY_WIN'};
  static const _motivos = {'CREATOR', 'FRIENDSHIP_REMOVED', 'MATCH_CANCELLED', 'MATCH_POSTPONED'};

  final String id;
  final String challengerId;
  final String challengedId;
  final String matchId;
  final String challengerPrediction;
  final String? challengedPrediction;
  final int amount;
  final StatusEncerrado status;
  final String? winnerId;
  final String? settledResult;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime finishedAt;

  const DesafioEncerrado({
    required this.id,
    required this.challengerId,
    required this.challengedId,
    required this.matchId,
    required this.challengerPrediction,
    required this.challengedPrediction,
    required this.amount,
    required this.status,
    required this.winnerId,
    required this.settledResult,
    required this.cancelReason,
    required this.createdAt,
    required this.acceptedAt,
    required this.startedAt,
    required this.finishedAt,
  });

  bool temParticipante(String uid) => uid == challengerId || uid == challengedId;

  /// Converte o documento. Lança [FormatException] se ele estiver fora do
  /// contrato, inclusive em estado não terminal, sem corrigir nem completar dados.
  factory DesafioEncerrado.fromMap(String id, Map<String, dynamic> dados) {
    final status = StatusEncerrado.deValor(dados['status']);
    if (status == null) _invalido('status');

    final challengerId = _texto(dados, 'challengerId');
    final challengedId = _texto(dados, 'challengedId');
    final participants = dados['participants'];
    if (challengerId == challengedId ||
        participants is! List ||
        participants.length != 2 ||
        participants[0] != challengerId ||
        participants[1] != challengedId) {
      _invalido('participants');
    }

    final amount = dados['amount'];
    if (amount is! int || amount < 10 || amount > 500) _invalido('amount');

    final challengerPrediction = dados['challengerPrediction'];
    if (!_palpites.contains(challengerPrediction)) _invalido('challengerPrediction');

    final challengedPrediction = _opcional(dados, 'challengedPrediction');
    if (challengedPrediction != null && !_palpites.contains(challengedPrediction)) {
      _invalido('challengedPrediction');
    }

    final finalizado = status == StatusEncerrado.finished;
    if (finalizado && challengedPrediction == null) _invalido('challengedPrediction');

    final settledResult = _opcional(dados, 'settledResult');
    if (finalizado ? !_palpites.contains(settledResult) : settledResult != null) {
      _invalido('settledResult');
    }

    final winnerId = _opcional(dados, 'winnerId');
    final vencedorValido = winnerId == null ||
        (finalizado && (winnerId == challengerId || winnerId == challengedId));
    if (!vencedorValido) _invalido('winnerId');

    final cancelReason = _opcional(dados, 'cancelReason');
    if (status == StatusEncerrado.cancelled
        ? !_motivos.contains(cancelReason)
        : cancelReason != null) {
      _invalido('cancelReason');
    }

    return DesafioEncerrado(
      id: id,
      challengerId: challengerId,
      challengedId: challengedId,
      matchId: _texto(dados, 'matchId'),
      challengerPrediction: challengerPrediction as String,
      challengedPrediction: challengedPrediction,
      amount: amount,
      status: status,
      winnerId: winnerId,
      settledResult: settledResult,
      cancelReason: cancelReason,
      createdAt: _data(dados, 'createdAt'),
      acceptedAt: _dataOpcional(dados, 'acceptedAt'),
      startedAt: _dataOpcional(dados, 'startedAt'),
      finishedAt: _data(dados, 'finishedAt'),
    );
  }

  static Never _invalido(String campo) =>
      throw FormatException('Campo "$campo" inválido no desafio.');

  static String _texto(Map<String, dynamic> dados, String campo) {
    final valor = dados[campo];
    if (valor is! String || valor.isEmpty) _invalido(campo);
    return valor;
  }

  static String? _opcional(Map<String, dynamic> dados, String campo) {
    final valor = dados[campo];
    if (valor == null) return null;
    if (valor is! String || valor.isEmpty) _invalido(campo);
    return valor;
  }

  static DateTime _data(Map<String, dynamic> dados, String campo) {
    final valor = dados[campo];
    if (valor is! Timestamp) _invalido(campo);
    return valor.toDate();
  }

  static DateTime? _dataOpcional(Map<String, dynamic> dados, String campo) =>
      dados[campo] == null ? null : _data(dados, campo);
}
