import 'package:cloud_firestore/cloud_firestore.dart';

/// Perfil do usuário persistido em `users/{uid}` (docs/firestore-schema.md §3.1).
///
/// O [uid] é o UID do Firebase Authentication e é a única identidade estável:
/// vem sempre do ID do documento, nunca do conteúdo, e não é gravado nos campos.
/// Username e e-mail são apenas dados do perfil, não chaves de referência.
class UserProfile {
  final String uid;
  final String displayName;
  final String username;
  final String usernameNormalized;
  final String email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.usernameNormalized,
    required this.email,
    this.createdAt,
    this.updatedAt,
  });

  /// Converte os dados de `users/{uid}`. Lança [FormatException] se o
  /// documento não tiver os campos obrigatórios do schema.
  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    if (uid.trim().isEmpty) {
      throw const FormatException('UID do perfil vazio.');
    }

    return UserProfile(
      uid: uid,
      displayName: _texto(data, 'displayName'),
      username: _texto(data, 'username'),
      usernameNormalized: _texto(data, 'usernameNormalized'),
      email: _texto(data, 'email'),
      createdAt: _data(data, 'createdAt'),
      updatedAt: _data(data, 'updatedAt'),
    );
  }

  /// Campos gravados no documento. O UID não entra: ele é o ID do documento.
  /// Datas vão como [Timestamp] em UTC; ausentes ficam de fora.
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'username': username,
      'usernameNormalized': usernameNormalized,
      'email': email,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!.toUtc()),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!.toUtc()),
    };
  }

  static String _texto(Map<String, dynamic> data, String campo) {
    final valor = data[campo];
    if (valor is! String || valor.trim().isEmpty) {
      throw FormatException('Campo "$campo" ausente ou inválido no perfil.');
    }
    return valor;
  }

  /// `null` é aceito: um `serverTimestamp()` pendente chega nulo na leitura local.
  static DateTime? _data(Map<String, dynamic> data, String campo) {
    final valor = data[campo];
    if (valor == null) return null;
    if (valor is Timestamp) return valor.toDate().toUtc();
    if (valor is DateTime) return valor.toUtc();
    throw FormatException('Campo "$campo" com tipo de data inválido no perfil.');
  }
}
