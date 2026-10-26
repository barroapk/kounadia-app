import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/v2.dart';
import '../../widgets/forecast_card.dart' show K, kMessage;
import '../../widgets/knd_banner.dart';
import 'v2_cats.dart';
import 'v2_widgets.dart';

export 'v2_cats.dart' show V2Cat;

/// Historique d'une rubrique, comme dans KOUNADIA : bilan de la semaine, jours de cette semaine
/// et de la semaine dernière, gagnés / perdus.
class V2HistoryScreen extends StatefulWidget {
  final V2Cat cat;
  final V2Data data;
  V2HistoryScreen(this.cat, this.data, {super.key});

  @override
  State<V2HistoryScreen> createState() => _V2HistoryScreenState();
}

class _V2HistoryScreenState extends State<V2HistoryScreen> {
  DateTime? _day;
  bool _lost = false;

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  String _pct(int w, int n) => n == 0 ? '–' : '${(w * 100 / n).round()} %';

  V2Day? _dayData(DateTime d) {
    for (final x in [if (widget.data.today != null) widget.data.today!, ...widget.data.history]) {
      final xd = x.date;
      if (xd != null && _same(xd, d)) return x;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.cat;
    final today = v2Day0(DateTime.now());
    final monday = v2Monday(today);
    final prevMonday = monday.subtract(Duration(days: 7));
    final thisWeek = [for (var d = monday; !d.isAfter(today); d = d.add(Duration(days: 1))) d];
    final lastWeek = [for (var d = prevMonday; d.isBefore(monday); d = d.add(Duration(days: 1))) d];
    final yesterday = today.subtract(Duration(days: 1));
    final sel = _day ?? (thisWeek.length > 1 ? yesterday : lastWeek.last);
    final dd = _dayData(sel);
    final (w, n) = dd == null ? (0, 0) : cat.count(dd);

    final content = <Widget>[];
    if (dd != null && cat.coupon != null) {
      final c = cat.coupon!(dd);
      if (c != null && c.r == (_lost ? 'lost' : 'won')) {
        content.add(V2CouponCard(title: cat.title, coupon: c, accent: _lost ? K.red : K.green));
      }
    } else if (dd != null && cat.legs != null) {
      final legs = cat.legs!(dd).where((l) => l.r == (_lost ? 'lost' : 'won')).toList();
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
        _weekCard(cat.period(widget.data, monday, monday.add(Duration(days: 7))), cat.period(widget.data, prevMonday, monday)),
        SizedBox(height: 14),
        _days('Cette semaine', thisWeek, sel),
        SizedBox(height: 10),
        _days('Semaine dernière', lastWeek, sel),
        SizedBox(height: 14),
        _gauge(w, n, sel),
        SizedBox(height: 12),
        Row(children: [
          _half('Gagnés', w, false, K.green),
          SizedBox(width: 8),
          _half('Perdus', n - w, true, K.red),
        ]),
        SizedBox(height: 12),
        if (content.isEmpty)
          SizedBox(height: 160, child: kMessage(_lost ? 'Aucun perdu ce jour-là.' : 'Aucun gagné ce jour-là.'))
        else
          ...content,
        KndBanner(),
      ]),
    );
  }

  Widget _weekCard((int, int) week, (int, int) last) {
    Widget stat(String label, (int, int) v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T(tr(label).toUpperCase(),
                style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
            SizedBox(height: 4),
            Text(_pct(v.$1, v.$2), style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            Text('${v.$1} ${tr('gagnés sur')} ${v.$2}', style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12)),
          ]),
        );
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        stat('Cette semaine', week),
        Container(width: 1, height: 52, color: Color(0x44FFFFFF), margin: EdgeInsets.symmetric(horizontal: 12)),
        stat('Semaine dernière', last),
      ]),
    );
  }

  Widget _days(String title, List<DateTime> days, DateTime sel) {
    final today = v2Day0(DateTime.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.only(left: 4, bottom: 6),
        child: T(title, style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w800)),
      ),
      // Les 7 jours tiennent sur l'écran (pas de défilement) : le jour choisi est toujours visible.
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: i >= days.length
                ? SizedBox(height: 62)
                : Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () => setState(() => _day = days[i]),
                      child: Builder(builder: (_) {
                        final d = days[i];
                        final on = _same(d, sel);
                        final dd = _dayData(d);
                        final (w, n) = dd == null ? (0, 0) : widget.cat.count(dd);
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 160),
                          height: 62,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on ? K.indigo : K.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: on ? K.indigo : K.border, width: on ? 2 : 1),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(_same(d, today) ? tr("Auj.") : dayName(d.weekday),
                                  style: TextStyle(color: on ? Colors.white : K.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('${d.day}',
                                  style: TextStyle(color: on ? Colors.white : K.text, fontSize: 16, fontWeight: FontWeight.w900)),
                              Text(n == 0 ? '–' : '$w/$n',
                                  style: TextStyle(color: on ? Color(0xDDFFFFFF) : K.green, fontSize: 11, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                        );
                      }),
                    ),
                  ),
          ),
      ]),
    ]);
  }

  Widget _gauge(int w, int n, DateTime day) {
    final l = n - w;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: K.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_pct(w, n), style: TextStyle(color: K.text, fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
          SizedBox(width: 10),
          Expanded(
            child: Text('${tr('gagnés')} · ${dayName(day.weekday)} ${day.day}',
                style: TextStyle(color: K.muted, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: n == 0
                ? Container(color: K.border)
                : Row(children: [
                    if (w > 0) Expanded(flex: w, child: Container(color: K.green)),
                    if (l > 0) Expanded(flex: l, child: Container(color: K.red)),
                  ]),
          ),
        ),
        SizedBox(height: 10),
        Text(n == 0 ? tr('Aucun résultat ce jour-là.') : '$w ${tr('gagnés')} · $l ${tr('perdus')}',
            style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _half(String label, int count, bool lostTab, Color c) {
    final on = _lost == lostTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _lost = lostTab),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.withAlpha(46) : K.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? c : K.border),
          ),
          child: Text('${tr(label)} · $count', style: TextStyle(color: on ? c : K.muted, fontSize: 13.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
