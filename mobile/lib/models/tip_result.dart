class TipResult {
  final DateTime date;
  final String league;
  final String home;
  final String away;
  final String tipFr;
  final String score;
  final bool won;
  final String source;

  TipResult({
    required this.date,
    required this.league,
    required this.home,
    required this.away,
    required this.tipFr,
    required this.score,
    required this.won,
    required this.source,
  });

  factory TipResult.fromJson(Map<String, dynamic> j, String source) => TipResult(
        date: DateTime.parse(j['date'].toString()).toLocal(),
        league: (j['leagueName'] ?? j['league'] ?? '').toString(),
        home: j['home']?.toString() ?? '',
        away: j['away']?.toString() ?? '',
        tipFr: j['tipFr']?.toString() ?? '',
        score: j['score']?.toString() ?? '',
        won: j['won'] == true,
        source: source,
      );
}
