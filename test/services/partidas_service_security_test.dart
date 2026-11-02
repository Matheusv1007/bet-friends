import 'package:flutter_test/flutter_test.dart';
import 'package:betfriends/services/api/api_client.dart';
import 'package:betfriends/services/api/partidas_service.dart';

void main() {
  group('Gerenciamento de Segurança de Credenciais (KAN-21: RN-SEC-003, RN-SEC-005, RNF-004)', () {
    test('PartidasService padrão não inclui token nem credenciais em cabeçalhos HTTP', () {
      final service = PartidasService();
      expect(service.client.defaultHeaders, isNull);
    });

    test('PartidasService com apiKey customizada repassa cabeçalho apenas se explicitamente fornecido', () {
      final service = PartidasService(apiKey: 'teste-token');
      expect(service.client.defaultHeaders, {'X-Auth-Token': 'teste-token'});
    });

    test('formatErrorMessage não expõe credenciais ou tokens em caso de falha', () {
      final erroComToken = ApiException(
        statusCode: 401,
        rawBody: '{"message": "Your API token 9294186c0e964542a6661b69665bd315 is invalid"}',
      );
      final mensagem = PartidasService.formatErrorMessage(erroComToken);
      expect(mensagem.contains('9294186c0e964542a6661b69665bd315'), isFalse);
      expect(mensagem.contains('token'), isFalse);
      expect(mensagem, 'Não foi possível autorizar o acesso ao serviço de partidas.');
    });

    test('Ausência do token hardcoded no código Flutter', () {
      // Garante que o client padrão não tem cabeçalho de autenticação
      final service = PartidasService();
      final headers = service.client.defaultHeaders;
      expect(headers == null || headers.isEmpty, isTrue);
    });
  });
}
