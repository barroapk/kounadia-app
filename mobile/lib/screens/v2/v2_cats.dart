import '../../models/v2.dart';

/// Une rubrique avec son historique : un coupon (single, vip2, coupon 5+…) ou une liste d'événements.
class V2Cat {
  final String title;
  final V2Coupon? Function(V2Day d)? coupon;
  final List<V2Leg> Function(V2Day d)? legs;
  const V2Cat(this.title, {this.coupon, this.legs});

  /// Résultats terminés d'une journée : (gagnés, total).
  (int, int) count(V2Day d) {
    if (coupon != null) {
      final r = coupon!(d)?.r;
      return r == 'won' ? (1, 1) : r == 'lost' ? (0, 1) : (0, 0);
    }
    var w = 0, n = 0;
    for (final l in legs!(d)) {
      if (l.r == 'won') {
        w++;
        n++;
      } else if (l.r == 'lost') {
        n++;
      }
    }
    return (w, n);
  }

  /// Bilan d'une période [from, to[ (jours) sur l'historique + aujourd'hui.
  (int, int) period(V2Data data, DateTime from, DateTime to) {
    var w = 0, n = 0;
    for (final d in [if (data.today != null) data.today!, ...data.history]) {
      final day = d.date;
      if (day == null || day.isBefore(from) || !day.isBefore(to)) continue;
      final (a, b) = count(d);
      w += a;
      n += b;
    }
    return (w, n);
  }
}

DateTime v2Day0(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime v2Monday(DateTime d) => v2Day0(d).subtract(Duration(days: d.weekday - 1));
