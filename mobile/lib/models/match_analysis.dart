class TeamForm {
  final int matchesAnalyzed;
  final int wins;
  final int draws;
  final int losses;
  final int points;
  final int maxPoints;
  final double formPercent;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final double avgGoalsFor;
  final double avgGoalsAgainst;
  final int cleanSheets;
  final int failedToScore;

  TeamForm({
    required this.matchesAnalyzed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.points,
    required this.maxPoints,
    required this.formPercent,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.avgGoalsFor,
    required this.avgGoalsAgainst,
    required this.cleanSheets,
    required this.failedToScore,
  });

  factory TeamForm.fromJson(Map<String, dynamic> json) {
    return TeamForm(
      matchesAnalyzed: json['matchesAnalyzed'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
      maxPoints: json['maxPoints'] as int? ?? 0,
      formPercent: (json['formPercent'] as num?)?.toDouble() ?? 0,
      goalsFor: json['goalsFor'] as int? ?? 0,
      goalsAgainst: json['goalsAgainst'] as int? ?? 0,
      goalDifference: json['goalDifference'] as int? ?? 0,
      avgGoalsFor: (json['avgGoalsFor'] as num?)?.toDouble() ?? 0,
      avgGoalsAgainst: (json['avgGoalsAgainst'] as num?)?.toDouble() ?? 0,
      cleanSheets: json['cleanSheets'] as int? ?? 0,
      failedToScore: json['failedToScore'] as int? ?? 0,
    );
  }
}

class HeadToHead {
  final bool available;
  final String? teamA;
  final String? teamB;
  final int? totalMatches;
  final int? teamAWins;
  final int? teamBWins;
  final int? draws;

  HeadToHead({
    required this.available,
    this.teamA,
    this.teamB,
    this.totalMatches,
    this.teamAWins,
    this.teamBWins,
    this.draws,
  });

  factory HeadToHead.fromJson(Map<String, dynamic> json) {
    if (json['available'] == false) {
      return HeadToHead(available: false);
    }
    return HeadToHead(
      available: true,
      teamA: json['teamA'] as String?,
      teamB: json['teamB'] as String?,
      totalMatches: json['totalMatches'] as int? ?? 0,
      teamAWins: json['teamAWins'] as int? ?? 0,
      teamBWins: json['teamBWins'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
    );
  }
}

class MatchStatistics {
  final Map<String, dynamic> home;
  final Map<String, dynamic> away;

  MatchStatistics({required this.home, required this.away});

  factory MatchStatistics.fromJson(Map<String, dynamic> json) {
    return MatchStatistics(
      home: Map<String, dynamic>.from(json['home'] as Map? ?? {}),
      away: Map<String, dynamic>.from(json['away'] as Map? ?? {}),
    );
  }
}

class LineupPlayer {
  final String? name;
  final int? number;
  final String? position;

  LineupPlayer({this.name, this.number, this.position});

  factory LineupPlayer.fromJson(Map<String, dynamic> json) {
    return LineupPlayer(
      name: json['name'] as String?,
      number: json['number'] as int?,
      position: json['position'] as String?,
    );
  }
}

class LineupEntry {
  final String? team;
  final String? formation;
  final String? coach;
  final List<LineupPlayer> startXI;
  final List<LineupPlayer> substitutes;

  LineupEntry({
    this.team,
    this.formation,
    this.coach,
    required this.startXI,
    required this.substitutes,
  });

  factory LineupEntry.fromJson(Map<String, dynamic> json) {
    return LineupEntry(
      team: json['team'] as String?,
      formation: json['formation'] as String?,
      coach: json['coach'] as String?,
      startXI: (json['startXI'] as List<dynamic>? ?? [])
          .map((e) => LineupPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      substitutes: (json['substitutes'] as List<dynamic>? ?? [])
          .map((e) => LineupPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MatchEvent {
  final int? minute;
  final int? extraMinute;
  final String? type;
  final String? detail;
  final String? team;
  final String? player;
  final String? assist;

  MatchEvent({
    this.minute,
    this.extraMinute,
    this.type,
    this.detail,
    this.team,
    this.player,
    this.assist,
  });

  factory MatchEvent.fromJson(Map<String, dynamic> json) {
    return MatchEvent(
      minute: json['minute'] as int?,
      extraMinute: json['extraMinute'] as int?,
      type: json['type'] as String?,
      detail: json['detail'] as String?,
      team: json['team'] as String?,
      player: json['player'] as String?,
      assist: json['assist'] as String?,
    );
  }
}

class MatchAnalysis {
  final int matchId;
  final String homeTeam;
  final String awayTeam;
  final String? competition;
  final int? homeScore;
  final int? awayScore;
  final String? utcDate;
  final String? status;
  final String? venue;
  final String? referee;
  final String? wonAfter;
  final TeamForm home;
  final TeamForm away;
  final HeadToHead headToHead;
  final MatchStatistics? statistics;
  final List<LineupEntry>? lineups;
  final List<MatchEvent>? events;

  MatchAnalysis({
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    this.competition,
    this.homeScore,
    this.awayScore,
    this.utcDate,
    this.status,
    this.venue,
    this.referee,
    this.wonAfter,
    required this.home,
    required this.away,
    required this.headToHead,
    this.statistics,
    this.lineups,
    this.events,
  });

  factory MatchAnalysis.fromJson(Map<String, dynamic> json) {
    return MatchAnalysis(
      matchId: json['matchId'] as int,
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      competition: json['competition'] as String?,
      homeScore: json['homeScore'] as int?,
      awayScore: json['awayScore'] as int?,
      utcDate: json['utcDate'] as String?,
      status: json['status'] as String?,
      venue: json['venue'] as String?,
      referee: json['referee'] as String?,
      wonAfter: json['wonAfter'] as String?,
      home: TeamForm.fromJson(json['home'] as Map<String, dynamic>),
      away: TeamForm.fromJson(json['away'] as Map<String, dynamic>),
      headToHead: HeadToHead.fromJson(
        json['headToHead'] as Map<String, dynamic>? ?? {'available': false},
      ),
      statistics: json['statistics'] != null
          ? MatchStatistics.fromJson(json['statistics'] as Map<String, dynamic>)
          : null,
      lineups: json['lineups'] != null
          ? (json['lineups'] as List<dynamic>)
              .map((e) => LineupEntry.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      events: json['events'] != null
          ? (json['events'] as List<dynamic>)
              .map((e) => MatchEvent.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }
}
