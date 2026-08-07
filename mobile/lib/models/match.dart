class Match {
  final int id;
  final String competition;
  final String? competitionCode;
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final int? minute;
  final String utcDate;
  final String? liveMinuteLabel;
  final String? continent;
  final String? country;
  final String? homeTeamCrest;
  final String? awayTeamCrest;
  final String? competitionEmblem;
  final String provider;
  final String? wonAfter;
  final int? penaltyHomeScore;
  final int? penaltyAwayScore;

  Match({
    required this.id,
    required this.competition,
    this.competitionCode,
    required this.homeTeam,
    required this.awayTeam,
    this.homeScore,
    this.awayScore,
    required this.status,
    this.minute,
    required this.utcDate,
    this.liveMinuteLabel,
    this.continent,
    this.country,
    this.homeTeamCrest,
    this.awayTeamCrest,
    this.competitionEmblem,
    this.provider = 'football-data',
    this.wonAfter,
    this.penaltyHomeScore,
    this.penaltyAwayScore,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as int,
      competition: json['competition'] as String? ?? '',
      competitionCode: json['competitionCode'] as String?,
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      homeScore: json['homeScore'] as int?,
      awayScore: json['awayScore'] as int?,
      status: json['status'] as String? ?? '',
      minute: json['minute'] as int?,
      utcDate: json['utcDate'] as String? ?? '',
      liveMinuteLabel: json['liveMinuteLabel'] as String?,
      continent: json['continent'] as String?,
      country: json['country'] as String?,
      homeTeamCrest: json['homeTeamCrest'] as String?,
      awayTeamCrest: json['awayTeamCrest'] as String?,
      competitionEmblem: json['competitionEmblem'] as String?,
      provider: json['provider'] as String? ?? 'football-data',
      wonAfter: json['wonAfter'] as String?,
      penaltyHomeScore: json['penaltyHomeScore'] as int?,
      penaltyAwayScore: json['penaltyAwayScore'] as int?,
    );
  }
}
