import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Registra um erro que o app trata e segue em frente (A-07).
///
/// Existe para que nenhum `catch` engula falha sem deixar rastro: o aviso ao
/// usuário continua sendo o da tela, e o diagnóstico (qual operação, qual
/// erro, onde) aparece em debug e no DevTools. Em release não há garantia
/// de coleta persistente ou envio remoto (não usamos Crashlytics).
/// Não troca a mensagem exibida nem relança nada.
///
/// [contexto] diz o que estava sendo feito, ex.: `'buscar desafios do usuário'`.
void registrarErro(String contexto, Object erro, [StackTrace? pilha]) {
  if (kDebugMode) {
    debugPrint('Falha ao $contexto: $erro');
    if (pilha != null) debugPrint(pilha.toString());
  }
  developer.log(
    'Falha ao $contexto',
    name: 'betfriends',
    error: erro,
    stackTrace: pilha,
    level: 1000,
  );
}
