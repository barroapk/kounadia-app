// KOUNADIA V2 : Coupon du jour, Sélection du jour et historiques (données du moteur V2).
import '../services/primatips_service.dart' show frLeague;

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Un événement (pari) : match + marché + confiance KOUNADIA + cote.
class V2Leg {
  final String id, home, away, country, league, mk, txt, fam;
  final DateTime? date;
  final double p, odd;
  final bool est;
  final List<String> why;
  String? r; // won, lost, void, live, null = à venir
  String? score;

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
        why = ((j['why'] as List?) ?? const []).map((e) => e.toString()).toList(),
        r = j['r']?.toString(),
        score = j['score']?.toString();

  /// Identifiant PrimaTips (pour le direct), si le match vient de PrimaTips.
  int? get ptId => id.startsWith('pt:') ? int.tryParse(id.substring(3)) : null;

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
class V2Day {
  final String day;
  final int matches;
  final Map<String, V2Coupon?> coupons;
  final V2Selection? selection;

  V2Day.fromJson(Map<String, dynamic> j)
      : day = (j['day'] ?? '').toString(),
        matches = (j['matches'] as num?)?.toInt() ?? 0,
        coupons = {
          for (final e in ((j['coupons'] as Map?) ?? const {}).entries)
            e.key.toString(): e.value == null ? null : V2Coupon.fromJson(Map<String, dynamic>.from(e.value as Map)),
        },
        selection = j['selection'] is Map ? V2Selection.fromJson(Map<String, dynamic>.from(j['selection'] as Map)) : null;

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
  V2Data(this.today, this.history, this.stats, this.offline, this.premium, this.updatedAt);

  V2Stat stat(String key) => stats[key] ?? V2Stat(0, 0, null);
}
