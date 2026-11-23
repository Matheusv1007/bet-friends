/// Representação pública de um usuário cadastrado no BetFriends (RF-004).
///
/// Diretrizes de Privacidade e Arquitetura:
/// - [userId]: UID do Firebase Authentication como identidade única e estável (RN-AUTH-006).
/// - [displayName]: Nome legível exibido para o usuário.
/// - [username]: Identificador legível único (@username).
/// - Dados privados (e-mail, saldos detalhados de BetCoins, transações e dados internos)
///   NUNCA são expostos neste modelo (RN-PROF-002).
class UsuarioPublico {
  final String userId;
  final String displayName;
  final String username;

  const UsuarioPublico({
    required this.userId,
    required this.displayName,
    required this.username,
  });

  /// Instancia o perfil público a partir de um mapa de dados.
  /// Lança [FormatException] se o identificador estiver vazio.
  factory UsuarioPublico.fromMap(Map<String, dynamic> data) {
    final uid = data['userId'] ?? data['uid'] ?? '';
    final name = data['displayName'] ?? '';
    final user = data['username'] ?? '';

    if (uid.toString().trim().isEmpty) {
      throw const FormatException('Identificador de usuário (userId/uid) ausente.');
    }

    final usernameLimpo = user.toString().trim().replaceFirst(RegExp(r'^@'), '');

    return UsuarioPublico(
      userId: uid.toString().trim(),
      displayName: name.toString().trim().isEmpty ? 'Usuário' : name.toString().trim(),
      username: usernameLimpo.isEmpty ? 'usuario' : usernameLimpo,
    );
  }

  /// Converte para mapa contendo EXCLUSIVAMENTE os dados públicos permitidos.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'username': username,
    };
  }

  /// Retorna o username formatado com @ para exibição na interface
  String get usernameComArroba => '@$username';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsuarioPublico &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() =>
      'UsuarioPublico(userId: $userId, displayName: $displayName, username: @$username)';
}
