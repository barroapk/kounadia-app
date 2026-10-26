import 'dart:math';
import '../models/coupon.dart';
import '../models/live_match.dart';
import 'markets_service.dart' show MatchMarkets;
import 'primatips_service.dart' show frLeague;
import '../models/v2.dart';
import 'live_socket.dart';

class CouponEngine {
  static Leg legOf(LiveMatch m, String pick, double odd, int prob) => Leg(
        matchId: m.id,
        home: m.home,
        away: m.away,
        league: frLeague(m.leagueLabel),
        flag: m.flag,
        pick: pick,
        odd: odd,
        prob: prob,
        date: m.date,
      );

  // Formule validée par backtest sur 240 jours de matchs (outil : tools/coupon-lab) :
  // 1) probabilité = cotes des bookmakers sans leur marge (mieux calibrée que PrimaTips) ;
  // 2) on refuse les paris trop mal payés (probabilité × cote < 0,9) ;
  // 3) chaque pari a un « coût » = -ln(P) / ln(cote) : plus il est bas, mieux le risque est payé ;
  // 4) recherche des combinaisons à la plus forte chance de gain dans la fourchette de cote ;
  // 5) « accord » : la chance retenue est la plus prudente entre les cotes et PrimaTips
  //    (week-end du 25/10 : 93 % de gagnés quand les deux dépassent 80 %, contre 89 % avec les cotes seules) ;
  // 6) variété : au plus 2 fois le même pari dans un coupon.
  static const _sameMax = 2;
  static const _vmin = 0.9;
  static const _dcCut = 0.98;

  static int _cmpStr(String a, String b) => a.compareTo(b);
  static double _cost(Leg l) => -log(l.prob / 100) / log(l.odd);

  /// Pour chaque match à venir : la liste des paris qui respectent les critères (meilleur d'abord).
  static List<List<Leg>> candidates(Iterable<LiveMatch> matches, CouponCriteria c,
      [Map<int, MatchMarkets> markets = const {}]) {
    final limit = DateTime.now().add(Duration(minutes: 10));
    final out = <List<Leg>>[];
    for (final m in matches) {
      if (m.status != 'upcoming' || m.date == null || m.date!.isBefore(limit)) continue;
      final ev = <(Leg, double)>[];
      // p : chance d'après les cotes (filtre de valeur) ; pt : avis PrimaTips en %, s'il existe.
      void add(String pick, double odd, double p, [int? pt]) {
        if (!(odd > 1.01 && p > 0 && p < 1)) return;
        final shown = pt != null && pt > 0 && pt < 100 && pt / 100 < p ? pt / 100 : p;
        ev.add((legOf(m, pick, odd, (shown * 100).round()), p));
      }

      final o = m.odds;
      if (o != null && o.length == 3 && o.every((x) => x > 1.01)) {
        final inv = [for (final x in o) 1 / x];
        final s = inv[0] + inv[1] + inv[2];
        final q = [for (final x in inv) x / s];
        double dcOdd(int i, int j, String code) {
          final t = m.tip.toUpperCase();
          final to = m.tipOdd;
          if (t == code && to != null && to > 1.01) return to;
          return (_dcCut / (inv[i] + inv[j]) * 100).round() / 100;
        }

        final pp = m.probs != null && m.probs!.length == 3 ? m.probs! : null;
        int? pt(int i, [int? j]) => pp == null ? null : pp[i] + (j == null ? 0 : pp[j]);
        if (c.win) {
          add('1', o[0], q[0], pt(0));
          add('2', o[2], q[2], pt(2));
        }
        if (c.draw) add('X', o[1], q[1], pt(1));
        if (c.dc) {
          add('1X', dcOdd(0, 1, '1X'), q[0] + q[1], pt(0, 1));
          add('X2', dcOdd(1, 2, 'X2'), q[1] + q[2], pt(1, 2));
          add('12', dcOdd(0, 2, '12'), q[0] + q[2], pt(0, 2));
        }
      }
      // Buts et « les deux marquent » : même règle, probabilité tirée des deux cotes.
      void pair(String yes, String no, (List<double>, List<int>)? x) {
        if (x == null || x.$1.length < 2) return;
        final a = x.$1[0], b = x.$1[1];
        if (a <= 1.01 || b <= 1.01) return;
        final qa = (1 / a) / (1 / a + 1 / b);
        final py = x.$2.isNotEmpty ? x.$2[0] : null;
        add(yes, a, qa, py);
        add(no, b, 1 - qa, py == null ? null : 100 - py);
      }

      final mk = markets[m.id];
      if (mk != null) {
        if (c.goals) {
          pair('O15', 'U15', mk.m['ou15']);
          pair('O25', 'U25', mk.m['ou25']);
          pair('O35', 'U35', mk.m['ou35']);
        }
        if (c.btts) pair('BTS', 'OTS', mk.m['btts']);
      }
      final ok = [
        for (final (l, p) in ev)
          if (l.odd >= c.oddMin &&
              l.odd <= c.oddMax &&
              l.prob >= c.probMin &&
              l.prob <= c.probMax &&
              p * l.odd >= _vmin)
            l
      ]..sort((a, b) {
          final d = _cost(a).compareTo(_cost(b));
          return d != 0 ? d : _cmpStr(a.pick, b.pick);
        });
      if (ok.isNotEmpty) out.add(ok);
    }
    return out;
  }

  /// Identifiant numérique stable d'un match du moteur (matchs hors PrimaTips : nombre négatif).
  static int poolId(V2PoolMatch m) {
    if (m.pt != null) return m.pt!;
    var h = 0x811c9dc5;
    for (final c in m.id.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x3fffffff;
    }
    return -h - 1;
  }

  /// Candidats tirés de la liste « Créer coupon » du moteur KOUNADIA : toutes les catégories
  /// (victoire, double chance, buts, les deux marquent, buts d'une équipe, mi-temps, corners/fautes/tirs),
  /// paris contredits par les statistiques déjà écartés. Même tri que les autres paris.
  static List<List<Leg>> poolCandidates(Iterable<V2PoolMatch> pool, CouponCriteria c) {
    final limit = DateTime.now().add(Duration(minutes: 10));
    final out = <List<Leg>>[];
    bool on(String fam, String mk) {
      switch (fam) {
        case 'res':
          return c.win;
        case 'dc':
          return c.dc;
        case 'buts':
          return c.goals;
        case 'btts':
          return c.btts;
        case 'equipe':
          return c.team;
        case 'mt':
          return c.half;
      }
      return fam.startsWith('st') && c.stats;
    }

    for (final m in pool) {
      if (m.date == null || m.date!.isBefore(limit)) continue;
      final ok = <Leg>[];
      for (final (mk, p, odd, est, fam) in m.ev) {
        if (!on(fam, mk)) continue;
        final prob = p.round();
        if (odd < c.oddMin || odd > c.oddMax || prob < c.probMin || prob > c.probMax) continue;
        if (!est && p / 100 * odd < _vmin) continue;
        ok.add(Leg(
          matchId: poolId(m),
          home: m.home,
          away: m.away,
          league: m.leagueLabel,
          flag: m.flag ?? '',
          pick: mk,
          odd: odd,
          prob: prob,
          date: m.date,
          v2: m.id,
          mk: mk,
          txt: v2Label(mk, m.home, m.away),
          pt: m.pt,
          est: est,
        ));
      }
      ok.sort((a, b) {
        final d = _cost(a).compareTo(_cost(b));
        return d != 0 ? d : _cmpStr(a.pick, b.pick);
      });
      if (ok.isNotEmpty) out.add(ok);
    }
    return out;
  }

  static String _sig(List<Leg> legs) => (legs.map((l) => '${l.matchId}:${l.pick}').toList()..sort()).join('|');

  static List<Coupon> generate(List<List<Leg>> cands, CouponCriteria c,
      {Set<String> exclude = const {}, int max = 5}) {
    if (cands.length < c.countMin) return [];
    // Meilleur pari de chaque match d'abord, puis les autres options des mêmes matchs.
    final pool = <(Leg, int, double)>[];
    for (final e in cands) {
      for (var i = 0; i < e.length; i++) {
        pool.add((e[i], i, _cost(e[i])));
      }
    }
    pool.sort((a, b) {
      if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
      final d = a.$3.compareTo(b.$3);
      if (d != 0) return d;
      if (a.$1.matchId != b.$1.matchId) return a.$1.matchId.compareTo(b.$1.matchId);
      return _cmpStr(a.$1.pick, b.$1.pick);
    });
    final top = [for (final x in pool.take(40)) x.$1];
    // Une même famille (buts, double chance…) au plus la moitié du coupon, si au moins 3 familles sont proposées.
    final famRule = top.map((l) => famOf(l.pick)).toSet().length >= 3;
    double key(_State s) => s.lp / max2(log(s.total), 0.01);
    var beam = [_State(const [], 1.0, 0.0, -1)];
    final done = <String, _State>{};
    for (var depth = 0; depth < c.countMax && beam.isNotEmpty; depth++) {
      final next = <_State>[];
      for (final st in beam) {
        for (var i = st.last + 1; i < top.length; i++) {
          final l = top[i];
          if (st.legs.any((x) => x.matchId == l.matchId)) continue;
          // Variété : coupon de 4 matchs ou moins = jamais deux fois le même pari.
          if (st.legs.where((x) => x.pick == l.pick).length >= (c.countMax <= 4 ? 1 : _sameMax)) continue;
          if (famRule && st.legs.where((x) => famOf(x.pick) == famOf(l.pick)).length + 1 > (st.legs.length + 2) ~/ 2) continue;
          final total = st.total * l.odd;
          if (total > c.totalMax) continue;
          final ns = _State([...st.legs, l], total, st.lp + log(l.prob / 100), i);
          if (ns.legs.length >= c.countMin && total >= c.totalMin) {
            final sg = _sig(ns.legs);
            if (!exclude.contains(sg)) done[sg] = ns;
          } else {
            next.add(ns);
          }
        }
      }
      next.sort((a, b) {
        final d = key(b).compareTo(key(a));
        if (d != 0) return d;
        final e = b.lp.compareTo(a.lp);
        return e != 0 ? e : _cmpStr(_sig(a.legs), _sig(b.legs));
      });
      beam = next.length > 300 ? next.sublist(0, 300) : next;
    }
    final sorted = [
      for (final e in done.entries)
        (e.key, e.value.legs, e.value.legs.fold<double>(1.0, (v, l) => v * l.prob / 100))
    ]..sort((a, b) {
        final d = b.$3.compareTo(a.$3);
        return d != 0 ? d : _cmpStr(a.$1, b.$1);
      });
    final picked = <Coupon>[];
    final used = <int, int>{};
    for (final (_, legs, _) in sorted) {
      if (picked.length >= max) break;
      // Un match n'apparaît que dans UN seul coupon : un pari perdu ne fait jamais perdre deux coupons.
      if (legs.any((l) => (used[l.matchId] ?? 0) >= 1)) continue;
      picked.add(Coupon.of(legs));
      for (final l in legs) {
        used[l.matchId] = (used[l.matchId] ?? 0) + 1;
      }
    }
    return picked;
  }

  static double max2(double a, double b) => a > b ? a : b;

  /// Famille d'un pari : victoire, double chance, buts, les deux marquent, buts d'une équipe, mi-temps, statistiques.
  static String famOf(String p) {
    if (p == '1' || p == '2' || p == 'X') return 'res';
    if (p == '1X' || p == 'X2' || p == '12') return 'dc';
    if (RegExp(r'^[OU]\d\d$').hasMatch(p) || RegExp(r'^[+-]\d\.5$').hasMatch(p)) return 'buts';
    if (p == 'BTS' || p == 'OTS' || p.startsWith('BTTS')) return 'btts';
    if (p.startsWith('Dom.') || p.startsWith('Ext.')) return 'equipe';
    if (p.contains('MT')) return 'mt';
    return p.split(' ').first;
  }

  static bool evalPick(String pick, int h, int a) {
    switch (pick) {
      case '1':
        return h > a;
      case 'X':
        return h == a;
      case '2':
        return a > h;
      case '1X':
        return h >= a;
      case 'X2':
        return a >= h;
      case '12':
        return h != a;
      case 'BTS':
        return h > 0 && a > 0;
      case 'OTS':
        return h == 0 || a == 0;
    }
    final g = RegExp(r'^([OU])(\d)(\d)$').firstMatch(pick);
    if (g != null) {
      final line = int.parse(g[2]!) + int.parse(g[3]!) / 10;
      return g[1] == 'O' ? h + a > line : h + a < line;
    }
    return false;
  }

  /// Met à jour les résultats des matchs d'un coupon à partir des scores.
  static void refresh(Coupon c, Map<int, LiveMatch> byId, [Map<String, V2Res> res = const {}]) {
    for (final l in c.legs) {
      if (l.result == 'won' || l.result == 'lost' || l.result == 'void') continue;
      if (l.mk != null && l.v2 != null) {
        _refreshV2(l, byId, res);
        continue;
      }
      final m = byId[l.matchId];
      if (m == null) continue;
      if (m.status == 'postponed') {
        l.result = 'void';
      } else if (m.status == 'finished' && m.hs != null && m.as_ != null) {
        l.result = evalPick(l.pick, m.hs!, m.as_!) ? 'won' : 'lost';
      } else if (m.status == 'live') {
        l.result = 'live';
      } else {
        l.result = 'pending';
      }
    }
  }
}

/// Pari du moteur : résultat officiel (score, mi-temps, statistiques) sinon direct du robot.
void _refreshV2(Leg l, Map<int, LiveMatch> byId, Map<String, V2Res> res) {
  final r = res[l.v2];
  if (r != null) {
    if (r.isVoid) {
      l.result = 'void';
      return;
    }
    if (r.hg != null && r.ag != null) l.score = '${r.hg}-${r.ag}';
    final v = v2Settle(l.mk!, r);
    if (v != null) {
      l.result = v ? 'won' : 'lost';
      return;
    }
  }
  final id = l.pt;
  final live = id == null ? null : LiveSocket.last[id];
  final m = id == null ? null : byId[id];
  int? hs = m?.hs, as_ = m?.as_;
  var st = m?.status ?? '';
  if (live != null && live.$1 != null && live.$2 != null) {
    hs = live.$1;
    as_ = live.$2;
    st = RegExp(r'^(FT|AET|PEN)', caseSensitive: false).hasMatch(live.$3) ? 'finished' : RegExp(r'^(\d|HT)').hasMatch(live.$3) ? 'live' : st;
  }
  if (m?.status == 'postponed') {
    l.result = 'void';
  } else if (hs != null && as_ != null && (st == 'live' || st == 'finished')) {
    l.score = '$hs-$as_';
    // Paris qui ne dépendent que du score final : réglés dès la fin ; les autres attendent les statistiques.
    final v = st == 'finished' ? v2Settle(l.mk!, V2Res.fromJson({'hg': hs, 'ag': as_})) : null;
    l.result = v == null ? 'live' : (v ? 'won' : 'lost');
  } else if (l.date != null && DateTime.now().isAfter(l.date!)) {
    l.result = 'live';
  } else {
    l.result = 'pending';
  }
}

class _State {
  final List<Leg> legs;
  final double total, lp;
  final int last;
  const _State(this.legs, this.total, this.lp, this.last);
}
