import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'provider/auth_provider.dart';
import 'provider/partidas_provider.dart';
import 'services/api/partidas_service.dart';
import 'services/auth_service.dart';
import 'services/challenge_service.dart';
import 'services/friendship_service.dart';
import 'services/historico_de_desafios_service.dart';
import 'services/user_profile_service.dart';
import 'services/user_search_service.dart';
import 'tema/tema_app.dart';
import 'telas_autenticacao/auth_gate.dart';

class App extends StatelessWidget {
  /// Os serviços são opcionais para permitir fakes em testes.
  final AuthService? authService;
  final PartidasService? partidasService;
  final UserProfileService? userProfileService;
  final ChallengeService? challengeService;
  final FriendshipService? friendshipService;
  final UserSearchService? userSearchService;
  final HistoricoDeDesafiosService? historicoService;

  const App({
    super.key,
    this.authService,
    this.partidasService,
    this.userProfileService,
    this.challengeService,
    this.friendshipService,
    this.userSearchService,
    this.historicoService,
  });

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
        Provider<ChallengeService?>(
          create: (_) =>
              challengeService ?? ChallengeService(authService: authService),
        ),
        // Mesma fonte de sessão do AuthProvider: o perfil é sempre o do UID logado
        Provider(
          create: (_) =>
              userProfileService ?? UserProfileService(authService: authService),
        ),
        Provider<FriendshipService?>(
          create: (_) =>
              friendshipService ?? FriendshipService(authService: authService),
        ),
        Provider<UserSearchService?>(
          create: (_) =>
              userSearchService ?? UserSearchService(authService: authService),
        ),
        Provider<HistoricoDeDesafiosService?>(
          create: (_) =>
              historicoService ?? HistoricoDeDesafiosService(authService: authService),
        ),
      ],
      child: MaterialApp(
        title: 'BetFriends',
        debugShowCheckedModeBanner: false,
        theme: TemaApp.escuro,
        darkTheme: TemaApp.escuro,
        themeMode: ThemeMode.dark,
        home: const AuthGate(),
      ),
    );
  }
}
