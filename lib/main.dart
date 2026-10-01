import 'package:betfriends/app.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:betfriends/services/functions/functions_smoke_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização do Firebase (se estiver usando)
  await Firebase.initializeApp();

  // Callable Functions locais: --dart-define=USE_FUNCTIONS_EMULATOR=true
  if (const bool.fromEnvironment('USE_FUNCTIONS_EMULATOR')) {
    FunctionsService.useEmulator(
      host: const String.fromEnvironment(
        'FUNCTIONS_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      ),
    );
  }

  // Chamada técnica ao backend: --dart-define=FUNCTIONS_SMOKE_TEST=true
  if (kDebugMode && const bool.fromEnvironment('FUNCTIONS_SMOKE_TEST')) {
    runFunctionsSmokeTestOnSignIn();
  }

  runApp(const App());
}
