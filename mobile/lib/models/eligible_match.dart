class EligibleMatch {
  final int matchId;
  final String competition;
  final String homeTeam;
  final String awayTeam;
  final int homeElo;
  final int awayElo;
  final String favoredSide;
  final String note;

  EligibleMatch({
    required this.matchId,
    required this.competition,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeElo,
    required this.awayElo,
    required this.favoredSide,
    required this.note,
  });

  factory EligibleMatch.fromJson(Map<String, dynamic> json) {
    return EligibleMatch(
      matchId: json['matchId'] as int,
      competition: json['competition'] as String? ?? '',
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      homeElo: json['homeElo'] as int? ?? 1500,
      awayElo: json['awayElo'] as int? ?? 1500,
      favoredSide: json['favoredSide'] as String? ?? 'balanced',
      note: json['note'] as String? ?? '',
    );
  }
}
