import 'package:cloud_functions/cloud_functions.dart';

/// Região das Callable Functions. Deve ser a mesma de functions/src/config.ts.
const String kFunctionsRegion = 'southamerica-east1';

/// Nomes das Callable Functions exportadas em functions/src/index.ts.
abstract final class CallableNames {
  static const String systemPing = 'systemPing';

  /// Cadastro do perfil com username único e carteira inicial (KAN-31).
  /// Username indisponível: `FunctionsException(code: 'already-exists')`.
  /// Chamada por `UserProfileService.criarPerfilDoUsuarioAtual` (KAN-32).
  static const String createUserProfile = 'createUserProfile';
}

/// Ponto único de acesso às Callable Functions do backend.
///
/// O Firebase envia automaticamente o ID token do usuário logado em cada
/// chamada; o backend usa esse token para identificar quem está chamando.
class FunctionsService {
  FunctionsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  final FirebaseFunctions _functions;

  /// Aponta as chamadas para o emulador local. Chame uma vez, no startup.
  /// No emulador Android, `10.0.2.2` é o localhost da máquina host.
  static void useEmulator({String host = '10.0.2.2', int port = 5001}) {
    FirebaseFunctions.instanceFor(
      region: kFunctionsRegion,
    ).useFunctionsEmulator(host, port);
  }

  /// Chama uma Callable Function e devolve a resposta como mapa.
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    try {
      final result = await _functions.httpsCallable(name).call<Object?>(data);
      final response = result.data;
      if (response == null) return {};
      if (response is! Map) {
        throw FunctionsException(
          code: 'internal',
          message: 'Resposta inesperada de $name',
        );
      }
      return Map<String, dynamic>.from(response);
    } on FirebaseFunctionsException catch (e) {
      throw FunctionsException(
        code: e.code,
        message: e.message ?? 'Erro ao chamar $name',
        motivo: FunctionsException.motivoDe(e.details),
      );
    }
  }

  /// Chamada técnica: confirma que o backend responde e recebe o usuário logado.
  Future<PingResult> ping() async {
    final response = await call(CallableNames.systemPing);
    return PingResult.fromMap(response);
  }
}

class PingResult {
  final String uid;
  final String? email;
  final String region;
  final DateTime serverTime;

  PingResult({
    required this.uid,
    required this.email,
    required this.region,
    required this.serverTime,
  });

  factory PingResult.fromMap(Map<String, dynamic> map) {
    return PingResult(
      uid: map['uid'] as String,
      email: map['email'] as String?,
      region: map['region'] as String,
      serverTime: DateTime.parse(map['serverTime'] as String),
    );
  }

  @override
  String toString() =>
      'PingResult(uid: $uid, email: $email, region: $region, serverTime: $serverTime)';
}

/// Erro devolvido por uma Callable Function.
/// `code` segue os códigos do HttpsError (ex.: unauthenticated, invalid-argument).
class FunctionsException implements Exception {
  final String code;
  final String message;

  /// Código do domínio em `details.motivo` (ex.: `perfil-existente`), quando
  /// o backend o envia. Distingue erros que chegam com o mesmo [code].
  final String? motivo;

  FunctionsException({required this.code, required this.message, this.motivo});

  static String? motivoDe(Object? details) {
    if (details is! Map) return null;
    final motivo = details['motivo'];
    return motivo is String ? motivo : null;
  }

  bool get isUnauthenticated => code == 'unauthenticated';

  /// O servidor não confirmou a chamada: sem conexão (`unavailable`) ou prazo
  /// esgotado (`deadline-exceeded`). Chamadas não ficam em fila nem são
  /// repetidas automaticamente; a tela não deve tratar a operação como feita
  /// e repetir depende de nova ação do usuário (KAN-24, RN-OFF-002/003).
  bool get semConfirmacaoDoServidor =>
      code == 'unavailable' || code == 'deadline-exceeded';

  @override
  String toString() => 'FunctionsException ($code): $message';
}
