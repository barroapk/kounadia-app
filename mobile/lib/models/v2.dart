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
  String? get statKey => const {'stc': 'c', 'stf': 'f', 'sts': 's', 'stt': 't'}[fam];

  /// Nom de la statistique du pari.
  String? get statName => const {'c': 'Corners', 'f': 'Fautes', 's': 'Tirs', 't': 'Tirs cadrés'}[statKey];

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
