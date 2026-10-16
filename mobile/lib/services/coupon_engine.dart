import 'dart:math';
import '../models/coupon.dart';
import '../models/live_match.dart';
import 'markets_service.dart' show MatchMarkets;
import 'primatips_service.dart' show frLeague;

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

  /// Pour chaque match à venir : la liste des paris qui respectent les critères.
  static List<List<Leg>> candidates(Iterable<LiveMatch> matches, CouponCriteria c,
      [Map<int, MatchMarkets> markets = const {}]) {
    final limit = DateTime.now().add(const Duration(minutes: 10));
    final out = <List<Leg>>[];
    for (final m in matches) {
      if (m.status != 'upcoming' || m.date == null || m.date!.isBefore(limit)) continue;
      final ev = <Leg>[];
      final p = m.probs;
      final o = m.odds;
      if (p != null && o != null && p.length == 3 && o.length == 3) {
        if (c.win) {
          ev.add(legOf(m, '1', o[0], p[0]));
          ev.add(legOf(m, '2', o[2], p[2]));
        }
        if (c.draw) ev.add(legOf(m, 'X', o[1], p[1]));
        if (c.dc && m.tipOdd != null) {
          final t = m.tip.toUpperCase();
          final pr = t == '1X'
              ? p[0] + p[1]
              : t == 'X2'
                  ? p[1] + p[2]
                  : t == '12'
                      ? p[0] + p[2]
                      : null;
          if (pr != null) ev.add(legOf(m, t, m.tipOdd!, pr));
        }
      }
      final mk = markets[m.id];
      if (mk != null) {
        if (c.goals) {
          for (final (key, code) in const [('ou15', '15'), ('ou25', '25'), ('ou35', '35')]) {
            final x = mk.m[key];
            if (x == null) continue;
            ev.add(legOf(m, 'O$code', x.$1[0], x.$2[0]));
            ev.add(legOf(m, 'U$code', x.$1[1], x.$2[1]));
          }
        }
        if (c.btts) {
          final x = mk.m['btts'];
          if (x != null) {
            ev.add(legOf(m, 'BTS', x.$1[0], x.$2[0]));
            ev.add(legOf(m, 'OTS', x.$1[1], x.$2[1]));
          }
        }
      }
      final ok = ev
          .where((l) =>
              l.odd > 1.01 &&
              l.odd >= c.oddMin &&
              l.odd <= c.oddMax &&
              l.prob >= c.probMin &&
              l.prob <= c.probMax)
          .toList();
      if (ok.isNotEmpty) out.add(ok);
    }
    return out;
  }

  static Leg _pick(List<Leg> evs, Random rnd) {
    if (evs.length == 1) return evs.first;
    final total = evs.fold<int>(0, (s, l) => s + l.prob);
    var r = rnd.nextInt(total < 1 ? 1 : total);
    for (final l in evs) {
      r -= l.prob;
      if (r < 0) return l;
    }
    return evs.last;
  }

  static List<Coupon> generate(List<List<Leg>> cands, CouponCriteria c,
      {Set<String> exclude = const {}, int max = 5}) {
    if (cands.length < c.countMin) return [];
    final rnd = Random(DateTime.now().microsecondsSinceEpoch);
    final found = <String, Coupon>{};
    for (var attempt = 0; attempt < 8000 && found.length < 300; attempt++) {
      final keyed = [
        for (final e in cands)
          (e, e.map((l) => l.prob).reduce((a, b) => a > b ? a : b) * (0.35 + rnd.nextDouble()))
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      final legs = <Leg>[];
      var total = 1.0;
      for (final (evs, _) in keyed) {
        if (legs.length >= c.countMax) break;
        final l = _pick(evs, rnd);
        final nt = total * l.odd;
        if (nt > c.totalMax) continue;
        legs.add(l);
        total = nt;
        if (legs.length >= c.countMin && total >= c.totalMin) break;
      }
      if (legs.length < c.countMin || legs.length > c.countMax) continue;
      if (total < c.totalMin || total > c.totalMax) continue;
      final cp = Coupon.of(legs);
      if (exclude.contains(cp.signature)) continue;
      found[cp.signature] = cp;
    }
    final sorted = found.values.toList()..sort((a, b) => b.prob.compareTo(a.prob));
    final picked = <Coupon>[];
    final used = <int, int>{};
    for (final cp in sorted) {
      if (picked.length >= max) break;
      if (cp.legs.any((l) => (used[l.matchId] ?? 0) >= 2)) continue;
      picked.add(cp);
      for (final l in cp.legs) {
        used[l.matchId] = (used[l.matchId] ?? 0) + 1;
      }
    }
    return picked;
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
  static void refresh(Coupon c, Map<int, LiveMatch> byId) {
    for (final l in c.legs) {
      if (l.result == 'won' || l.result == 'lost' || l.result == 'void') continue;
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
