import 'package:betfriends/app.dart';
import 'package:betfriends/tema/tema_app.dart';
import 'package:betfriends/services/registro_de_erros.dart';
import 'package:betfriends/services/functions/functions_service.dart';
import 'package:betfriends/services/functions/functions_smoke_test.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    registrarErro('executar framework Flutter', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (erro, pilha) {
    registrarErro('executar operação assíncrona não tratada', erro, pilha);
    return true;
  };

  // Ícones claros sobre o fundo escuro, inclusive nas telas sem AppBar
  SystemChrome.setSystemUIOverlayStyle(TemaApp.barrasDoSistema);
  // A fonte embutida é SIL OFL 1.1: a licença aparece na tela de licenças
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Schibsted Grotesk'],
      await rootBundle.loadString('assets/fonts/OFL-SchibstedGrotesk.txt'),
    );
  });

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
