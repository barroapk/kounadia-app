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
    );
  }
}
