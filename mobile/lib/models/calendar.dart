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
  final String? roundLabel;
  final List<Match> matches;
  final bool allFinished;
  final MatchdaySummary summary;

  MatchdayGroup({
    required this.matchday,
    this.roundLabel,
    required this.matches,
    required this.allFinished,
    required this.summary,
  });

  factory MatchdayGroup.fromJson(Map<String, dynamic> json) {
    return MatchdayGroup(
      matchday: json['matchday'] as int,
      roundLabel: json['roundLabel'] as String?,
      matches: (json['matches'] as List<dynamic>)
          .map((e) => Match.fromJson(e as Map<String, dynamic>))
          .toList(),
      allFinished: json['allFinished'] as bool? ?? false,
      summary: MatchdaySummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }

  /// Libellé à afficher : le vrai round (coupes) si disponible, sinon "J{n}".
  String get displayLabel => roundLabel ?? "J$matchday";

  // Libellé court pour les puces compactes du sélecteur de journée.
  // Les journées classiques ("Apertura - 5") restent inchangées : seules
  // les phases à élimination directe connues sont raccourcies.
  static const Map<String, String> _shortLabels = {
    "round of 32": "1/16",
    "round of 16": "1/8",
    "quarter-finals": "1/4",
    "semi-finals": "1/2",
    "3rd place": "3e",
    "third place": "3e",
    "final": "Finale",
  };

  String get shortDisplayLabel {
    final label = roundLabel;
    if (label == null) return "J$matchday";

    final normalized = label.toLowerCase();
    for (final entry in _shortLabels.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return label;
  }
}

class CalendarSeasonInfo {
  final String value;
  final String label;

  CalendarSeasonInfo({required this.value, required this.label});

  factory CalendarSeasonInfo.fromJson(Map<String, dynamic> json) {
    return CalendarSeasonInfo(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class CalendarResponse {
  final String competitionCode;
  final String? season;
  final List<CalendarSeasonInfo> availableSeasons;
  final int currentMatchday;
  final String? currentRoundLabel;
  final int totalMatchdays;
  final List<MatchdayGroup> matchdays;

  CalendarResponse({
    required this.competitionCode,
    this.season,
    this.availableSeasons = const [],
    required this.currentMatchday,
    this.currentRoundLabel,
    required this.totalMatchdays,
    required this.matchdays,
  });

  factory CalendarResponse.fromJson(Map<String, dynamic> json) {
    return CalendarResponse(
      competitionCode: json['competitionCode'] as String? ?? '',
      season: json['season'] as String?,
      availableSeasons: (json['availableSeasons'] as List<dynamic>? ?? [])
          .map((e) => CalendarSeasonInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentMatchday: json['currentMatchday'] as int? ?? 1,
      currentRoundLabel: json['currentRoundLabel'] as String?,
      totalMatchdays: json['totalMatchdays'] as int? ?? 0,
      matchdays: (json['matchdays'] as List<dynamic>)
          .map((e) => MatchdayGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
