import 'package:flutter_test/flutter_test.dart';
import 'package:betfriends/data/firestore/partidas_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:betfriends/services/api/partidas_service.dart';

void main() {
  group('Gerenciamento de Segurança de Credenciais, Provedor e Rotação (KAN-21, KAN-42, KAN-102; RN-SEC-003, RN-SEC-005, RNF-004, RNF-005)', () {
    test('PartidasService padrão conecta ao Firestore e não ao provedor externo', () {
      final service = PartidasService();
      expect(service.repository, isA<FirestorePartidasRepository>());
    });

    test('formatErrorMessage não expõe credenciais ou tokens em caso de falha', () {
      final erroComToken = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'fake_secret_token_12345',
      );
      final mensagem = PartidasService.formatErrorMessage(erroComToken);
      expect(mensagem.contains('fake_secret_token_12345'), isFalse);
      expect(mensagem.contains('token'), isFalse);
      expect(mensagem, 'Não foi possível autorizar o acesso ao serviço de partidas.');
    });

    test('formatErrorMessage trata erros do Firestore sem vazar dados técnicos', () {
      final erroFirebase = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Dados técnicos internos',
      );
      final mensagem = PartidasService.formatErrorMessage(erroFirebase);
      expect(mensagem, 'Serviço de partidas temporariamente indisponível. Verifique sua conexão e tente novamente.');
    });

    test('Serviço não aceita chave de API no construtor (RN-SEC-003)', () {
      expect(
        () => Function.apply(PartidasService.new, [], {#apiKey: 'chave-proibida'}),
        throwsA(isA<NoSuchMethodError>()),
      );
    });

    test('Permissão recusada no Firestore não vaza dados técnicos na mensagem amigável', () {
      final erroCredencialRevogada = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'token revoked',
      );
      final mensagem = PartidasService.formatErrorMessage(erroCredencialRevogada);
      expect(mensagem, 'Não foi possível autorizar o acesso ao serviço de partidas.');
      expect(mensagem.contains('token'), isFalse);
      expect(mensagem.contains('revoked'), isFalse);
    });
  });
}
