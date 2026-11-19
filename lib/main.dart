import 'package:betfriends/app.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:betfriends/services/functions/functions_smoke_test.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização do Firebase (se estiver usando)
  await Firebase.initializeApp();

  // Callable Functions locais: --dart-define=USE_FUNCTIONS_EMULATOR=true
  const usaEmulador = bool.fromEnvironment('USE_FUNCTIONS_EMULATOR');
  if (usaEmulador) {
    FunctionsService.useEmulator(
      host: const String.fromEnvironment(
        'FUNCTIONS_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      ),
    );
  }

  // App Check (A-05): anexa a cada chamada ao backend um token que prova que
  // quem chama é este app. O backend só passa a exigir o token quando
  // ENFORCE_APP_CHECK=true no deploy (docs/callable-functions.md §12); até lá
  // o token é enviado e ignorado. Em debug usa o provedor de depuração (o
  // token aparece no logcat e precisa ser registrado no console); em release,
  // o Play Integrity. Contra os emuladores não há o que atestar.
  if (!usaEmulador) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  }

  // Chamada técnica ao backend: --dart-define=FUNCTIONS_SMOKE_TEST=true
  if (kDebugMode && const bool.fromEnvironment('FUNCTIONS_SMOKE_TEST')) {
    runFunctionsSmokeTestOnSignIn();
  }

  runApp(const App());
}
