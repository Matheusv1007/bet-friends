import 'package:cloud_firestore/cloud_firestore.dart';

/// Item de amigo para listagem e seleção de desafios.
class AmigoItem {
  final String uid;
  final String displayName;
  final String username;

  const AmigoItem({
    required this.uid,
    required this.displayName,
    required this.username,
  });
}

/// Palpite de aposta no desfecho da partida (RN-PRD-001).
enum Palpite {
  homeWin('HOME_WIN', 'Vitória Mandante'),
  draw('DRAW', 'Empate'),
  awayWin('AWAY_WIN', 'Vitória Visitante');

  final String valor;
  final String label;
  const Palpite(this.valor, this.label);

  static Palpite? deValor(Object? v) {
    if (v is! String) return null;
    for (final p in values) {
      if (p.valor == v) return p;
    }
    return null;
  }
}

/// Estados oficiais do ciclo de vida de um desafio (Plano §7, docs/firestore-schema.md §3.5).
enum StatusDesafio {
  pending('PENDING', 'Pendente'),
  accepted('ACCEPTED', 'Aceito'),
  inProgress('IN_PROGRESS', 'Em Andamento'),
  waitingResult('WAITING_RESULT', 'Aguardando Resultado'),
  finished('FINISHED', 'Finalizado'),
  rejected('REJECTED', 'Recusado'),
  expired('EXPIRED', 'Expirado'),
  cancelled('CANCELLED', 'Cancelado');

  final String valor;
  final String label;
  const StatusDesafio(this.valor, this.label);

  static StatusDesafio? deValor(Object? v) {
    if (v is! String) return null;
    for (final s in values) {
      if (s.valor == v) return s;
    }
    return null;
  }

  bool get isTerminal =>
      this == finished || this == rejected || this == expired || this == cancelled;
}

/// Modelo de Desafio no aplicativo (KAN-62; RN-CHL-001 a 024).
class ChallengeModel {
  final String id;
  final String challengerId;
  final String challengedId;
  final List<String> participants;
  final String matchId;
  final Palpite challengerPrediction;
  final Palpite? challengedPrediction;
  final int amount;
  final StatusDesafio status;
  final String? winnerId;
  final Palpite? settledResult;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime updatedAt;

  const ChallengeModel({
    required this.id,
    required this.challengerId,
    required this.challengedId,
    required this.participants,
    required this.matchId,
    required this.challengerPrediction,
    this.challengedPrediction,
    required this.amount,
    required this.status,
    this.winnerId,
    this.settledResult,
    this.cancelReason,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.finishedAt,
    required this.updatedAt,
  });

  bool get isPending => status == StatusDesafio.pending;
  bool get isAccepted => status == StatusDesafio.accepted;
  bool get isTerminal => status.isTerminal;

  bool temParticipante(String uid) => uid == challengerId || uid == challengedId;

  factory ChallengeModel.fromMap(String id, Map<String, dynamic> map) {
    final status = StatusDesafio.deValor(map['status']) ?? StatusDesafio.pending;
    final challengerPrediction =
        Palpite.deValor(map['challengerPrediction']) ?? Palpite.homeWin;
    final challengedPrediction = Palpite.deValor(map['challengedPrediction']);
    final settledResult = Palpite.deValor(map['settledResult']);

    DateTime parseDate(dynamic value, [DateTime? fallback]) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? (fallback ?? DateTime.now());
      if (value is DateTime) return value;
      return fallback ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is DateTime) return value;
      return null;
    }

    final rawParticipants = map['participants'];
    final participants = rawParticipants is List
        ? rawParticipants.map((e) => e.toString()).toList()
        : <String>[map['challengerId']?.toString() ?? '', map['challengedId']?.toString() ?? ''];

    return ChallengeModel(
      id: id,
      challengerId: map['challengerId']?.toString() ?? '',
      challengedId: map['challengedId']?.toString() ?? '',
      participants: participants,
      matchId: map['matchId']?.toString() ?? '',
      challengerPrediction: challengerPrediction,
      challengedPrediction: challengedPrediction,
      amount: (map['amount'] as num?)?.toInt() ?? 10,
      status: status,
      winnerId: map['winnerId']?.toString(),
      settledResult: settledResult,
      cancelReason: map['cancelReason']?.toString(),
      createdAt: parseDate(map['createdAt']),
      acceptedAt: parseNullableDate(map['acceptedAt']),
      startedAt: parseNullableDate(map['startedAt']),
      finishedAt: parseNullableDate(map['finishedAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'challengerId': challengerId,
      'challengedId': challengedId,
      'participants': participants,
      'matchId': matchId,
      'challengerPrediction': challengerPrediction.valor,
      'challengedPrediction': challengedPrediction?.valor,
      'amount': amount,
      'status': status.valor,
      'winnerId': winnerId,
      'settledResult': settledResult?.valor,
      'cancelReason': cancelReason,
      'createdAt': createdAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// DTO para requisição de criação de desafio.
class CriarDesafioRequest {
  final String challengedId;
  final String matchId;
  final Palpite challengerPrediction;
  final int amount;

  const CriarDesafioRequest({
    required this.challengedId,
    required this.matchId,
    required this.challengerPrediction,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
        'challengedId': challengedId,
        'matchId': matchId,
        'challengerPrediction': challengerPrediction.valor,
        'amount': amount,
      };
}

/// Resposta da Callable Function createChallenge.
class CriarDesafioResponse {
  final String challengeId;
  final StatusDesafio status;
  final String challengerId;
  final String challengedId;
  final String matchId;
  final Palpite challengerPrediction;
  final int amount;

  const CriarDesafioResponse({
    required this.challengeId,
    required this.status,
    required this.challengerId,
    required this.challengedId,
    required this.matchId,
    required this.challengerPrediction,
    required this.amount,
  });

  factory CriarDesafioResponse.fromMap(Map<String, dynamic> map) {
    return CriarDesafioResponse(
      challengeId: map['challengeId']?.toString() ?? '',
      status: StatusDesafio.deValor(map['status']) ?? StatusDesafio.pending,
      challengerId: map['challengerId']?.toString() ?? '',
      challengedId: map['challengedId']?.toString() ?? '',
      matchId: map['matchId']?.toString() ?? '',
      challengerPrediction:
          Palpite.deValor(map['challengerPrediction']) ?? Palpite.homeWin,
      amount: (map['amount'] as num?)?.toInt() ?? 10,
    );
  }
}

/// DTO para requisição de aceite de desafio.
class AceitarDesafioRequest {
  final String challengeId;
  final Palpite challengedPrediction;

  const AceitarDesafioRequest({
    required this.challengeId,
    required this.challengedPrediction,
  });

  Map<String, dynamic> toMap() => {
        'challengeId': challengeId,
        'challengedPrediction': challengedPrediction.valor,
      };
}

/// Resposta da Callable Function acceptChallenge.
class AceitarDesafioResponse {
  final String challengeId;
  final StatusDesafio status;
  final String challengerId;
  final String challengedId;
  final String matchId;
  final Palpite challengerPrediction;
  final Palpite challengedPrediction;
  final int amount;
  final DateTime acceptedAt;

  const AceitarDesafioResponse({
    required this.challengeId,
    required this.status,
    required this.challengerId,
    required this.challengedId,
    required this.matchId,
    required this.challengerPrediction,
    required this.challengedPrediction,
    required this.amount,
    required this.acceptedAt,
  });

  factory AceitarDesafioResponse.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return AceitarDesafioResponse(
      challengeId: map['challengeId']?.toString() ?? '',
      status: StatusDesafio.deValor(map['status']) ?? StatusDesafio.accepted,
      challengerId: map['challengerId']?.toString() ?? '',
      challengedId: map['challengedId']?.toString() ?? '',
      matchId: map['matchId']?.toString() ?? '',
      challengerPrediction:
          Palpite.deValor(map['challengerPrediction']) ?? Palpite.homeWin,
      challengedPrediction:
          Palpite.deValor(map['challengedPrediction']) ?? Palpite.awayWin,
      amount: (map['amount'] as num?)?.toInt() ?? 10,
      acceptedAt: parseDate(map['acceptedAt']),
    );
  }
}

