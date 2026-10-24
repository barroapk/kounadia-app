import '../config/store.dart';

class LiveMatch {
  final int id;
  final String url;
  final DateTime? date;
  final String country;
  final String league;
  final String flag;
  final String home;
  final String away;
  final List<int>? probs;
  final List<double>? odds;
  final String tip;
  final double? tipOdd;
  String tipStatus;
  String status;
  String? minute;
  int? hs;
  int? as_;

  LiveMatch({
    required this.id,
    required this.url,
    required this.date,
    required this.country,
    required this.league,
    required this.flag,
    required this.home,
    required this.away,
    required this.probs,
    required this.odds,
    required this.tip,
    required this.tipOdd,
    required this.tipStatus,
    required this.status,
    required this.minute,
    required this.hs,
    required this.as_,
  });

  factory LiveMatch.fromJson(Map<String, dynamic> j) {
    final score = j['score'] as Map<String, dynamic>?;
    return LiveMatch(
      id: (j['id'] as num).toInt(),
      url: j['url']?.toString() ?? '',
      date: DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal(),
      country: j['country']?.toString() ?? '',
      league: j['league']?.toString() ?? '',
      flag: j['flag']?.toString() ?? '',
      home: j['home']?.toString() ?? '',
      away: j['away']?.toString() ?? '',
      probs: (j['probs'] as List?)?.map((e) => (e as num).toInt()).toList(),
      odds: (j['odds'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      tip: j['tip']?.toString() ?? '',
      tipOdd: (j['tipOdd'] as num?)?.toDouble(),
      tipStatus: j['tipStatus']?.toString() ?? 'pending',
      status: j['status']?.toString() ?? 'upcoming',
      minute: j['minute']?.toString(),
      hs: (score?['h'] as num?)?.toInt(),
      as_: (score?['a'] as num?)?.toInt(),
    );
  }

  String get leagueLabel => country.isEmpty ? league : '$country - $league';

  int? get tipProb {
    final p = probs;
    if (p == null || p.length != 3) return null;
    switch (tip.toUpperCase()) {
      case '1':
        return p[0];
      case 'X':
        return p[1];
      case '2':
        return p[2];
      case '1X':
        return p[0] + p[1];
      case 'X2':
        return p[1] + p[2];
      case '12':
        return p[0] + p[2];
    }
    return null;
  }

  String get tipShort {
    // V2 : le pari s'affiche avec son code (1, X, 2, 1X, X2, 12).
    if (kV2 && const ['1', 'X', '2', '1X', 'X2', '12'].contains(tip.toUpperCase())) return tip.toUpperCase();
    switch (tip.toUpperCase()) {
      case '1':
        return 'Victoire dom.';
      case 'X':
        return 'Match nul';
      case '2':
        return 'Victoire ext.';
      case '1X':
        return 'Dom. ou nul';
      case 'X2':
        return 'Ext. ou nul';
      case '12':
        return 'Pas de nul';
    }
    return tip;
  }
}
