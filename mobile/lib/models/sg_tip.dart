class SgTip {
  final DateTime date;
  final String leagueName;
  final String home;
  final String away;
  final String pick;
  final String pickTeam;
  final String score;
  final int agree;
  final int models;

  SgTip({
    required this.date,
    required this.leagueName,
    required this.home,
    required this.away,
    required this.pick,
    required this.pickTeam,
    required this.score,
    required this.agree,
    required this.models,
  });

  factory SgTip.fromJson(Map<String, dynamic> j) => SgTip(
        date: DateTime.parse(j['date'].toString()).toLocal(),
        leagueName: j['leagueName']?.toString() ?? '',
        home: j['home']?.toString() ?? '',
        away: j['away']?.toString() ?? '',
        pick: j['pick']?.toString() ?? '',
        pickTeam: j['pickTeam']?.toString() ?? '',
        score: j['score']?.toString() ?? '',
        agree: (j['agree'] as num?)?.toInt() ?? 0,
        models: (j['models'] as num?)?.toInt() ?? 0,
      );

  String get labelFr =>
      pick == 'draw' ? 'Match nul' : 'Victoire $pickTeam';
}
