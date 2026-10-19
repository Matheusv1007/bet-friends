import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'provider/auth_provider.dart';
import 'provider/partidas_provider.dart';
import 'services/api/partidas_service.dart';
import 'services/auth_service.dart';

// simon = login / sessão
import 'telas_autenticacao/auth_gate.dart';

// kaue = Homepage
//import 'telas_principais/homePage.dart';

class App extends StatelessWidget {
  /// Os serviços são opcionais para permitir fakes em testes.
  final AuthService? authService;
  final PartidasService? partidasService;

  const App({super.key, this.authService, this.partidasService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService: authService),
        ),
        ChangeNotifierProvider(
          create: (_) => PartidasProvider(partidasService: partidasService),
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        //home: Homepage(),
        home: AuthGate(),
      ),
    );
  }
}

///
/// Testar Homepage
///
/*
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PartidasProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BetFriends',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0B111D),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00D084),
            secondary: Color(0xFFF5A623),
            surface: Color(0xFF151E2E),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
        ),
        home: const Homepage(),
      ),
    );
  }
}
*/
