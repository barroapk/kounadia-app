class StandingRow {
  final int position;
  final String? group;
  final String teamName;
  final String? teamCrest;
  final int playedGames;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;

  StandingRow({
    required this.position,
    this.group,
    required this.teamName,
    this.teamCrest,
    required this.playedGames,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  factory StandingRow.fromJson(Map<String, dynamic> json) {
    return StandingRow(
      position: json['position'] as int,
      group: json['group'] as String?,
      teamName: json['teamName'] as String? ?? '',
      teamCrest: json['teamCrest'] as String?,
      playedGames: json['playedGames'] as int? ?? 0,
      won: json['won'] as int? ?? 0,
      draw: json['draw'] as int? ?? 0,
      lost: json['lost'] as int? ?? 0,
      goalsFor: json['goalsFor'] as int? ?? 0,
      goalsAgainst: json['goalsAgainst'] as int? ?? 0,
      goalDifference: json['goalDifference'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
    );
  }
}

class SeasonInfo {
  final String startYear;
  final String label;

  SeasonInfo({required this.startYear, required this.label});

  factory SeasonInfo.fromJson(Map<String, dynamic> json) {
    return SeasonInfo(
      startYear: json['startYear'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class StandingsResponse {
  final String competitionCode;
  final String competitionName;
  final String? competitionEmblem;
  final String? season;
  final List<SeasonInfo> availableSeasons;
  final int totalTeams;
  final List<StandingRow> standings;

  StandingsResponse({
    required this.competitionCode,
    required this.competitionName,
    this.competitionEmblem,
    this.season,
    required this.availableSeasons,
    required this.totalTeams,
    required this.standings,
  });

  factory StandingsResponse.fromJson(Map<String, dynamic> json) {
    return StandingsResponse(
      competitionCode: json['competitionCode'] as String? ?? '',
      competitionName: json['competitionName'] as String? ?? '',
      competitionEmblem: json['competitionEmblem'] as String?,
      season: json['season'] as String?,
      availableSeasons: (json['availableSeasons'] as List<dynamic>? ?? [])
          .map((e) => SeasonInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalTeams: json['totalTeams'] as int? ?? 0,
      standings: (json['standings'] as List<dynamic>)
          .map((e) => StandingRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
