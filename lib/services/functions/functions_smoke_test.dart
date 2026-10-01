import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'functions_service.dart';

/// Chamada técnica Flutter -> Callable Function (apenas em debug).
///
/// Ativada com `--dart-define=FUNCTIONS_SMOKE_TEST=true`. Assim que houver um
/// usuário logado, chama `systemPing` e imprime no console o uid recebido
/// pelo backend.
void runFunctionsSmokeTestOnSignIn() {
  FirebaseAuth.instance
      .authStateChanges()
      .firstWhere((user) => user != null)
      .then((user) async {
        try {
          final result = await FunctionsService().ping();
          final ok = result.uid == user!.uid;
          debugPrint(
            '[FunctionsSmokeTest] ${ok ? 'OK' : 'UID DIVERGENTE'}: $result',
          );
        } catch (e) {
          debugPrint('[FunctionsSmokeTest] FALHOU: $e');
        }
      });
}
