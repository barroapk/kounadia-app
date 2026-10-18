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

  /// IA + Expert + Coup sûr (jours passés, jusqu'à 2 semaines).
  Future<HistoryData> _load() async {
    final h = await KounadiaData.history();
    try {
      final v = await VipService.load();
      final legs = [for (final d in v.history.take(15)) ...d.singles];
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
  DateTime? _day; // jour choisi (par défaut : hier)
  String _src = 'all';
  final Set<String> _collapsed = {};

  Future<void> _refresh() async {
    setState(() => _f = _load());
    try {
      await _f;
    } catch (_) {}
  }

  static const _wd = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  static const _wdLong = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

  DateTime _d0(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  String _dayName(DateTime d) => '${_wdLong[d.weekday - 1]} ${d.day}';

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

          final today = _d0(DateTime.now());
          final monday = today.subtract(Duration(days: today.weekday - 1));
          final prevMonday = monday.subtract(Duration(days: 7));
          // Jours affichés : de lundi à hier (aujourd'hui s'affiche demain). Le lundi : hier (dimanche).
          final days = <DateTime>[
            for (var d = monday; d.isBefore(today); d = d.add(Duration(days: 1))) d,
          ];
          if (days.isEmpty) days.add(today.subtract(Duration(days: 1)));
          final played = data.items.where((f) => f.won != null && _d0(f.date).isBefore(today)).toList();
          final wins = played.where((f) => f.won == true).toList();
          final sel = (_day != null && days.any((d) => _same(d, _day!))) ? _day! : days.last;
          final ofDay = wins.where((f) => _same(_d0(f.date), sel)).toList();
          final week = wins.where((f) => !_d0(f.date).isBefore(monday)).toList();
          final lastWeek = wins.where((f) => !_d0(f.date).isBefore(prevMonday) && _d0(f.date).isBefore(monday)).toList();
          final items = ofDay.where((f) => _src == 'all' || f.source == _src).toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          final countOf = {for (final d in days) d: wins.where((f) => _same(_d0(f.date), d)).length};

          final children = <Widget>[
            if (data.offline) kOfflineBanner(),
            _weekCard(week, lastWeek, today.weekday == 1),
            SizedBox(height: 12),
            _daySwitch(days, sel, countOf),
            SizedBox(height: 10),
            _srcChips(ofDay),
            SizedBox(height: 14),
            _hero(ofDay, sel),
            SizedBox(height: 14),
            KndBanner(),
          ];

          if (items.isEmpty) {
            children.addAll([
              SizedBox(height: 30),
              kMessage(ofDay.isEmpty
                  ? "Peu de matchs ce jour-là : rendez-vous sur les prochains jours pour de nouveaux pronostics gagnants."
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
                ..add(_group('${sel.toIso8601String()}|$_src|${e.key}', e.key, e.value))
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

  /// Bilan de la semaine en cours (remis à zéro chaque lundi) + semaine précédente.
  Widget _weekCard(List<Forecast> week, List<Forecast> lastWeek, bool isMonday) {
    final n = week.length;
    final p = lastWeek.length;
    Widget stat(String label, String value, String sub) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
            SizedBox(height: 4),
            Text(value, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            Text(sub, style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12)),
          ]),
        );
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Bilan de la semaine', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        ]),
        SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          stat('Cette semaine', isMonday ? '0' : '$n', isMonday ? 'nouveau départ ce lundi 🚀' : 'pronostic${n > 1 ? 's' : ''} validé${n > 1 ? 's' : ''}'),
          Container(width: 1, height: 52, color: Color(0x44FFFFFF), margin: EdgeInsets.symmetric(horizontal: 12)),
          stat('Semaine dernière', '$p', 'pronostic${p > 1 ? 's' : ''} validé${p > 1 ? 's' : ''}'),
        ]),
      ]),
    );
  }

  Widget _daySwitch(List<DateTime> days, DateTime sel, Map<DateTime, int> counts) {
    final yesterday = _d0(DateTime.now()).subtract(Duration(days: 1));
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        children: [
          for (final d in days.reversed)
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => setState(() => _day = d),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 160),
                  width: 74,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _same(d, sel) ? K.indigo : K.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _same(d, sel) ? K.indigo : K.border),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_same(d, yesterday) ? 'Hier' : '${_wd[d.weekday - 1]} ${d.day}',
                        style: TextStyle(color: _same(d, sel) ? Colors.white : K.text, fontSize: 13, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('${counts[d] ?? 0} ✓',
                        style: TextStyle(color: _same(d, sel) ? Color(0xDDFFFFFF) : K.green, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
        ],
      ),
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

  Widget _hero(List<Forecast> list, DateTime day) {
    final n = list.length;
    final s = n > 1 ? 's' : '';
    final ia = list.where((f) => f.source == 'ia').length;
    final ex = list.where((f) => f.source == 'expert').length;
    final su = list.where((f) => f.source == 'sure').length;
    final isYesterday = _same(day, _d0(DateTime.now()).subtract(Duration(days: 1)));
    final when = isYesterday ? "d'hier" : 'du ${_dayName(day)}';
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
            Text(n == 0 ? 'Journée calme' : '$n pronostic$s validé$s',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text(
              n == 0
                  ? 'Peu de matchs au programme $when. Les prochains jours apportent de nouvelles chances !'
                  : n < 10
                      ? 'Avec peu de matchs au programme $when, nos prédictions ont tout de même validé $n pronostic$s. 💪'
                      : 'Kounadia IA, Expert et Coup sûr : $n pronostic$s validé$s $when. 🔥',
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
