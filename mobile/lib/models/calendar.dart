import "match.dart";

class MatchdaySummary {
  final int totalMatches;
  final int finished;
  final int live;
  final int scheduled;

  MatchdaySummary({
    required this.totalMatches,
    required this.finished,
    required this.live,
    required this.scheduled,
  });

  factory MatchdaySummary.fromJson(Map<String, dynamic> json) {
    return MatchdaySummary(
      totalMatches: json['totalMatches'] as int? ?? 0,
      finished: json['finished'] as int? ?? 0,
      live: json['live'] as int? ?? 0,
      scheduled: json['scheduled'] as int? ?? 0,
    );
  }
}

class MatchdayGroup {
  final int matchday;
  final List<Match> matches;
  final bool allFinished;
  final MatchdaySummary summary;

  MatchdayGroup({
    required this.matchday,
    required this.matches,
    required this.allFinished,
    required this.summary,
  });

  factory MatchdayGroup.fromJson(Map<String, dynamic> json) {
    return MatchdayGroup(
      matchday: json['matchday'] as int,
      matches: (json['matches'] as List<dynamic>)
          .map((e) => Match.fromJson(e as Map<String, dynamic>))
          .toList(),
      allFinished: json['allFinished'] as bool? ?? false,
      summary: MatchdaySummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}

class CalendarResponse {
  final String competitionCode;
  final int currentMatchday;
  final int totalMatchdays;
  final List<MatchdayGroup> matchdays;

  CalendarResponse({
    required this.competitionCode,
    required this.currentMatchday,
    required this.totalMatchdays,
    required this.matchdays,
  });

  factory CalendarResponse.fromJson(Map<String, dynamic> json) {
    return CalendarResponse(
      competitionCode: json['competitionCode'] as String? ?? '',
      currentMatchday: json['currentMatchday'] as int? ?? 1,
      totalMatchdays: json['totalMatchdays'] as int? ?? 0,
      matchdays: (json['matchdays'] as List<dynamic>)
          .map((e) => MatchdayGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
