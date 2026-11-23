import 'package:betfriends/services/functions/functions_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PingResult converte a resposta do systemPing', () {
    final result = PingResult.fromMap({
      'ok': true,
      'uid': 'user-123',
      'email': 'a@b.com',
      'emailVerified': false,
      'region': 'southamerica-east1',
      'serverTime': '2026-10-01T12:00:00.000Z',
    });

    expect(result.uid, 'user-123');
    expect(result.email, 'a@b.com');
    expect(result.region, kFunctionsRegion);
    expect(result.serverTime, DateTime.utc(2026, 10, 1, 12));
  });

  group('FunctionsException sem confirmação do servidor (KAN-24)', () {
    test('sem conexão e prazo esgotado não confirmam a operação', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          FunctionsException(code: code, message: 'x').semConfirmacaoDoServidor,
          isTrue,
          reason: code,
        );
      }
    });

    test('respostas do backend não são confundidas com falta de conexão', () {
      for (final code in ['unauthenticated', 'invalid-argument', 'failed-precondition', 'internal']) {
        expect(
          FunctionsException(code: code, message: 'x').semConfirmacaoDoServidor,
          isFalse,
          reason: code,
        );
      }
    });
  });

  group('FunctionsException.motivo (KAN-32)', () {
    test('lê details.motivo enviado pelo backend', () {
      expect(FunctionsException.motivoDe({'motivo': 'perfil-existente'}), 'perfil-existente');
    });

    test('details ausente ou fora do formato não tem motivo', () {
      for (final details in [null, 'texto', 42, <String, Object>{}, {'motivo': 1}]) {
        expect(FunctionsException.motivoDe(details), isNull, reason: '$details');
      }
    });
  });
}
