import '../services/user_prefs.dart';
import '../config/store.dart';
import '../l10n/tr.dart';

String fx(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
String _two(int n) => n.toString().padLeft(2, '0');

class CouponCriteria {
  int period; // 0 = aujourd'hui, 1 = demain, 2 = les deux
  double totalMin, totalMax;
  int countMin, countMax;
  double oddMin, oddMax;
  int probMin, probMax;
  bool win, draw, dc, goals, btts;
  /// Catégories KOUNADIA (liste « Créer coupon » du moteur) : buts d'une équipe, mi-temps, corners/fautes/tirs.
  bool team, half, stats;

  CouponCriteria({
    this.period = 0,
    required this.totalMin,
    required this.totalMax,
    required this.countMin,
    required this.countMax,
    required this.oddMin,
    required this.oddMax,
    required this.probMin,
    required this.probMax,
    this.win = true,
    this.draw = false,
    this.dc = true,
    this.goals = true,
    this.btts = true,
    this.team = true,
    this.half = true,
    this.stats = false,
  });

  // Réglages validés par backtest (tools/coupon-lab) : cotes réalistes, peu de matchs par coupon.
  factory CouponCriteria.safe() => CouponCriteria(
      totalMin: 1.5, totalMax: 2.5, countMin: 2, countMax: 3, oddMin: 1.1, oddMax: 1.7, probMin: 70, probMax: 95,
      btts: false);
  factory CouponCriteria.balanced() => CouponCriteria(
      totalMin: 2.5, totalMax: 5, countMin: 2, countMax: 4, oddMin: 1.25, oddMax: 2.2, probMin: 58, probMax: 95);
  factory CouponCriteria.bold() => CouponCriteria(
      totalMin: 6, totalMax: 15, countMin: 3, countMax: 6, oddMin: 1.4, oddMax: 3.2, probMin: 40, probMax: 95,
      draw: true);
}

class Leg {
  final int matchId;
  final String home, away, league, flag, pick;
  final double odd;
  final int prob;
  final DateTime? date;
  String result; // pending, live, won, lost, void
  /// Pari du moteur KOUNADIA (toutes catégories) : identifiant du match, code du pari, libellé.
  final String? v2, mk, txt;
  final int? pt;
  /// Cote estimée par KOUNADIA (mi-temps, corners, « une équipe marque »…) : affichée avec ≈.
  final bool est;
  String? score; // score connu (direct ou final)

  Leg({
    required this.matchId,
    required this.home,
    required this.away,
    required this.league,
    required this.flag,
    required this.pick,
    required this.odd,
    required this.prob,
    required this.date,
    this.result = 'pending',
    this.v2,
    this.mk,
    this.txt,
    this.pt,
    this.est = false,
    this.score,
  });

  String get label {
    if (txt != null && txt!.isNotEmpty) return txt!;
    switch (pick) {
      case '1':
        return 'Victoire $home';
      case 'X':
        return 'Match nul';
      case '2':
        return 'Victoire $away';
      case '1X':
        return '$home ou nul';
      case 'X2':
        return '$away ou nul';
      case '12':
        return 'Pas de match nul';
      case 'BTS':
        return 'Les deux équipes marquent';
      case 'OTS':
        return 'Une équipe ne marque pas';
    }
    final g = RegExp(r'^([OU])(\d)(\d)$').firstMatch(pick);
    if (g != null) return '${g[1] == 'O' ? 'Plus' : 'Moins'} de ${g[2]},${g[3]} buts';
    return pick;
  }

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'home': home,
        'away': away,
        'league': league,
        'flag': flag,
        'pick': pick,
        'odd': odd,
        'prob': prob,
        'date': date?.toIso8601String(),
        'result': result,
        if (v2 != null) 'v2': v2,
        if (mk != null) 'mk': mk,
        if (txt != null) 'txt': txt,
        if (pt != null) 'pt': pt,
        if (est) 'est': true,
        if (score != null) 'score': score,
      };

  factory Leg.fromJson(Map<String, dynamic> j) => Leg(
        matchId: (j['matchId'] as num).toInt(),
        home: (j['home'] ?? '').toString(),
        away: (j['away'] ?? '').toString(),
        league: (j['league'] ?? '').toString(),
        flag: (j['flag'] ?? '').toString(),
        pick: (j['pick'] ?? '').toString(),
        odd: (j['odd'] as num).toDouble(),
        prob: (j['prob'] as num).toInt(),
        date: DateTime.tryParse((j['date'] ?? '').toString()),
        result: (j['result'] ?? 'pending').toString(),
        v2: j['v2']?.toString(),
        mk: j['mk']?.toString(),
        txt: j['txt']?.toString(),
        pt: (j['pt'] as num?)?.toInt(),
        est: j['est'] == true,
        score: j['score']?.toString(),
      );
}

class Coupon {
  final DateTime created;
  final List<Leg> legs;
  Coupon(this.created, this.legs);

  factory Coupon.of(List<Leg> legs) {
    final l = List<Leg>.of(legs)
      ..sort((a, b) => (a.date ?? DateTime(2100)).compareTo(b.date ?? DateTime(2100)));
    return Coupon(DateTime.now(), l);
  }

  double get total => legs.fold(1.0, (v, l) => v * l.odd);
  /// « ≈ » devant la cote totale si une cote est estimée.
  String get x => legs.any((l) => l.est) ? '≈' : '×';
  double get prob => legs.fold(1.0, (v, l) => v * l.prob / 100);
  String get signature => (legs.map((l) => '${l.matchId}:${l.pick}').toList()..sort()).join('|');

  String get status {
    if (legs.any((l) => l.result == 'lost')) return 'lost';
    if (legs.every((l) => l.result == 'won' || l.result == 'void')) return 'won';
    if (legs.any((l) => l.result == 'live' || l.result == 'won')) return 'live';
    return 'pending';
  }

  String pctText() {
    final p = prob * 100;
    return p < 10 ? '${p.toStringAsFixed(1).replaceAll('.', ',')} %' : '${p.round()} %';
  }

  String shareText() {
    final b = StringBuffer('🎟️ Coupon KOUNADIA · ${tr('cote')} $x${fx(total)}\n\n');
    for (var i = 0; i < legs.length; i++) {
      final l = legs[i];
      final d = l.date;
      final t = d == null ? '' : '${_two(d.day)}/${_two(d.month)} ${_two(d.hour)}:${_two(d.minute)} · ';
      b.writeln('${i + 1}. ${l.league}');
      b.writeln('   $t${l.home} – ${l.away}');
      b.writeln('   ➜ ${tr(l.label)} ${l.est ? '≈' : '@'}${fx(l.odd)}');
    }
    b.writeln('\n${tr('Probabilité estimée')} ≈ ${pctText()}');
    if (!kPlay) {
      b.writeln('${tr('📲 Pronostics gratuits sur KOUNADIA')} : https://kounadia.pages.dev');
      b.writeln('🎁 ${tr('Code promo 1xBet')} : 99KND');
    }
    if (!kPlay && UserPrefs.iso == 'BF') b.writeln('💬 ${tr('Dépôt / retrait 1xBet : KOUNADIA SERVICE sur WhatsApp')} +226 52 57 12 01');
    b.write(tr('18+ · Jouez de manière responsable.'));
    return b.toString();
  }

  Map<String, dynamic> toJson() =>
      {'created': created.toIso8601String(), 'legs': legs.map((l) => l.toJson()).toList()};

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        DateTime.tryParse((j['created'] ?? '').toString()) ?? DateTime.now(),
        ((j['legs'] as List?) ?? [])
            .map((e) => Leg.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
