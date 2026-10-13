class NerdyTip {
  final DateTime date;
  final String league;
  final String home;
  final String away;
  final String tip;
  final String tipFr;
  final double? confidence;

  const NerdyTip({
    required this.date,
    required this.league,
    required this.home,
    required this.away,
    required this.tip,
    required this.tipFr,
    required this.confidence,
  });

  factory NerdyTip.fromJson(Map<String, dynamic> j) => NerdyTip(
        date: DateTime.parse(j['date'].toString()).toLocal(),
        league: j['league']?.toString() ?? '',
        home: j['home']?.toString() ?? '',
        away: j['away']?.toString() ?? '',
        tip: j['tip']?.toString() ?? '',
        tipFr: j['tipFr']?.toString() ?? '',
        confidence: (j['confidence'] as num?)?.toDouble(),
      );
}
