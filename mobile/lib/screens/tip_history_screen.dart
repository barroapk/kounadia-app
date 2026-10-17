import 'package:flutter/material.dart';
import '../models/forecast.dart';
import '../services/kounadia_data_service.dart';
import '../services/vip_service.dart';
import 'sure_tab.dart' show sureForecast;
import '../widgets/forecast_card.dart';
import '../widgets/knd_banner.dart';

class TipHistoryScreen extends StatefulWidget {
  TipHistoryScreen({super.key});

  @override
  State<TipHistoryScreen> createState() => _TipHistoryScreenState();
}

class _TipHistoryScreenState extends State<TipHistoryScreen> {
  late Future<HistoryData> _f = _load();

  /// IA + Expert + Coup sûr gagnants (hier et aujourd'hui).
  Future<HistoryData> _load() async {
    final h = await KounadiaData.history();
    try {
      final v = await VipService.load();
      final legs = [...?v.today?.singles, for (final d in v.history.take(2)) ...d.singles];
      final seen = <int>{};
      final extra = <Forecast>[];
      for (final l in legs) {
        if (l.result == 'won' && seen.add(l.id)) extra.add(sureForecast(l));
      }
      return HistoryData([...h.items, ...extra], h.offline);
    } catch (_) {
      return h;
    }
  }
  int? _day; // 0 = aujourd'hui, 1 = hier (null = automatique)
  String _src = 'all';
  final Set<String> _collapsed = {};

  Future<void> _refresh() async {
    setState(() => _f = _load());
    try {
      await _f;
    } catch (_) {}
  }

  int _dayDiff(DateTime d) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      body: FutureBuilder<HistoryData>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: K.indigo));
          }
          if (snap.hasError) return kMessage(snap.error.toString(), onRetry: _refresh);
          final data = snap.data!;

          final wins = data.items.where((f) {
            final d = _dayDiff(f.date);
            return f.won == true && d >= 0 && d <= 1;
          }).toList();
          final today = wins.where((f) => _dayDiff(f.date) == 0).toList();
          final yesterday = wins.where((f) => _dayDiff(f.date) == 1).toList();
          final day = _day ?? (today.isNotEmpty ? 0 : 1);
          final ofDay = day == 0 ? today : yesterday;
          final items = ofDay.where((f) => _src == 'all' || f.source == _src).toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          final children = <Widget>[
            if (data.offline) kOfflineBanner(),
            _daySwitch(day, yesterday.length, today.length),
            SizedBox(height: 10),
            _srcChips(ofDay),
            SizedBox(height: 14),
            _hero(ofDay, day),
            SizedBox(height: 14),
            KndBanner(),
          ];

          if (items.isEmpty) {
            children.addAll([
              SizedBox(height: 30),
              kMessage(ofDay.isEmpty
                  ? (day == 0
                      ? "Les pronostics gagnants du jour s'afficheront ici dès la fin des matchs."
                      : "Aucun pronostic validé hier.")
                  : 'Aucun pronostic validé pour cette source.'),
            ]);
          } else {
            final groups = <String, List<Forecast>>{};
            for (final f in items) {
              groups.putIfAbsent(f.league.isEmpty ? 'Autres compétitions' : f.league, () => []).add(f);
            }
            var rows = 0;
            var block = 0;
            for (final e in groups.entries) {
              children
                ..add(_group('$day|$_src|${e.key}', e.key, e.value))
                ..add(SizedBox(height: 10));
              rows += e.value.length;
              if (rows ~/ 10 > block) {
                block = rows ~/ 10;
                children.add(KndBanner(afterCards: block * 10, total: items.length));
              }
            }
          }

          return RefreshIndicator(
            color: K.indigo,
            backgroundColor: K.card,
            onRefresh: _refresh,
            child: ListView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: children,
            ),
          );
        },
      ),
    );
  }

  Widget _daySwitch(int day, int nYesterday, int nToday) {
    Widget half(String label, int value, int count) {
      final sel = day == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _day = value),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 160),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? K.indigo : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$label · $count',
                style: TextStyle(
                    color: sel ? Colors.white : K.muted, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: K.border),
      ),
      child: Row(children: [
        half('Hier', 1, nYesterday),
        half("Aujourd'hui", 0, nToday),
      ]),
    );
  }

  Widget _srcChips(List<Forecast> ofDay) {
    final opts = [
      ('all', 'Tous', ofDay.length),
      ('ia', 'Kounadia IA', ofDay.where((f) => f.source == 'ia').length),
      ('expert', 'Expert', ofDay.where((f) => f.source == 'expert').length),
      ('sure', 'Coup sûr', ofDay.where((f) => f.source == 'sure').length),
    ];
    return Row(children: [
      for (final (value, label, count) in opts)
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => _src = value),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 150),
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _src == value ? K.indigoSoft : K.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _src == value ? K.indigoText : K.border),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('$label · $count',
                        style: TextStyle(
                            color: _src == value ? K.text : K.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _hero(List<Forecast> list, int day) {
    final n = list.length;
    final s = n > 1 ? 's' : '';
    final ia = list.where((f) => f.source == 'ia').length;
    final ex = list.where((f) => f.source == 'expert').length;
    final su = list.where((f) => f.source == 'sure').length;
    final when = day == 0 ? 'du jour' : "d'hier";
    Widget mini(String label, int v) => Container(
          margin: EdgeInsets.only(right: 8),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Color(0x33FFFFFF), borderRadius: BorderRadius.circular(20)),
          child: Text('$label : $v',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        );
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
          child: Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n == 0 ? 'Résultats à venir' : '$n pronostic$s validé$s',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text(
              n == 0
                  ? 'Nos pronostics gagnants $when apparaîtront ici dès la fin des matchs.'
                  : 'Sur nos pronostics $when Kounadia IA, Expert et Coup sûr, au total $n pronostic$s validé$s.',
              style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13, height: 1.35),
            ),
            if (n > 0) ...[
              SizedBox(height: 10),
              Wrap(runSpacing: 6, children: [mini('Kounadia IA', ia), mini('Expert', ex), mini('Coup sûr', su)]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _group(String key, String title, List<Forecast> list) {
    final collapsed = _collapsed.contains(key);
    final rows = <Widget>[];
    if (!collapsed) {
      for (var i = 0; i < list.length; i++) {
        if (i > 0) rows.add(Container(height: 1, color: K.border));
        rows.add(ForecastCard(f: list[i], result: true, grouped: true));
      }
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.border),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => collapsed ? _collapsed.remove(key) : _collapsed.add(key)),
          child: Container(
            color: K.groupHead,
            padding: EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              Icon(Icons.emoji_events_outlined, color: K.amber, size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Color(0x3322C55E), borderRadius: BorderRadius.circular(10)),
                child: Text('${list.length} ✓',
                    style: TextStyle(color: K.green, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              Icon(collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, color: K.muted, size: 22),
            ]),
          ),
        ),
        ...rows,
      ]),
    );
  }
}
