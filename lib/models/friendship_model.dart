/// Status possíveis de uma amizade (docs/firestore-schema.md §3.3).
enum FriendshipStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  rejected('REJECTED');

  final String valor;
  const FriendshipStatus(this.valor);

  static FriendshipStatus fromString(String valor) {
    switch (valor.toUpperCase()) {
      case 'ACCEPTED':
        return FriendshipStatus.accepted;
      case 'REJECTED':
        return FriendshipStatus.rejected;
      case 'PENDING':
      default:
        return FriendshipStatus.pending;
    }
  }
}

/// Resultado do envio de solicitação de amizade (RF-005, RN-FRD-005).
class ResultadoEnvioAmizade {
  final String friendshipId;
  final FriendshipStatus status;
  final bool autoAccepted;

  const ResultadoEnvioAmizade({
    required this.friendshipId,
    required this.status,
    required this.autoAccepted,
  });

  factory ResultadoEnvioAmizade.fromMap(Map<String, dynamic> map) {
    return ResultadoEnvioAmizade(
      friendshipId: map['friendshipId'] as String? ?? '',
      status: FriendshipStatus.fromString(map['status'] as String? ?? 'PENDING'),
      autoAccepted: map['autoAccepted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'friendshipId': friendshipId,
      'status': status.valor,
      'autoAccepted': autoAccepted,
    };
  }
}

/// Resultado do aceite de solicitação de amizade (RF-005, RN-FRD-001, RN-FRD-005).
class ResultadoAceiteAmizade {
  final String friendshipId;
  final FriendshipStatus status;
  final String userAId;
  final String userBId;

  const ResultadoAceiteAmizade({
    required this.friendshipId,
    required this.status,
    required this.userAId,
    required this.userBId,
  });

  factory ResultadoAceiteAmizade.fromMap(Map<String, dynamic> map) {
    return ResultadoAceiteAmizade(
      friendshipId: map['friendshipId'] as String? ?? '',
      status: FriendshipStatus.fromString(map['status'] as String? ?? 'ACCEPTED'),
      userAId: map['userAId'] as String? ?? '',
      userBId: map['userBId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'friendshipId': friendshipId,
      'status': status.valor,
      'userAId': userAId,
      'userBId': userBId,
    };
  }
}

/// Modelo da relação de amizade entre dois usuários no Firestore (docs/firestore-schema.md §3.3).
class FriendshipModel {
  final String id;
  final String userAId;
  final String userBId;
  final List<String> participants;
  final String requesterId;
  final FriendshipStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final DateTime? updatedAt;

  const FriendshipModel({
    required this.id,
    required this.userAId,
    required this.userBId,
    required this.participants,
    required this.requesterId,
    required this.status,
    this.createdAt,
    this.respondedAt,
    this.updatedAt,
  });

  factory FriendshipModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      // Firebase Timestamp tem método toDate()
      try {
        return (v as dynamic).toDate() as DateTime?;
      } catch (_) {
        return null;
      }
    }

    final rawParticipants = map['participants'];
    final participants = rawParticipants is List
        ? rawParticipants.map((e) => e.toString()).toList()
        : <String>[];

    return FriendshipModel(
      id: id,
      userAId: map['userAId'] as String? ?? '',
      userBId: map['userBId'] as String? ?? '',
      participants: participants,
      requesterId: map['requesterId'] as String? ?? '',
      status: FriendshipStatus.fromString(map['status'] as String? ?? 'PENDING'),
      createdAt: parseDate(map['createdAt']),
      respondedAt: parseDate(map['respondedAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userAId': userAId,
      'userBId': userBId,
      'participants': participants,
      'requesterId': requesterId,
      'status': status.valor,
      'createdAt': createdAt?.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
