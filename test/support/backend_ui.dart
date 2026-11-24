// Cenários locais para regressão visual e de acessibilidade, sem rede/Firebase.
import 'dart:async';

import 'package:betfriends/app.dart';
import 'package:betfriends/data/firestore/challenge_repository.dart';
import 'package:betfriends/data/firestore/extrato_repository.dart';
import 'package:betfriends/data/firestore/friendship_repository.dart';
import 'package:betfriends/data/firestore/historico_de_desafios_repository.dart';
import 'package:betfriends/data/firestore/user_profile_repository.dart';
import 'package:betfriends/data/firestore/user_search_repository.dart';
import 'package:betfriends/models/carteira.dart';
import 'package:betfriends/models/challenge_model.dart';
import 'package:betfriends/models/desafio_encerrado.dart';
import 'package:betfriends/models/friendship_model.dart';
import 'package:betfriends/models/lancamento_do_extrato.dart';
import 'package:betfriends/models/partida_model.dart';
import 'package:betfriends/models/user_profile.dart';
import 'package:betfriends/models/usuario_publico.dart';
import 'package:betfriends/services/api/partidas_service.dart';
import 'package:betfriends/services/challenge_service.dart';
import 'package:betfriends/services/extrato_service.dart';
import 'package:betfriends/services/friendship_service.dart';
import 'package:betfriends/services/historico_de_desafios_service.dart';
import 'package:betfriends/services/user_profile_service.dart';
import 'package:betfriends/services/user_search_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'fake_auth.dart';

const uidAna = 'uid-ana';

const ana = UserProfile(
  uid: uidAna,
  displayName: 'Ana Lima',
  username: 'AnaL',
  usernameNormalized: 'anal',
  email: 'ana.lima@example.com',
);

const bruno = UsuarioPublico(
  userId: 'uid-bruno',
  displayName: 'Bruno Alves',
  username: 'brunoalves',
);
const carla = UsuarioPublico(
  userId: 'uid-carla',
  displayName: 'Carla Mendes',
  username: 'carlam',
);
const diego = UsuarioPublico(
  userId: 'uid-diego',
  displayName: 'Diego Fernandes de Albuquerque Souza',
  username: 'diego_fernandes_albuquerque',
);
const elisa = UsuarioPublico(
  userId: 'uid-elisa',
  displayName: 'Elisa Prado',
  username: 'elisap',
);
const felipe = UsuarioPublico(
  userId: 'uid-felipe',
  displayName: 'Felipe Ramos',
  username: 'feramos',
);
const gabriela = UsuarioPublico(
  userId: 'uid-gabi',
  displayName: 'Gabriela Torres',
  username: 'gabitorres',
);

const amigosPadrao = [bruno, carla, diego, elisa, felipe, gabriela];

/// Modo de resposta do serviço de partidas.
enum ModoPartidas { normal, carregando, erro, vazio, refreshComErro }

DateTime _agora() => DateTime.now().toUtc();

PartidaModel _p(
  String id,
  String mandante,
  String visitante,
  String codigo, {
  String status = 'AGENDADA',
  Duration em = const Duration(hours: 3),
  int? gm,
  int? gv,
  String? minuto,
  int? rodada,
}) => PartidaModel(
  id: id,
  timeMandante: mandante,
  timeVisitante: visitante,
  status: status,
  golsMandante: gm,
  golsVisitante: gv,
  minuto: minuto,
  startsAtUtc: _agora().add(em),
  syncedAt: _agora(),
  competitionCode: codigo,
  matchday: rodada,
  season: 2026,
);

List<PartidaModel> partidasPadrao({bool semSerieA = false}) => [
  _p(
    'm1',
    'Internacional',
    'Vitória',
    'BSA',
    em: const Duration(hours: 3),
    rodada: 30,
  ),
  _p(
    'm2',
    'Flamengo',
    'Palmeiras',
    'BSA',
    status: 'EM_ANDAMENTO',
    em: const Duration(minutes: -67),
    gm: 1,
    gv: 0,
    minuto: "67'",
    rodada: 30,
  ),
  _p(
    'm3',
    'Atlético Mineiro',
    'Athletico Paranaense',
    'BSA',
    em: const Duration(days: 1, hours: 2),
    rodada: 30,
  ),
  _p(
    'm4',
    'Corinthians',
    'São Paulo',
    'BSA',
    status: 'FINALIZADA',
    em: const Duration(days: -1),
    gm: 2,
    gv: 1,
    rodada: 29,
  ),
  _p(
    'm5',
    'Arsenal',
    'Chelsea',
    'PL',
    em: const Duration(days: 1, hours: 4),
    rodada: 12,
  ),
  _p(
    'm6',
    'Manchester City',
    'Liverpool',
    'PL',
    em: const Duration(days: 2),
    rodada: 12,
  ),
  _p(
    'm7',
    'Brighton & Hove Albion',
    'Wolverhampton Wanderers',
    'PL',
    em: const Duration(days: 2, hours: 3),
    rodada: 12,
  ),
  if (!semSerieA) ...[
    _p(
      'm8',
      'Juventus',
      'Milan',
      'SA',
      em: const Duration(days: 1, hours: 6),
      rodada: 13,
    ),
    _p(
      'm9',
      'Inter de Milão',
      'Napoli',
      'SA',
      status: 'FINALIZADA',
      em: const Duration(days: -2),
      gm: 1,
      gv: 1,
      rodada: 12,
    ),
  ],
  _p(
    'm10',
    'Real Madrid',
    'Barcelona',
    'PD',
    em: const Duration(days: 2, hours: 5),
    rodada: 14,
  ),
  _p(
    'm11',
    'Atlético de Madrid',
    'Sevilla',
    'PD',
    status: 'EM_ANDAMENTO',
    em: const Duration(minutes: -34),
    gm: 0,
    gv: 0,
    minuto: "34'",
    rodada: 14,
  ),
  _p(
    'm12',
    'Valencia',
    'Villarreal',
    'PD',
    status: 'ADIADA',
    em: const Duration(days: 3),
    rodada: 14,
  ),
];

ChallengeModel _c(
  String id,
  String desafiante,
  String desafiado,
  String partida,
  Palpite p1,
  int valor,
  StatusDesafio status, {
  Palpite? p2,
  String? vencedor,
  Palpite? resultado,
  String? motivo,
  Duration criado = const Duration(hours: -5),
}) {
  final t = DateTime.now().add(criado);
  return ChallengeModel(
    id: id,
    challengerId: desafiante,
    challengedId: desafiado,
    participants: [desafiante, desafiado],
    matchId: partida,
    challengerPrediction: p1,
    challengedPrediction: p2,
    amount: valor,
    status: status,
    winnerId: vencedor,
    settledResult: resultado,
    cancelReason: motivo,
    createdAt: t,
    acceptedAt: p2 != null ? t.add(const Duration(minutes: 20)) : null,
    finishedAt: status == StatusDesafio.finished
        ? t.add(const Duration(hours: 3))
        : null,
    updatedAt: t,
  );
}

List<ChallengeModel> desafiosPadrao() => [
  _c(
    'c1',
    bruno.userId,
    uidAna,
    'm1',
    Palpite.homeWin,
    100,
    StatusDesafio.pending,
  ),
  _c('c2', carla.userId, uidAna, 'm5', Palpite.draw, 50, StatusDesafio.pending),
  _c(
    'c3',
    uidAna,
    diego.userId,
    'm10',
    Palpite.homeWin,
    100,
    StatusDesafio.pending,
  ),
  _c(
    'c4',
    uidAna,
    elisa.userId,
    'm6',
    Palpite.homeWin,
    200,
    StatusDesafio.accepted,
    p2: Palpite.awayWin,
  ),
  _c(
    'c5',
    felipe.userId,
    uidAna,
    'm2',
    Palpite.homeWin,
    50,
    StatusDesafio.inProgress,
    p2: Palpite.draw,
  ),
  _c(
    'c6',
    uidAna,
    bruno.userId,
    'm4',
    Palpite.homeWin,
    100,
    StatusDesafio.finished,
    p2: Palpite.awayWin,
    vencedor: uidAna,
    resultado: Palpite.homeWin,
    criado: const Duration(days: -2),
  ),
  _c(
    'c7',
    carla.userId,
    uidAna,
    'm9',
    Palpite.homeWin,
    50,
    StatusDesafio.finished,
    p2: Palpite.draw,
    vencedor: null,
    resultado: Palpite.draw,
    criado: const Duration(days: -3),
  ),
  _c(
    'c8',
    diego.userId,
    uidAna,
    'm4',
    Palpite.awayWin,
    150,
    StatusDesafio.finished,
    p2: Palpite.homeWin,
    vencedor: diego.userId,
    resultado: Palpite.awayWin,
    criado: const Duration(days: -4),
  ),
  _c(
    'c9',
    uidAna,
    diego.userId,
    'm12',
    Palpite.homeWin,
    100,
    StatusDesafio.cancelled,
    motivo: 'MATCH_POSTPONED',
    criado: const Duration(days: -1),
  ),
];

LancamentoDoExtrato _l(
  String id,
  String tipo,
  int valor,
  int saldo,
  DateTime quando,
) => LancamentoDoExtrato.fromMap(id, {
  'userId': uidAna,
  'type': tipo,
  'amount': valor,
  'balanceAfter': {'saldoTotal': saldo, 'saldoReservado': 0},
  'challengeId': 'desafio-interno',
  'createdAt': Timestamp.fromDate(quando),
});

List<LancamentoDoExtrato> extratoPadrao() => [
  _l('e1', 'RESERVE', 100, 1000, DateTime(2026, 11, 23, 14, 30)),
  _l('e2', 'WIN', 200, 1000, DateTime(2026, 11, 22, 21, 5)),
  _l('e3', 'LOSS', 150, 800, DateTime(2026, 11, 21, 18, 42)),
  _l('e4', 'REFUND', 50, 950, DateTime(2026, 11, 20, 16, 10)),
  _l('e5', 'RELEASE', 100, 950, DateTime(2026, 11, 19, 12, 0)),
  _l('e6', 'RECOVERY_BONUS', 100, 100, DateTime(2026, 11, 10, 9, 0)),
  _l('e7', 'INITIAL_BALANCE', 1000, 1000, DateTime(2026, 11, 1, 10, 0)),
];

DesafioEncerrado _h(
  String id,
  String partida,
  String adv,
  int valor,
  StatusEncerrado st, {
  String? vencedor,
  String? resultado,
  String? motivo,
  int dia = 20,
  bool euCriei = true,
}) {
  return DesafioEncerrado(
    id: id,
    challengerId: euCriei ? uidAna : adv,
    challengedId: euCriei ? adv : uidAna,
    matchId: partida,
    challengerPrediction: 'HOME_WIN',
    challengedPrediction: st == StatusEncerrado.finished ? 'AWAY_WIN' : null,
    amount: valor,
    status: st,
    winnerId: vencedor,
    settledResult: resultado,
    cancelReason: motivo,
    createdAt: DateTime(2026, 11, dia - 2),
    acceptedAt: null,
    startedAt: null,
    finishedAt: DateTime(2026, 11, dia),
  );
}

List<DesafioEncerrado> historicoPadrao() => [
  _h(
    'h1',
    'm4',
    bruno.userId,
    100,
    StatusEncerrado.finished,
    vencedor: uidAna,
    resultado: 'HOME_WIN',
    dia: 22,
  ),
  _h(
    'h2',
    'm9',
    carla.userId,
    50,
    StatusEncerrado.finished,
    resultado: 'DRAW',
    dia: 21,
    euCriei: false,
  ),
  _h(
    'h3',
    'm4',
    diego.userId,
    150,
    StatusEncerrado.finished,
    vencedor: diego.userId,
    resultado: 'HOME_WIN',
    dia: 20,
    euCriei: false,
  ),
  _h(
    'h4',
    'm12',
    diego.userId,
    100,
    StatusEncerrado.cancelled,
    motivo: 'MATCH_POSTPONED',
    dia: 19,
  ),
  _h('h5', 'm5', elisa.userId, 30, StatusEncerrado.rejected, dia: 18),
  _h('h6', 'm6', felipe.userId, 500, StatusEncerrado.expired, dia: 17),
];

// ---------------------------------------------------------------------------

class Backend {
  Carteira carteira = Carteira(saldoTotal: 1000, saldoReservado: 100);
  UserProfile? perfil = ana;
  bool perfilDoCache = false;
  bool perfilComErro = false;

  ModoPartidas modoPartidas = ModoPartidas.normal;
  List<PartidaModel> partidas = partidasPadrao();
  List<ChallengeModel> desafios = desafiosPadrao();
  String modoDesafios = 'normal'; // normal | carregando | erro

  List<UsuarioPublico> amigos = List.of(amigosPadrao);
  List<SolicitacaoAmizade> solicitacoes = [];
  bool amigosComErro = false;
  bool solicitacoesComErro = false;
  List<UsuarioPublico> bancoBusca = const [
    UsuarioPublico(
      userId: 'u-marcos',
      displayName: 'Marcos Vinícius',
      username: 'marcosv',
    ),
    UsuarioPublico(
      userId: 'u-mariana',
      displayName: 'Mariana Costa',
      username: 'marianac',
    ),
    UsuarioPublico(
      userId: 'u-marta',
      displayName: 'Marta Silva de Oliveira Pereira',
      username: 'marta_silva_oliveira_pereira',
    ),
    UsuarioPublico(
      userId: 'u-marcelo',
      displayName: 'Marcelo Dias',
      username: 'marcelod',
    ),
  ];

  List<LancamentoDoExtrato> extrato = extratoPadrao();
  String modoExtrato = 'normal'; // normal | carregando | erro | vazio
  List<DesafioEncerrado> historico = historicoPadrao();
  String modoHistorico = 'normal'; // normal | carregando | erro | vazio

  bool logado = true;
  bool sessaoPendente = false;
  Object? signInError;
  Object? signUpError;

  // Instâncias criadas por [app].
  late FakeAuthService auth;
  late PartidasService partidasService;

  Widget app() {
    auth =
        _Auth(
            this,
            usuarioInicial: logado ? FakeUser(uidAna, email: ana.email) : null,
            sessaoPendente: sessaoPendente,
          )
          ..signInError = signInError
          ..signUpError = signUpError;
    partidasService = _PartidasFake(this);
    final perfis = UserProfileService(
      authService: auth,
      repository: _Perfis(this),
    );
    final challengeRepo = _Desafios(this);
    return Provider<ExtratoService?>.value(
      value: ExtratoService(authService: auth, repository: _Extrato(this)),
      child: App(
        authService: auth,
        partidasService: partidasService,
        userProfileService: perfis,
        challengeService: ChallengeService(
          authService: auth,
          repository: challengeRepo,
        ),
        friendshipService: FriendshipService(
          authService: auth,
          repository: _Amizades(this),
        ),
        userSearchService: UserSearchService(
          authService: auth,
          repository: _Busca(this),
        ),
        historicoService: HistoricoDeDesafiosService(
          authService: auth,
          repository: _Historico(this),
        ),
      ),
    );
  }
}

class _Auth extends FakeAuthService {
  final Backend b;
  _Auth(this.b, {super.usuarioInicial, super.sessaoPendente});

  @override
  Future<UserCredential> signIn({
    required String identifier,
    required String password,
  }) async {
    signInCalls++;
    if (signInError != null) throw signInError!;
    return super.signIn(identifier: identifier, password: password);
  }
}

class _PartidasFake extends PartidasService {
  final Backend b;
  bool falharAgora = false;
  _PartidasFake(this.b);

  @override
  Future<List<PartidaModel>> getPartidas() async {
    switch (b.modoPartidas) {
      case ModoPartidas.carregando:
        return Completer<List<PartidaModel>>().future;
      case ModoPartidas.erro:
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      case ModoPartidas.vazio:
        return [];
      case ModoPartidas.refreshComErro:
        if (falharAgora) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        }
        return List.of(b.partidas);
      case ModoPartidas.normal:
        return List.of(b.partidas);
    }
  }
}

class _Perfis implements UserProfileRepository {
  final Backend b;
  _Perfis(this.b);

  @override
  Stream<PerfilObservado> observarPorUid(String uid) {
    if (b.perfilComErro) {
      return Stream.error(
        const UserProfileException(
          UserProfileErrorCode.unavailable,
          'Sem conexão.',
        ),
      );
    }
    return Stream.value(
      PerfilObservado(b.perfil, carteira: b.carteira, doCache: b.perfilDoCache),
    );
  }

  @override
  Future<UserProfile?> buscarPorUid(String uid) async => b.perfil;

  @override
  Future<void> atualizarDisplayName(String uid, String displayName) async {}
}

class _Amizades implements FriendshipRepository {
  final Backend b;
  _Amizades(this.b);

  @override
  Future<void> removerAmizade(String friendshipId) async {}

  @override
  Future<List<UsuarioPublico>> listarAmigosAceitos() async {
    if (b.amigosComErro) {
      throw const FriendshipException(
        FriendshipErrorCode.unavailable,
        'Falha temporária de rede.',
      );
    }
    return List.of(b.amigos);
  }

  @override
  Future<PaginaSolicitacoesAmizade> listarSolicitacoesPendentes({
    Map<String, dynamic>? cursor,
  }) async {
    if (b.solicitacoesComErro) {
      throw const FriendshipException(
        FriendshipErrorCode.unavailable,
        'Falha temporária de rede.',
      );
    }
    return PaginaSolicitacoesAmizade(requests: List.of(b.solicitacoes));
  }

  @override
  Future<ResultadoAceiteAmizade> aceitarSolicitacaoAmizade(String id) async =>
      ResultadoAceiteAmizade(
        friendshipId: id,
        userAId: 'x',
        userBId: uidAna,
        status: FriendshipStatus.accepted,
      );

  @override
  Future<ResultadoRecusaAmizade> recusarSolicitacaoAmizade(String id) async =>
      ResultadoRecusaAmizade(
        friendshipId: id,
        userAId: 'x',
        userBId: uidAna,
        status: FriendshipStatus.rejected,
      );

  @override
  Future<ResultadoEnvioAmizade> enviarSolicitacaoAmizade(
    String toUserId,
  ) async => const ResultadoEnvioAmizade(
    friendshipId: 'nova',
    status: FriendshipStatus.pending,
    autoAccepted: false,
  );
}

class _Busca implements UserSearchRepository {
  final Backend b;
  _Busca(this.b);

  @override
  Future<List<UsuarioPublico>> buscarUsuarios(
    String termo, {
    required String usuarioAtualUid,
    int limite = 20,
  }) async {
    final t = termo.trim().toLowerCase().replaceFirst('@', '');
    return b.bancoBusca
        .where(
          (u) =>
              u.username.toLowerCase().contains(t) ||
              u.displayName.toLowerCase().contains(t),
        )
        .toList();
  }
}

class _Desafios implements ChallengeRepository {
  final Backend b;
  _Desafios(this.b);

  @override
  Stream<List<ChallengeModel>> observarDesafiosDoUsuario(String uid) {
    switch (b.modoDesafios) {
      case 'carregando':
        return StreamController<List<ChallengeModel>>().stream;
      case 'erro':
        return Stream.error(StateError('falha simulada'));
      default:
        return Stream.value(List.of(b.desafios));
    }
  }

  @override
  Future<List<ChallengeModel>> listarDesafiosDoUsuario(String uid) async =>
      List.of(b.desafios);

  @override
  Future<int?> buscarSaldoDisponivel(String uid) async =>
      b.carteira.saldoDisponivel;

  @override
  Future<List<AmigoItem>> listarAmigosAceitos(String uid) async => [
    for (final a in b.amigos)
      AmigoItem(
        uid: a.userId,
        displayName: a.displayName,
        username: a.username,
      ),
  ];

  @override
  Future<CriarDesafioResponse> criarDesafio(
    CriarDesafioRequest request,
  ) async => throw UnimplementedError();
  @override
  Future<AceitarDesafioResponse> aceitarDesafio(
    AceitarDesafioRequest request,
  ) async => throw UnimplementedError();
  @override
  Future<EncerrarDesafioResponse> recusarDesafio(String challengeId) async =>
      throw UnimplementedError();
  @override
  Future<EncerrarDesafioResponse> cancelarDesafio(String challengeId) async =>
      throw UnimplementedError();
}

class _Extrato implements ExtratoRepository {
  final Backend b;
  _Extrato(this.b);

  @override
  Future<PaginaDoExtrato> buscar(
    String uid, {
    int limite = 20,
    CursorDoExtrato? cursor,
  }) async {
    switch (b.modoExtrato) {
      case 'carregando':
        return Completer<PaginaDoExtrato>().future;
      case 'erro':
        throw const ExtratoException(
          ExtratoErrorCode.unavailable,
          'Sem conexão. Verifique sua internet.',
        );
      case 'vazio':
        return const PaginaDoExtrato(
          itens: [],
          ignorados: 0,
          doCache: false,
          temMais: false,
          proximoCursor: null,
        );
      default:
        return PaginaDoExtrato(
          itens: b.extrato,
          ignorados: 0,
          doCache: false,
          temMais: false,
          proximoCursor: null,
        );
    }
  }
}

class _Historico implements HistoricoDeDesafiosRepository {
  final Backend b;
  _Historico(this.b);

  @override
  Future<PaginaDoHistorico> buscar(
    String uid, {
    int limite = 20,
    CursorDoHistorico? cursor,
  }) async {
    switch (b.modoHistorico) {
      case 'carregando':
        return Completer<PaginaDoHistorico>().future;
      case 'erro':
        throw const HistoricoException(
          HistoricoErrorCode.unavailable,
          'Sem conexão. Verifique sua internet.',
        );
      case 'vazio':
        return const PaginaDoHistorico(
          itens: [],
          ignorados: 0,
          doCache: false,
          temMais: false,
          proximoCursor: null,
        );
      default:
        return PaginaDoHistorico(
          itens: b.historico,
          ignorados: 0,
          doCache: false,
          temMais: false,
          proximoCursor: null,
        );
    }
  }
}
