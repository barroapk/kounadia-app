// KOUNADIA V2 : lecture des fichiers du moteur et règlement des paris (mêmes règles que kounadia-engine/scripts/v2/core.mjs).
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kounadia/models/v2.dart';
import 'package:kounadia/services/v2_service.dart';
import 'package:kounadia/services/v2_live.dart';
import 'package:kounadia/models/coupon.dart';
import 'package:kounadia/services/coupon_engine.dart';

Map<String, dynamic> _load(String f) =>
    Map<String, dynamic>.from(jsonDecode(File('test/fixtures/$f').readAsStringSync()) as Map);

void main() {
  test('règlement immédiat des paris (score final)', () {
    expect(V2Service.quick('1', 2, 1), true);
    expect(V2Service.quick('1', 1, 1), false);
    expect(V2Service.quick('2', 0, 3), true);
    expect(V2Service.quick('1X', 1, 1), true);
    expect(V2Service.quick('X2', 2, 1), false);
    expect(V2Service.quick('12', 0, 0), false);
    expect(V2Service.quick('+2.5', 2, 1), true);
    expect(V2Service.quick('+2.5', 1, 1), false);
    expect(V2Service.quick('-1.5', 1, 0), true);
    expect(V2Service.quick('-3.5', 2, 2), false);
    expect(V2Service.quick('BTTS oui', 1, 1), true);
    expect(V2Service.quick('BTTS non', 2, 0), true);
    expect(V2Service.quick('Dom. +1.5', 2, 0), true);
    expect(V2Service.quick('Ext. marque', 3, 0), false);
    // Mi-temps et statistiques : réglés par le robot, jamais deviné par l'app.
    expect(V2Service.quick('+0.5 MT1', 2, 0), isNull);
    expect(V2Service.quick('Corners +8.5', 2, 0), isNull);
  });

  test('fichier Premium du moteur : coupons, sélection, historique, bilans', () {
    final j = _load('v2_sample.json');
    final t = V2Day.fromJson(Map<String, dynamic>.from(j['today'] as Map));
    expect(t.day, isNotEmpty);
    for (final k in ['single', 'free', 'vip2', 'vip3', 'vip5']) {
      expect(t.coupons.containsKey(k), true, reason: k);
    }
    final single = t.coupons['single']!;
    expect(single.legs.length, 1);
    expect(single.odd, greaterThanOrEqualTo(1.15));
    final free = t.coupons['free']!;
    expect(free.legs.length, inInclusiveRange(2, 3));
    // Jamais deux fois le même match dans le Coupon du jour.
    final ids = [for (final c in t.coupons.values) if (c != null) ...c.legs.map((l) => l.id)];
    expect(ids.toSet().length, ids.length);
    final s = t.selection!;
    expect(s.locked, false);
    expect(s.top, isNotEmpty);
    // La Sélection n'utilise aucun match du Coupon du jour.
    for (final l in [...s.top, ...s.byFam]) {
      expect(ids.contains(l.id), false, reason: l.id);
    }
    // Coupons de la Sélection : seulement des événements affichés (Coups sûrs ou catégories).
    final shown = {for (final l in [...s.top, ...s.byFam, ...s.fav]) '${l.id}|${l.mk}'};
    for (final c in s.coupons.values) {
      for (final l in c?.legs ?? const <V2Leg>[]) {
        expect(shown.contains('${l.id}|${l.mk}'), true, reason: l.txt);
      }
    }
    // Codes des paris
    for (final l in t.allLegs) {
      expect(l.p, inInclusiveRange(1, 95));
      expect(l.odd, greaterThanOrEqualTo(1.15));
      if (['1', '2', '1X', 'X2', '12'].contains(l.mk)) expect(l.code, l.mk);
    }
    final hist = (j['history'] as List).map((e) => V2Day.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    expect(hist, isNotEmpty);
    final st = V2Stat.fromJson(Map<String, dynamic>.from((j['stats'] as Map)['single'] as Map));
    expect(st.total, greaterThan(0));
  });

  test('fichier public : VIP et Sélection verrouillés', () {
    final j = _load('v2_public.json');
    final t = V2Day.fromJson(Map<String, dynamic>.from(j['today'] as Map));
    expect(t.coupons['single']!.legs.length, 1);
    expect(t.coupons['vip2']!.locked, true);
    expect(t.coupons['vip2']!.legs, isEmpty);
    expect(t.coupons['vip2']!.n, greaterThan(0));
    expect(t.selection!.locked, true);
  });

  test('résultat d\'un coupon recalculé avec le direct', () {
    final c = V2Coupon.fromJson({
      'odd': 2.0,
      'p': 50,
      'legs': [
        {'id': 'pt:1', 'mk': '1X', 'txt': '1X · A ou nul', 'p': 80, 'odd': 1.3, 'r': 'won'},
        {'id': 'pt:2', 'mk': '+1.5', 'txt': 'Plus de 1,5 buts', 'p': 75, 'odd': 1.4, 'r': null},
      ],
    });
    c.refresh();
    expect(c.r, isNull);
    c.legs[1].r = 'live';
    c.refresh();
    expect(c.r, 'live');
    c.legs[1].r = 'lost';
    c.refresh();
    expect(c.r, 'lost');
    expect(c.legs[0].code, '1X');
    expect(c.legs[1].code, '');
    expect(c.legs[0].ptId, 1);
  });

  test('statistiques ESPN : corners, fautes, tirs, mi-temps', () {
    final s = V2Live.parseSummary({
      'header': {
        'competitions': [
          {
            'status': {'displayClock': "67'", 'type': {'state': 'in', 'completed': false}},
            'competitors': [
              {'homeAway': 'home', 'id': '1', 'team': {'id': '1'}, 'score': '2', 'linescores': [{'displayValue': '1'}]},
              {'homeAway': 'away', 'id': '2', 'team': {'id': '2'}, 'score': '0', 'linescores': [{'displayValue': '0'}]},
            ],
          }
        ]
      },
      'boxscore': {
        'teams': [
          {'team': {'id': '1'}, 'statistics': [{'name': 'wonCorners', 'displayValue': '6'}, {'name': 'foulsCommitted', 'displayValue': '9'}]},
          {'team': {'id': '2'}, 'statistics': [{'name': 'wonCorners', 'displayValue': '2'}, {'name': 'shotsOnTarget', 'displayValue': '3'}]},
        ]
      },
    })!;
    expect(s.state, 'in');
    expect(s.done, false);
    expect(s.hg, 2);
    expect(s.h1, [1, 0]);
    expect(s.st['c'], [6, 2]);
    expect(s.st['f'], [9, null]);
    expect(s.st['t'], [null, 3]);
    final l = V2Leg.fromJson({'id': 'fd:x', 'mk': 'Corners +8.5', 'txt': 'Plus de 8,5 corners', 'fam': 'stc', 'p': 80, 'odd': 1.2,
      'st': {'c': [6, 2]}, 'pt': 7, 'espn': {'lg': 'fra.1', 'id': '9'}});
    expect(l.statPair, [6, 2]);
    expect(l.statName, 'Corners');
    expect(l.ptId, 7);
    expect(l.espnLg, 'fra.1');
    expect(l.code, '');
  });

  test('Créer coupon : règlement de toutes les catégories', () {
    final r = V2Res.fromJson({
      'hg': 2, 'ag': 1, 'h1': [1, 0], 'done': true,
      'st': {'c': [6, 4], 'f': [12, 11], 's': [14, 9], 't': [5, 3]},
    });
    expect(v2Settle('1', r), true);
    expect(v2Settle('X2', r), false);
    expect(v2Settle('+2.5', r), true);
    expect(v2Settle('BTTS oui', r), true);
    expect(v2Settle('Ext. marque', r), true);
    expect(v2Settle('+0.5 MT1', r), true);
    expect(v2Settle('+1.5 MT2', r), false);
    expect(v2Settle('But chaque MT', r), true);
    expect(v2Settle('Corners +9.5', r), true);
    expect(v2Settle('Fautes -22.5', r), false);
    expect(v2Settle('Tirs cadrés +7.5', r), true);
    expect(v2Settle('Corners +9.5', V2Res.fromJson({'hg': 1, 'ag': 0})), null);
    expect(v2Label('Corners +9.5', 'A', 'B'), 'Plus de 9,5 corners');
    expect(v2Label('-1.5 MT1', 'A', 'B'), 'Moins de 2 buts en 1re mi-temps');
  });

  test('Créer coupon : candidats de la liste du moteur', () {
    final m = V2PoolMatch.fromJson({
      'id': 'fd:E0:x', 'home': 'Arsenal', 'away': 'Leeds', 'country': 'Angleterre', 'league': 'Premier League',
      'date': DateTime.now().toUtc().add(Duration(hours: 3)).toIso8601String(),
      'ev': [['1', 72.0, 1.4, 0, 'res'], ['+0.5 MT2', 75.0, 1.3, 1, 'mt'], ['Corners +8.5', 70.0, 1.35, 1, 'stc']],
    });
    final c = CouponCriteria.balanced()..stats = false;
    final cands = CouponEngine.poolCandidates([m], c);
    expect(cands.length, 1);
    expect(cands.first.map((l) => l.mk).toSet(), {'1', '+0.5 MT2'});
    expect(cands.first.first.matchId < 0, true);
    expect(cands.first.first.v2, 'fd:E0:x');
    final leg = cands.first.firstWhere((l) => l.mk == '1');
    final back = Leg.fromJson(leg.toJson());
    expect(back.mk, '1');
    expect(back.label, '1 · Victoire Arsenal');
  });
}
