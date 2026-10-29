import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/v2.dart';
import '../../widgets/forecast_card.dart' show K, kMessage;
import '../../widgets/knd_banner.dart';
import 'v2_cats.dart';
import 'v2_widgets.dart';

export 'v2_cats.dart' show V2Cat;

/// Historique d'une rubrique : les résultats d'hier (gagnés puis perdus), sans pourcentages.
class V2HistoryScreen extends StatelessWidget {
  final V2Cat cat;
  final V2Data data;
  V2HistoryScreen(this.cat, this.data, {super.key});

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  V2Day? _dayData(DateTime d) {
    for (final x in [if (data.today != null) data.today!, ...data.history]) {
      final xd = x.date;
      if (xd != null && _same(xd, d)) return x;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final yesterday = v2Day0(DateTime.now()).subtract(Duration(days: 1));
    final dd = _dayData(yesterday);
    final content = <Widget>[];
    if (dd != null && cat.coupon != null) {
      final c = cat.coupon!(dd);
      if (c != null) content.add(V2CouponCard(title: cat.title, coupon: c, accent: c.r == 'lost' ? K.red : c.r == 'won' ? K.green : K.indigo));
    } else if (dd != null && cat.legs != null) {
      final legs = cat.legs!(dd).where((l) => l.r == 'won' || l.r == 'lost').toList()
        ..sort((a, b) => (a.r == 'won' ? 0 : 1) - (b.r == 'won' ? 0 : 1));
      content.addAll(v2Groups(legs));
    }
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        backgroundColor: K.bg,
        foregroundColor: K.text,
        title: T(cat.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: ListView(padding: EdgeInsets.fromLTRB(12, 6, 12, 40), children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4, 6, 4, 12),
          child: Text('${tr("Résultats d'hier")} · ${dayName(yesterday.weekday)} ${yesterday.day}',
              style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w900)),
        ),
        if (content.isEmpty)
          SizedBox(height: 160, child: kMessage('Aucun résultat ce jour-là.'))
        else
          ...content,
        KndBanner(),
      ]),
    );
  }
}
