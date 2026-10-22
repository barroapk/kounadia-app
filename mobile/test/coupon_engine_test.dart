// Vérifie que le moteur de coupons de l'app donne exactement les mêmes coupons que la formule
// testée dans tools/coupon-lab (backtest), et qu'il respecte toujours les critères.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kounadia/models/coupon.dart';
import 'package:kounadia/models/live_match.dart';
import 'package:kounadia/services/coupon_engine.dart';

void main() {
  final matches = [
    for (final j in jsonDecode(File('test/fixtures/coupon_matches.json').readAsStringSync()) as List)
      LiveMatch.fromJson(Map<String, dynamic>.from(j as Map))
  ];
  final expected = jsonDecode(File('test/fixtures/coupon_expected.json').readAsStringSync()) as Map<String, dynamic>;
  final presets = {
    'safe': CouponCriteria.safe,
    'balanced': CouponCriteria.balanced,
    'bold': CouponCriteria.bold,
  };

  for (final e in presets.entries) {
    test('${e.key} : mêmes coupons que le backtest', () {
      final c = e.value();
      final cands = CouponEngine.candidates(matches, c);
      final first = CouponEngine.generate(cands, c);
      final second = CouponEngine.generate(cands, c, exclude: first.map((x) => x.signature).toSet());
      for (final (got, want) in [(first, expected[e.key]['first']), (second, expected[e.key]['second'])]) {
        final w = want as List;
        expect(got.length, w.length);
        for (var i = 0; i < got.length; i++) {
          expect(got[i].signature, w[i][0]);
          expect(got[i].prob, closeTo((w[i][1] as num).toDouble(), 1e-9));
        }
      }
    });

    test('${e.key} : critères toujours respectés', () {
      final c = e.value();
      final res = CouponEngine.generate(CouponEngine.candidates(matches, c), c);
      expect(res, isNotEmpty);
      for (final cp in res) {
        expect(cp.legs.length, inInclusiveRange(c.countMin, c.countMax));
        expect(cp.total, inInclusiveRange(c.totalMin - 1e-9, c.totalMax + 1e-9));
        expect(cp.legs.map((l) => l.matchId).toSet().length, cp.legs.length);
        for (final l in cp.legs) {
          expect(l.odd, inInclusiveRange(c.oddMin, c.oddMax));
          expect(l.prob, inInclusiveRange(c.probMin, c.probMax));
        }
      }
    });
  }
}
