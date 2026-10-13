class Tip {
  final DateTime date;
  final String league;
  final String home;
  final String away;
  final double pHome;
  final double pDraw;
  final double pAway;
  final String pick;
  final String label;
  final double prob;

  Tip({
    required this.date,
    required this.league,
    required this.home,
    required this.away,
    required this.pHome,
    required this.pDraw,
    required this.pAway,
    required this.pick,
    required this.label,
    required this.prob,
  });

  factory Tip.fromJson(Map<String, dynamic> j) => Tip(
        date: DateTime.parse(j['date']).toLocal(),
        league: j['league'],
        home: j['home'],
        away: j['away'],
        pHome: (j['pHome'] as num).toDouble(),
        pDraw: (j['pDraw'] as num).toDouble(),
        pAway: (j['pAway'] as num).toDouble(),
        pick: j['pick'],
        label: j['label'] ?? '',
        prob: (j['prob'] as num).toDouble(),
      );
}
