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
  final int? totalMatches;
  final int? team1Wins;
  final int? team2Wins;
  final int? draws;

  HeadToHead({
    required this.available,
    this.totalMatches,
    this.team1Wins,
    this.team2Wins,
    this.draws,
  });

  factory HeadToHead.fromJson(Map<String, dynamic> json) {
    if (json['available'] == false) {
      return HeadToHead(available: false);
    }
    return HeadToHead(
      available: true,
      totalMatches: json['totalMatches'] as int? ?? 0,
      team1Wins: json['team1Wins'] as int? ?? 0,
      team2Wins: json['team2Wins'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
    );
  }
}

class MatchAnalysis {
  final int matchId;
  final String homeTeam;
  final String awayTeam;
  final TeamForm home;
  final TeamForm away;
  final HeadToHead headToHead;

  MatchAnalysis({
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.home,
    required this.away,
    required this.headToHead,
  });

  factory MatchAnalysis.fromJson(Map<String, dynamic> json) {
    return MatchAnalysis(
      matchId: json['matchId'] as int,
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      home: TeamForm.fromJson(json['home'] as Map<String, dynamic>),
      away: TeamForm.fromJson(json['away'] as Map<String, dynamic>),
      headToHead: HeadToHead.fromJson(
        json['headToHead'] as Map<String, dynamic>? ?? {'available': false},
      ),
    );
  }
}
