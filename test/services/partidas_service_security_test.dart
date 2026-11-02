import 'package:flutter_test/flutter_test.dart';
import 'package:betfriends/data/firestore/partidas_repository.dart';
import 'package:betfriends/services/api/api_client.dart';
import 'package:betfriends/services/api/partidas_service.dart';

void main() {
  group('Gerenciamento de Segurança de Credenciais e Provedor (KAN-21, KAN-42; RN-SEC-003, RN-SEC-005, RNF-004, RNF-005)', () {
    test('PartidasService padrão conecta ao Firestore e não ao provedor externo', () {
      final service = PartidasService();
      expect(service.repository, isA<FirestorePartidasRepository>());
    });

    test('formatErrorMessage não expõe credenciais ou tokens em caso de falha', () {
      final erroComToken = ApiException(
        statusCode: 401,
        rawBody: '{"message": "Your API token fake_secret_token_12345 is invalid"}',
      );
      final mensagem = PartidasService.formatErrorMessage(erroComToken);
      expect(mensagem.contains('fake_secret_token_12345'), isFalse);
      expect(mensagem.contains('token'), isFalse);
      expect(mensagem, 'Não foi possível autorizar o acesso ao serviço de partidas.');
    });

    test('formatErrorMessage trata erros do Firestore sem vazar dados técnicos', () {
      final erroFirebase = ApiException(
        statusCode: 503,
        rawBody: 'unavailable',
      );
      final mensagem = PartidasService.formatErrorMessage(erroFirebase);
      expect(mensagem, 'O servidor de partidas está temporariamente indisponível. Tente novamente mais tarde.');
    });
  });
}
