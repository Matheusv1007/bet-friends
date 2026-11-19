import 'package:cloud_firestore/cloud_firestore.dart';

/// Status de domínio interno de partida (RF-008, RN-MAT-002, RNF-013; docs/firestore-schema.md §3.4).
enum StatusPartida {
  agendada('AGENDADA', 'Agendada'),
  emAndamento('EM_ANDAMENTO', 'Em Andamento'),
  finalizada('FINALIZADA', 'Finalizada'),
  adiada('ADIADA', 'Adiada'),
  cancelada('CANCELADA', 'Cancelada'),
  suspensa('SUSPENSA', 'Suspensa'),
  revisaoNecessaria('REVISAO_NECESSARIA', 'Revisão Necessária');

  final String codigo;
  final String rotulo;
  const StatusPartida(this.codigo, this.rotulo);

  static StatusPartida deCodigo(dynamic codigo) {
    if (codigo == null) return StatusPartida.agendada;
    final str = codigo.toString().trim().toUpperCase();
    for (final s in StatusPartida.values) {
      if (s.codigo == str) return s;
    }
    // Mapeamentos para segurança e normalização (RN-MAT-002, RNF-013)
    if (str == 'SCHEDULED' || str == 'TIMED' || str.contains('PRÓXIMO') || str.contains('PROXIMO')) {
      return StatusPartida.agendada;
    }
    if (str == 'IN_PLAY' || str == 'PAUSED' || str == 'LIVE' || str.contains('AO VIVO') || str.contains('ANDAMENTO')) {
      return StatusPartida.emAndamento;
    }
    if (str == 'FINISHED' || str.contains('FINALIZAD')) {
      return StatusPartida.finalizada;
    }
    if (str == 'POSTPONED' || str.contains('ADIAD')) {
      return StatusPartida.adiada;
    }
    if (str == 'CANCELLED' || str.contains('CANCELAD')) {
      return StatusPartida.cancelada;
    }
    if (str == 'SUSPENDED' || str.contains('SUSPENS')) {
      return StatusPartida.suspensa;
    }
    if (str == 'AWARDED' || str.contains('REVIS')) {
      return StatusPartida.revisaoNecessaria;
    }
    return StatusPartida.agendada;
  }
}

/// Resultado normalizado de domínio interno de partida (RF-008, RNF-013; docs/firestore-schema.md §3.4).
enum ResultadoPartida {
  homeWin('HOME_WIN', 'Vitória do Mandante'),
  draw('DRAW', 'Empate'),
  awayWin('AWAY_WIN', 'Vitória do Visitante');

  final String codigo;
  final String rotulo;
  const ResultadoPartida(this.codigo, this.rotulo);

  static ResultadoPartida? deCodigo(dynamic codigo) {
    if (codigo == null) return null;
    final str = codigo.toString().trim().toUpperCase();
    for (final r in ResultadoPartida.values) {
      if (r.codigo == str) return r;
    }
    if (str == 'HOME_TEAM') return ResultadoPartida.homeWin;
    if (str == 'AWAY_TEAM') return ResultadoPartida.awayWin;
    return null;
  }
}

/// Modelo de partida no domínio da aplicação (KAN-42, KAN-43, KAN-46; docs/firestore-schema.md §3.4).
///
/// Diretrizes de Domínio e Segurança:
/// - O armazenamento no backend e Firestore é estritamente em UTC (`startsAtUtc`).
/// - A conversão de data/hora para o fuso local do dispositivo ocorre apenas na exibição (RN-MAT-005, RF-008).
/// - Nunca expõe ou armazena enums brutos do provedor (RN-MAT-002, RNF-013).
class PartidaModel {
  final String id;
  final String timeMandante;
  final String timeVisitante;
  final int? golsMandante;
  final int? golsVisitante;
  final String status;
  final StatusPartida statusDominio;
  final ResultadoPartida? resultado;
  final String? campeonato;
  final String? horario;
  final String? minuto;
  final String? logoMandante;
  final String? logoVisitante;
  final DateTime? startsAtUtc;
  final DateTime? syncedAt;
  final int? matchday;
  final String? competitionCode;
  final int? season;

  PartidaModel({
    required this.id,
    required this.timeMandante,
    required this.timeVisitante,
    this.golsMandante,
    this.golsVisitante,
    String? status,
    StatusPartida? statusDominio,
    ResultadoPartida? resultado,
    this.campeonato,
    String? horario,
    this.minuto,
    this.logoMandante,
    this.logoVisitante,
    this.startsAtUtc,
    this.syncedAt,
    this.matchday,
    this.competitionCode,
    this.season,
  })  : statusDominio = statusDominio ?? StatusPartida.deCodigo(status),
        status = status ??
            (statusDominio != null
                ? mapearStatusDominio(statusDominio.codigo)
                : 'PRÓXIMO JOGO'),
        resultado = resultado ??
            _deduzirResultado(
              statusDominio ?? StatusPartida.deCodigo(status),
              golsMandante,
              golsVisitante,
            ),
        horario = horario ?? formatarHorarioExibicao(startsAtUtc);

  static ResultadoPartida? _deduzirResultado(
    StatusPartida status,
    int? homeGoals,
    int? awayGoals,
  ) {
    if (status != StatusPartida.finalizada) return null;
    if (homeGoals == null || awayGoals == null) return null;
    if (homeGoals > awayGoals) return ResultadoPartida.homeWin;
    if (homeGoals < awayGoals) return ResultadoPartida.awayWin;
    return ResultadoPartida.draw;
  }

  bool get isFinalizado =>
      statusDominio == StatusPartida.finalizada ||
      status.toUpperCase().contains('FINALIZADO') ||
      status.toUpperCase().contains('FINISHED');

  bool get isCancelado =>
      statusDominio == StatusPartida.cancelada ||
      status.toUpperCase().contains('CANCELADO') ||
      status.toUpperCase().contains('CANCELLED');

  bool get isAdiado =>
      statusDominio == StatusPartida.adiada ||
      status.toUpperCase().contains('ADIADO') ||
      status.toUpperCase().contains('POSTPONED');

  bool get isAoVivo =>
      statusDominio == StatusPartida.emAndamento ||
      status.toUpperCase().contains('AO VIVO') ||
      status.toUpperCase().contains('ANDAMENTO') ||
      status.toUpperCase().contains('IN_PLAY') ||
      status.toUpperCase().contains('INTERVALO');

  bool get isAgendado =>
      statusDominio == StatusPartida.agendada ||
      status.toUpperCase().contains('AGENDAD') ||
      status.toUpperCase().contains('PRÓXIMO') ||
      status.toUpperCase().contains('PROXIMO') ||
      status.toUpperCase().contains('SCHEDULED') ||
      status.toUpperCase().contains('TIMED') ||
      (!isFinalizado && !isAoVivo && !isCancelado && !isAdiado);

  /// Partidas elegíveis para novo desafio (RN-MAT-003, RN-MAT-004):
  /// - Exclui partidas finalizadas, canceladas e adiadas.
  /// - Se [startsAtUtc] estiver preenchido, exige início com mais de 5 minutos de antecedência.
  bool get podeCriarDesafio {
    if (isFinalizado || isCancelado || isAdiado) return false;
    if (startsAtUtc != null && isAgendado) {
      final limite = startsAtUtc!.toUtc().subtract(const Duration(minutes: 5));
      if (DateTime.now().toUtc().isAfter(limite)) {
        return false;
      }
    }
    return true;
  }

  /// Converte data/hora oficial em UTC para o fuso horário local do dispositivo EXCLUSIVAMENTE na exibição (RN-MAT-005).
  static String formatarHorarioExibicao(DateTime? utcDate, [DateTime? localNow]) {
    if (utcDate == null) return "A definir";
    final local = utcDate.toLocal();
    final now = localNow ?? DateTime.now();
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    final amanha = DateTime(now.year, now.month, now.day + 1);

    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return 'Hoje $hora:$minuto';
    } else if (local.year == amanha.year &&
        local.month == amanha.month &&
        local.day == amanha.day) {
      return 'Amanhã $hora:$minuto';
    } else {
      final dia = local.day.toString().padLeft(2, '0');
      final mes = local.month.toString().padLeft(2, '0');
      return '$dia/$mes $hora:$minuto';
    }
  }

  /// Mapeia qualquer status do provedor para o status legível de domínio em português (RN-MAT-002, nunca exibe enum bruto).
  static String mapearStatusDominio(String? rawStatus) {
    if (rawStatus == null || rawStatus.isEmpty) return 'PRÓXIMO JOGO';
    final upper = rawStatus.toUpperCase();
    switch (upper) {
      case 'AGENDADA':
      case 'AGENDADO':
      case 'SCHEDULED':
      case 'TIMED':
      case 'PRÓXIMO JOGO':
      case 'PROXIMO JOGO':
        return 'PRÓXIMO JOGO';
      case 'EM_ANDAMENTO':
      case 'IN_PLAY':
      case 'PAUSED':
      case 'LIVE':
      case 'AO VIVO':
      case 'EM ANDAMENTO':
        return 'EM ANDAMENTO';
      case 'FINALIZADA':
      case 'FINALIZADO':
      case 'FINISHED':
        return 'FINALIZADO';
      case 'ADIADA':
      case 'ADIADO':
      case 'POSTPONED':
        return 'ADIADO';
      case 'CANCELADA':
      case 'CANCELADO':
      case 'CANCELLED':
        return 'CANCELADO';
      case 'SUSPENSA':
      case 'SUSPENSO':
      case 'SUSPENDED':
        return 'SUSPENSO';
      case 'REVISAO_NECESSARIA':
      case 'AWARDED':
      case 'REVISÃO NECESSÁRIA':
        return 'REVISÃO NECESSÁRIA';
      default:
        return upper;
    }
  }

  /// Converte um documento da coleção `matches` do Firestore para [PartidaModel] (KAN-42; docs/firestore-schema.md §3.4).
  factory PartidaModel.fromFirestoreMap(Map<String, dynamic> data, String id) {
    // 1. Tratamento de data/hora oficial (preservado em UTC)
    DateTime? startsAtUtc;
    final rawStartsAt = data['startsAtUtc'] ?? data['utcDate'];
    if (rawStartsAt is Timestamp) {
      startsAtUtc = rawStartsAt.toDate().toUtc();
    } else if (rawStartsAt is DateTime) {
      startsAtUtc = rawStartsAt.toUtc();
    } else if (rawStartsAt is String) {
      startsAtUtc = DateTime.tryParse(rawStartsAt)?.toUtc();
    }

    // Marca de sincronização
    DateTime? syncedAt;
    final rawSynced = data['syncedAt'];
    if (rawSynced is Timestamp) {
      syncedAt = rawSynced.toDate().toUtc();
    } else if (rawSynced is DateTime) {
      syncedAt = rawSynced.toUtc();
    } else if (rawSynced is String) {
      syncedAt = DateTime.tryParse(rawSynced)?.toUtc();
    }

    // 2. Horário de exibição formatado no fuso local do dispositivo (RN-MAT-005)
    final horarioFormatado = startsAtUtc != null
        ? formatarHorarioExibicao(startsAtUtc)
        : (data['horario']?.toString() ?? 'A definir');

    // 3. Status amigável de domínio em português (RN-MAT-002, RNF-013)
    final rawStatus = data['status']?.toString();
    final statusDominio = StatusPartida.deCodigo(rawStatus);
    final statusAmigavel = mapearStatusDominio(rawStatus);

    // 4. Identificação dos times
    final homeTeam = data['homeTeam'];
    final awayTeam = data['awayTeam'];
    final mandante = homeTeam is Map
        ? (homeTeam['shortName'] ?? homeTeam['name'] ?? 'Mandante')
        : (data['timeMandante'] ?? 'Mandante');
    final visitante = awayTeam is Map
        ? (awayTeam['shortName'] ?? awayTeam['name'] ?? 'Visitante')
        : (data['timeVisitante'] ?? 'Visitante');

    // 5. Placar
    int? homeGoals;
    int? awayGoals;
    final score = data['score'];
    if (score is Map && score['fullTime'] is Map) {
      homeGoals = (score['fullTime']['home'] as num?)?.toInt();
      awayGoals = (score['fullTime']['away'] as num?)?.toInt();
    } else {
      homeGoals = (data['homeScore'] as num?)?.toInt() ??
          (data['golsMandante'] as num?)?.toInt();
      awayGoals = (data['awayScore'] as num?)?.toInt() ??
          (data['golsVisitante'] as num?)?.toInt();
    }

    // 6. Resultado do domínio (KAN-43; docs/firestore-schema.md §3.4)
    final rawResult = data['result'] ?? data['resultado'];
    var resultado = ResultadoPartida.deCodigo(rawResult);
    if (resultado == null && statusDominio == StatusPartida.finalizada) {
      if (homeGoals != null && awayGoals != null) {
        if (homeGoals > awayGoals) {
          resultado = ResultadoPartida.homeWin;
        } else if (homeGoals < awayGoals) {
          resultado = ResultadoPartida.awayWin;
        } else {
          resultado = ResultadoPartida.draw;
        }
      }
    }

    return PartidaModel(
      id: id.isNotEmpty ? id : (data['id']?.toString() ?? ''),
      timeMandante: mandante.toString(),
      timeVisitante: visitante.toString(),
      golsMandante: homeGoals,
      golsVisitante: awayGoals,
      status: statusAmigavel,
      statusDominio: statusDominio,
      resultado: resultado,
      campeonato: data['competitionCode']?.toString() ??
          data['competition']?['name']?.toString() ??
          data['campeonato']?.toString() ??
          'Brasileirão Série A',
      horario: horarioFormatado,
      startsAtUtc: startsAtUtc,
      syncedAt: syncedAt,
      matchday: (data['matchday'] as num?)?.toInt(),
      competitionCode: data['competitionCode']?.toString() ?? 'BSA',
      season: (data['season'] as num?)?.toInt() ?? 2026,
      minuto: data['minuto']?.toString(),
      logoMandante: homeTeam is Map ? homeTeam['crest']?.toString() : data['logoMandante']?.toString(),
      logoVisitante: awayTeam is Map ? awayTeam['crest']?.toString() : data['logoVisitante']?.toString(),
    );
  }

  /// Converte JSON para [PartidaModel], delegando para [fromFirestoreMap].
  factory PartidaModel.fromJson(Map<String, dynamic> json) {
    return PartidaModel.fromFirestoreMap(json, json['id']?.toString() ?? '');
  }

  /// Texto do placar formatado (ex: "2 - 0" ou "0 - 0")
  String get placarTexto {
    if (golsMandante != null && golsVisitante != null) {
      return '$golsMandante - $golsVisitante';
    }
    return '0 - 0';
  }

  /// Descrição legível e normalizada do resultado da partida (ex: "Vitória do Mandante (Flamengo)").
  String? get resultadoNormalizadoDescricao {
    if (resultado == null) return null;
    switch (resultado!) {
      case ResultadoPartida.homeWin:
        return 'Vitória do Mandante ($timeMandante)';
      case ResultadoPartida.awayWin:
        return 'Vitória do Visitante ($timeVisitante)';
      case ResultadoPartida.draw:
        return 'Empate';
    }
  }

  /// Data e hora exibida no fuso horário do dispositivo (RN-MAT-005, RF-008).
  String get dataHoraLocalFormatada {
    if (startsAtUtc == null) return horario ?? 'A definir';
    final local = startsAtUtc!.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    final ano = local.year.toString();
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$ano às $hora:$minuto';
  }

  /// Converte a instância para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timeMandante': timeMandante,
      'timeVisitante': timeVisitante,
      'golsMandante': golsMandante,
      'golsVisitante': golsVisitante,
      'status': status,
      'statusDominio': statusDominio.codigo,
      'resultado': resultado?.codigo,
      'campeonato': campeonato,
      'horario': horario,
      'minuto': minuto,
      'logoMandante': logoMandante,
      'logoVisitante': logoVisitante,
      'startsAtUtc': startsAtUtc?.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'matchday': matchday,
      'competitionCode': competitionCode,
      'season': season,
    };
  }
}
