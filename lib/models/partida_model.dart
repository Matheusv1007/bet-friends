class PartidaModel {
  final String id;
  final String timeMandante;
  final String timeVisitante;
  final int? golsMandante;
  final int? golsVisitante;
  final String status;
  final String? campeonato;
  final String? horario;
  final String? logoMandante;
  final String? logoVisitante;

  PartidaModel({
    required this.id,
    required this.timeMandante,
    required this.timeVisitante,
    this.golsMandante,
    this.golsVisitante,
    this.status = 'AGENDADO',
    this.campeonato,
    this.horario,
    this.logoMandante,
    this.logoVisitante,
  });

  /// Converte o JSON retornado pela API Football-Data para uma instância de PartidaModel
  factory PartidaModel.fromJson(Map<String, dynamic> json) {
    // Tratamento de data/hora UTC para o fuso horário local do dispositivo
    String? horarioFormatado;
    final utcDateStr = json['utcDate'] ?? json['horario'];
    if (utcDateStr != null) {
      try {
        final localDate = DateTime.parse(utcDateStr.toString()).toLocal();
        final hora = localDate.hour.toString().padLeft(2, '0');
        final minuto = localDate.minute.toString().padLeft(2, '0');
        horarioFormatado = '$hora:$minuto';
      } catch (_) {
        horarioFormatado = utcDateStr.toString();
      }
    }

    // Tratamento de status amigável
    final rawStatus = json['status']?.toString().toUpperCase() ?? 'SCHEDULED';
    String statusAmigavel;
    switch (rawStatus) {
      case 'FINISHED':
        statusAmigavel = 'FINALIZADO';
        break;
      case 'IN_PLAY':
        statusAmigavel = 'AO VIVO';
        break;
      case 'PAUSED':
        statusAmigavel = 'INTERVALO';
        break;
      case 'TIMED':
      case 'SCHEDULED':
        statusAmigavel = horarioFormatado ?? 'AGENDADO';
        break;
      case 'POSTPONED':
        statusAmigavel = 'ADIADO';
        break;
      case 'CANCELLED':
        statusAmigavel = 'CANCELADO';
        break;
      default:
        statusAmigavel = rawStatus;
    }

    // Nomes dos times (prioriza shortName para caber melhor na tela de celular)
    final homeTeam = json['homeTeam'];
    final awayTeam = json['awayTeam'];
    final mandante = homeTeam is Map
        ? (homeTeam['shortName'] ?? homeTeam['name'] ?? 'Mandante')
        : (json['timeMandante'] ?? 'Mandante');
    final visitante = awayTeam is Map
        ? (awayTeam['shortName'] ?? awayTeam['name'] ?? 'Visitante')
        : (json['timeVisitante'] ?? 'Visitante');

    // Placar
    int? homeGoals;
    int? awayGoals;
    final score = json['score'];
    if (score is Map && score['fullTime'] is Map) {
      homeGoals = score['fullTime']['home'];
      awayGoals = score['fullTime']['away'];
    } else {
      homeGoals = json['golsMandante'];
      awayGoals = json['golsVisitante'];
    }

    return PartidaModel(
      id: json['id']?.toString() ?? '',
      timeMandante: mandante.toString(),
      timeVisitante: visitante.toString(),
      golsMandante: homeGoals,
      golsVisitante: awayGoals,
      status: statusAmigavel,
      campeonato: json['competition']?['name'] ?? json['campeonato'],
      horario: horarioFormatado,
      logoMandante: homeTeam is Map ? homeTeam['crest'] : json['logoMandante'],
      logoVisitante: awayTeam is Map ? awayTeam['crest'] : json['logoVisitante'],
    );
  }

  /// Texto do placar formatado (ex: "2 - 0" ou "vs" se ainda não começou)
  String get placarTexto {
    if (golsMandante != null && golsVisitante != null) {
      return '$golsMandante - $golsVisitante';
    }
    return 'vs';
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
      'campeonato': campeonato,
      'horario': horario,
      'logoMandante': logoMandante,
      'logoVisitante': logoVisitante,
    };
  }
}
