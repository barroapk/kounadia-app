// KOUNADIA V2 : Coupon du jour, Sélection du jour et historiques (données du moteur V2).
import '../services/primatips_service.dart' show frLeague;

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Un événement (pari) : match + marché + confiance KOUNADIA + cote.
class V2Leg {
  final String id, home, away, country, league, mk, txt, fam;
  final String? hl, al, flag, espnLg, espnId;
  final int? pt; // identifiant PrimaTips (direct)
  final DateTime? date;
  final double p, odd;
  final bool est;
  /// Probabilité PrimaTips (2e avis) et accord des analystes Expert.
  final double? pp;
  final bool ex;
  final List<String> why;
  String? r; // won, lost, void, live, null = à venir
  String? score;
  String? minute; // direct
  /// Statistiques du match [domicile, extérieur] : c corners, f fautes, s tirs, t tirs cadrés.
  Map<String, List<int?>> st;
  List<int>? h1; // score à la mi-temps

  V2Leg.fromJson(Map<String, dynamic> j)
      : id = (j['id'] ?? '').toString(),
        home = (j['home'] ?? '').toString(),
        away = (j['away'] ?? '').toString(),
        country = (j['country'] ?? '').toString(),
        league = frLeague((j['league'] ?? '').toString()),
        mk = (j['mk'] ?? '').toString(),
        txt = (j['txt'] ?? '').toString(),
        fam = (j['fam'] ?? '').toString(),
        date = DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
        p = _d(j['p']),
        odd = _d(j['odd']),
        est = j['est'] == true,
        pp = (j['pp'] as num?)?.toDouble(),
        ex = j['ex'] == true,
        why = ((j['why'] as List?) ?? const []).map((e) => e.toString()).toList(),
        pt = (j['pt'] as num?)?.toInt(),
        hl = _s(j['hl']),
        al = _s(j['al']),
        flag = _s(j['flag']),
        espnLg = _s((j['espn'] as Map?)?['lg']),
        espnId = _s((j['espn'] as Map?)?['id']),
        r = j['r']?.toString(),
        score = j['score']?.toString(),
        st = {
          for (final e in ((j['st'] as Map?) ?? const {}).entries)
            if (e.value is List) e.key.toString(): (e.value as List).map((x) => (x as num?)?.toInt()).toList(),
        },
        h1 = (j['h1'] as List?)?.map((x) => (x as num).toInt()).toList();

  static String? _s(dynamic v) => v == null || v.toString().isEmpty ? null : v.toString();

  /// Pari sur une statistique (corners, fautes, tirs, tirs cadrés) : clé c, f, s ou t.
  String? get statKey => const {'stc': 'c', 'stf': 'f', 'sts': 's', 'stt': 't', 'sty': 'y'}[fam];

  /// Nom de la statistique du pari.
  String? get statName => const {'c': 'Corners', 'f': 'Fautes', 's': 'Tirs', 't': 'Tirs cadrés', 'y': 'Cartons jaunes'}[statKey];

  /// Valeurs [domicile, extérieur] de la statistique du pari, si connues.
  List<int?>? get statPair => statKey == null ? null : st[statKey];

  /// Clé unique (favoris).
  String get key => '$id|$mk';

  /// Championnat affiché : « Pays - Compétition ».
  String get leagueLabel => country.isEmpty || league.toLowerCase().startsWith(country.toLowerCase()) ? league : '$country - $league';

  /// Identifiant PrimaTips (pour le direct), si le match vient de PrimaTips.
  int? get ptId => pt ?? (id.startsWith('pt:') ? int.tryParse(id.substring(3)) : null);

  /// Code court du pari : 1, X2, +2.5…
  String get code {
    final i = txt.indexOf(' · ');
    return i > 0 ? txt.substring(0, i) : '';
  }

  /// Libellé sans le code.
  String get label {
    final i = txt.indexOf(' · ');
    return i > 0 ? txt.substring(i + 3) : txt;
  }
}

/// Un coupon : plusieurs événements sur des matchs différents.
class V2Coupon {
  final double odd, p;
  final List<V2Leg> legs;
  final int n;
  final bool locked;
  String? r;

  V2Coupon.fromJson(Map<String, dynamic> j)
      : odd = _d(j['odd']),
        p = _d(j['p']),
        legs = ((j['legs'] as List?) ?? const [])
            .map((e) => V2Leg.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        n = (j['n'] as num?)?.toInt() ?? ((j['legs'] as List?)?.length ?? 0),
        locked = j['locked'] == true,
        r = j['r']?.toString();

  /// Résultat recalculé à partir des événements (direct compris).
  void refresh() {
    if (legs.isEmpty) return;
    final rs = legs.map((l) => l.r).toList();
    if (rs.contains('lost')) {
      r = 'lost';
    } else if (rs.every((x) => x == 'won' || x == 'void')) {
      r = rs.every((x) => x == 'void') ? 'void' : 'won';
    } else if (rs.contains('live')) {
      r = 'live';
    } else {
      r = null;
    }
  }
}

/// Bilan sur 14 jours d'une catégorie.
class V2Stat {
  final int won, lost;
  final double? pct;
  V2Stat(this.won, this.lost, this.pct);
  int get total => won + lost;
  factory V2Stat.fromJson(Map<String, dynamic>? j) =>
      V2Stat((j?['won'] as num?)?.toInt() ?? 0, (j?['lost'] as num?)?.toInt() ?? 0, (j?['pct'] as num?)?.toDouble());
}

class V2Selection {
  final int n;
  final bool locked;
  final List<V2Leg> top, byFam, fav;
  final Map<String, V2Coupon?> coupons;

  V2Selection.fromJson(Map<String, dynamic> j)
      : n = (j['n'] as num?)?.toInt() ?? 0,
        locked = j['locked'] == true,
        top = _legs(j['top']),
        byFam = _legs(j['byFam']),
        fav = _legs(j['fav']),
        coupons = {
          for (final e in ((j['coupons'] as Map?) ?? const {}).entries)
            e.key.toString(): e.value == null ? null : V2Coupon.fromJson(Map<String, dynamic>.from(e.value as Map)),
        };

  static List<V2Leg> _legs(dynamic v) =>
      ((v as List?) ?? const []).map((e) => V2Leg.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  /// Tous les événements affichés (pour le direct).
  Iterable<V2Leg> get allLegs sync* {
    yield* top;
    yield* byFam;
    yield* fav;
    for (final c in coupons.values) {
      if (c != null) yield* c.legs;
    }
  }
}

/// Une journée : Coupon du jour + Sélection du jour.
/// Un match de la liste « Créer coupon » (tous les bons paris du jour, toutes catégories).
class V2PoolMatch {
  final String id, home, away, country, league;
  final String? flag, hl, al, espnLg, espnId;
  final int? pt;
  final DateTime? date;
  /// (pari, chance %, cote, cote estimée, famille)
  final List<(String, double, double, bool, String)> ev;

  V2PoolMatch.fromJson(Map<String, dynamic> j)
      : id = (j['id'] ?? '').toString(),
        home = (j['home'] ?? '').toString(),
        away = (j['away'] ?? '').toString(),
        country = (j['country'] ?? '').toString(),
        league = frLeague((j['league'] ?? '').toString()),
        flag = j['flag']?.toString(),
        hl = j['hl']?.toString(),
        al = j['al']?.toString(),
        espnLg = (j['espn'] as Map?)?['lg']?.toString(),
        espnId = (j['espn'] as Map?)?['id']?.toString(),
        pt = (j['pt'] as num?)?.toInt(),
        date = DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
        ev = [
          for (final e in ((j['ev'] as List?) ?? const []))
            if (e is List && e.length >= 5)
              ('${e[0]}', (e[1] as num).toDouble(), (e[2] as num).toDouble(), e[3] == 1, '${e[4]}'),
        ];

  String get leagueLabel => country.isEmpty || league.toLowerCase().startsWith(country.toLowerCase()) ? league : '$country - $league';
}

/// Résultat d'un match (score, mi-temps, statistiques) publié par le moteur.
class V2Res {
  final int? hg, ag;
  final List<int>? h1;
  final Map<String, List<int?>> st;
  final bool done, isVoid;
  V2Res.fromJson(Map<String, dynamic> j)
      : hg = (j['hg'] as num?)?.toInt(),
        ag = (j['ag'] as num?)?.toInt(),
        h1 = (j['h1'] as List?)?.map((x) => (x as num).toInt()).toList(),
        st = {
          for (final e in ((j['st'] as Map?) ?? const {}).entries)
            if (e.value is List) e.key.toString(): (e.value as List).map((x) => (x as num?)?.toInt()).toList(),
        },
        done = j['done'] == true,
        isVoid = j['void'] == true;
}

/// Libellé d'un pari (mêmes textes que le moteur).
String v2Label(String mk, String home, String away) {
  const fixed = {
    '12': '12 · Pas de match nul',
    'BTTS oui': 'Les deux équipes marquent : Oui',
    'BTTS non': 'Les deux équipes marquent : Non',
    '+0.5 MT1': 'But en 1re mi-temps',
    '+0.5 MT2': 'But en 2e mi-temps',
    '+1.5 MT2': '2 buts ou plus en 2e mi-temps',
    '-1.5 MT1': 'Moins de 2 buts en 1re mi-temps',
    'But chaque MT': 'But dans chaque mi-temps',
  };
  final f = fixed[mk];
  if (f != null) return f;
  switch (mk) {
    case '1':
      return '1 · Victoire $home';
    case '2':
      return '2 · Victoire $away';
    case '1X':
      return '1X · $home ou nul';
    case 'X2':
      return 'X2 · $away ou nul';
    case 'Dom. marque':
      return '$home marque';
    case 'Ext. marque':
      return '$away marque';
    case 'Dom. +1.5':
      return '$home marque 2 buts ou plus';
    case 'Ext. +1.5':
      return '$away marque 2 buts ou plus';
  }
  final g = RegExp(r'^([+-])(\d)\.5$').firstMatch(mk);
  if (g != null) return '${g[1] == '+' ? 'Plus' : 'Moins'} de ${g[2]},5 buts';
  final s = RegExp(r'^(.+) ([+-])(\d+)\.5$').firstMatch(mk);
  if (s != null) return '${s[2] == '+' ? 'Plus' : 'Moins'} de ${s[3]},5 ${s[1]!.toLowerCase()}';
  return mk;
}

/// Règlement d'un pari avec le résultat complet (mêmes règles que le moteur). null = pas encore connu.
bool? v2Settle(String mk, V2Res r) {
  final hg = r.hg, ag = r.ag;
  if (hg == null || ag == null) return null;
  final t = hg + ag;
  switch (mk) {
    case '1':
      return hg > ag;
    case '2':
      return ag > hg;
    case '1X':
      return hg >= ag;
    case 'X2':
      return ag >= hg;
    case '12':
      return hg != ag;
    case 'BTTS oui':
      return hg > 0 && ag > 0;
    case 'BTTS non':
      return hg == 0 || ag == 0;
    case 'Dom. marque':
      return hg > 0;
    case 'Ext. marque':
      return ag > 0;
    case 'Dom. +1.5':
      return hg > 1;
    case 'Ext. +1.5':
      return ag > 1;
  }
  final g = RegExp(r'^([+-])(\d\.5)$').firstMatch(mk);
  if (g != null) {
    final x = double.parse(g[2]!);
    return g[1] == '+' ? t > x : t < x;
  }
  if (mk.contains('MT')) {
    final h1 = r.h1;
    if (h1 == null || h1.length < 2) return null;
    final a1 = h1[0] + h1[1], a2 = t - a1;
    switch (mk) {
      case '+0.5 MT1':
        return a1 > 0;
      case '+0.5 MT2':
        return a2 > 0;
      case '+1.5 MT2':
        return a2 > 1;
      case '-1.5 MT1':
        return a1 < 2;
      case 'But chaque MT':
        return a1 > 0 && a2 > 0;
    }
    return null;
  }
  final s = RegExp(r'^(.+) ([+-])(\d+\.5)$').firstMatch(mk);
  if (s != null) {
    final k = const {'Corners': 'c', 'Fautes': 'f', 'Tirs': 's', 'Tirs cadrés': 't'}[s[1]];
    final v = k == null ? null : r.st[k];
    if (v == null || v.length < 2 || v[0] == null || v[1] == null) return null;
    final x = double.parse(s[3]!);
    final tot = v[0]! + v[1]!;
    return s[2] == '+' ? tot > x : tot < x;
  }
  return null;
}

class V2Day {
  final String day;
  final int matches;
  final Map<String, V2Coupon?> coupons;
  final V2Selection? selection;
  final List<V2PoolMatch> pool;

  V2Day.fromJson(Map<String, dynamic> j)
      : day = (j['day'] ?? '').toString(),
        matches = (j['matches'] as num?)?.toInt() ?? 0,
        coupons = {
          for (final e in ((j['coupons'] as Map?) ?? const {}).entries)
            e.key.toString(): e.value == null ? null : V2Coupon.fromJson(Map<String, dynamic>.from(e.value as Map)),
        },
        selection = j['selection'] is Map ? V2Selection.fromJson(Map<String, dynamic>.from(j['selection'] as Map)) : null,
        pool = [for (final m in ((j['pool'] as List?) ?? const [])) if (m is Map) V2PoolMatch.fromJson(Map<String, dynamic>.from(m))];

  Iterable<V2Leg> get allLegs sync* {
    for (final c in coupons.values) {
      if (c != null) yield* c.legs;
    }
    if (selection != null) yield* selection!.allLegs;
  }

  DateTime? get date => DateTime.tryParse(day);
}

class V2Data {
  final V2Day? today;
  final List<V2Day> history;
  final Map<String, V2Stat> stats;
  final bool offline, premium;
  final DateTime? updatedAt;
  /// Résultats des matchs d'hier et d'aujourd'hui (coupons créés dans l'app).
  final Map<String, V2Res> res;
  /// Liste « Créer coupon » vivante (aujourd'hui + demain, cotes du moment).
  final List<V2PoolMatch> pool;
  V2Data(this.today, this.history, this.stats, this.offline, this.premium, this.updatedAt,
      {this.res = const {}, this.pool = const []});

  V2Stat stat(String key) => stats[key] ?? V2Stat(0, 0, null);
}
