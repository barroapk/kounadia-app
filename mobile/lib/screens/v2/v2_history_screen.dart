import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/v2.dart';
import '../../widgets/forecast_card.dart' show K, frDay, kHonest, kMessage;
import 'v2_widgets.dart';

/// Ce qu'on affiche dans un historique : un coupon (single, vip2, sel c5…) ou une liste d'événements.
class V2Cat {
  final String key; // clé du bilan (stats)
  final String title;
  final V2Coupon? Function(V2Day d)? coupon;
  final List<V2Leg> Function(V2Day d)? legs;
  const V2Cat(this.key, this.title, {this.coupon, this.legs});
}

/// Historique intégral (14 jours) d'une catégorie : bilan + chaque jour avec ses résultats.
class V2HistoryScreen extends StatefulWidget {
  final V2Cat cat;
  final V2Data data;
  V2HistoryScreen(this.cat, this.data, {super.key});

  @override
  State<V2HistoryScreen> createState() => _V2HistoryScreenState();
}

class _V2HistoryScreenState extends State<V2HistoryScreen> {
  String _f = 'all'; // all, won, lost

  bool _keep(String? r) => _f == 'all' ? (r == 'won' || r == 'lost') : r == _f;

  @override
  Widget build(BuildContext context) {
    final cat = widget.cat;
    final s = widget.data.stat(cat.key);
    final items = <Widget>[];
    for (final d in widget.data.history) {
      final date = d.date;
      if (cat.coupon != null) {
        final c = cat.coupon!(d);
        if (c == null || !_keep(c.r)) continue;
        items.add(V2CouponCard(
          title: date == null ? d.day : frDay(date),
          coupon: c,
          accent: c.r == 'won' ? K.green : K.red,
        ));
      } else if (cat.legs != null) {
        final legs = cat.legs!(d).where((l) => _keep(l.r)).toList();
        if (legs.isEmpty) continue;
        items.add(Padding(
          padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Text(date == null ? d.day : frDay(date),
              style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6)),
        ));
        items.add(Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
          child: Column(children: [
            for (var i = 0; i < legs.length; i++) ...[
              if (i > 0) Container(height: 1, color: K.border),
              V2LegRow(legs[i]),
            ],
          ]),
        ));
      }
    }
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        backgroundColor: K.bg,
        foregroundColor: K.text,
        title: T(cat.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: ListView(padding: EdgeInsets.fromLTRB(14, 6, 14, 40), children: [
        _summary(s),
        SizedBox(height: 12),
        Row(children: [
          for (final (k, t) in [('all', 'Tous'), ('won', 'Gagnés'), ('lost', 'Perdus')]) ...[
            Expanded(
              child: ChoiceChip(
                label: Center(child: T(t)),
                selected: _f == k,
                onSelected: (_) => setState(() => _f = k),
                selectedColor: K.indigoSoft,
                backgroundColor: K.card,
                labelStyle: TextStyle(color: _f == k ? K.indigoText : K.muted, fontWeight: FontWeight.w800),
                side: BorderSide(color: K.border),
                showCheckmark: false,
              ),
            ),
            if (k != 'lost') SizedBox(width: 8),
          ],
        ]),
        SizedBox(height: 6),
        if (items.isEmpty)
          SizedBox(height: 260, child: kMessage('Aucun résultat sur les 14 derniers jours.'))
        else
          ...items,
        SizedBox(height: 18),
        T(kHonest, textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11.5, height: 1.4)),
      ]),
    );
  }

  Widget _summary(V2Stat s) {
    final pct = (s.pct ?? 0) / 100;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.border)),
      child: Row(children: [
        SizedBox(
          width: 78,
          height: 78,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 78,
              height: 78,
              child: CircularProgressIndicator(
                value: s.total == 0 ? 0 : pct,
                strokeWidth: 8,
                backgroundColor: K.red.withAlpha(s.total == 0 ? 30 : 90),
                color: K.green,
              ),
            ),
            Text(s.total == 0 ? '—' : '${s.pct?.round()} %',
                style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w900)),
          ]),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T('14 derniers jours', style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Row(children: [
              Icon(Icons.check_circle_rounded, color: K.green, size: 18),
              SizedBox(width: 6),
              Text('${s.won} ${tr(s.won > 1 ? 'gagnés' : 'gagné')}', style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
            SizedBox(height: 4),
            Row(children: [
              Icon(Icons.cancel_rounded, color: K.red, size: 18),
              SizedBox(width: 6),
              Text('${s.lost} ${tr(s.lost > 1 ? 'perdus' : 'perdu')}', style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
