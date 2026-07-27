class Match {
  final int id;
  final String competition;
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

  Match({
    required this.id,
    required this.competition,
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
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as int,
      competition: json['competition'] as String? ?? '',
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
    );
  }
}
