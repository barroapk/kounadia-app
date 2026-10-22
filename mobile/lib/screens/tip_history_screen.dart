import 'package:flutter/material.dart';
import '../models/forecast.dart';
import '../services/kounadia_data_service.dart';
import '../services/vip_service.dart';
import 'sure_tab.dart' show sureForecast;
import '../widgets/forecast_card.dart';
import '../widgets/knd_banner.dart';
import '../l10n/tr.dart';

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
        if ((l.result == 'won' || l.result == 'lost') && seen.add(l.id)) extra.add(sureForecast(l));
      }
      return HistoryData([...h.items, ...extra], h.offline);
    } catch (_) {
      return h;
    }
  }
  DateTime? _day; // jour choisi (par défaut : hier)
  String _src = 'all';
  bool _showLost = false; // onglet « Perdus »
  final Set<String> _collapsed = {};

  Future<void> _refresh() async {
    setState(() => _f = _load());
    try {
      await _f;
    } catch (_) {}
  }


  DateTime _d0(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

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
          // Tous les pronostics terminés (gagnés ET perdus) : le pourcentage est honnête.
          final played = data.items.where((f) => f.won != null && _d0(f.date).isBefore(today)).toList();
          final sel = (_day != null && days.any((d) => _same(d, _day!))) ? _day! : days.last;
          final ofDay = played.where((f) => _same(_d0(f.date), sel)).toList();
          final week = played.where((f) => !_d0(f.date).isBefore(monday)).toList();
          final lastWeek = played.where((f) => !_d0(f.date).isBefore(prevMonday) && _d0(f.date).isBefore(monday)).toList();
          final ofSrc = ofDay.where((f) => _src == 'all' || f.source == _src).toList();
          final won = ofSrc.where((f) => f.won == true).toList();
          final lost = ofSrc.where((f) => f.won == false).toList();
          final items = [...(_showLost ? lost : won)]..sort((a, b) => a.date.compareTo(b.date));
          final countOf = {
            for (final d in days)
              d: (
                played.where((f) => f.won == true && _same(_d0(f.date), d)).length,
                played.where((f) => _same(_d0(f.date), d)).length,
              ),
          };

          final children = <Widget>[
            if (data.offline) kOfflineBanner(),
            _weekCard(week, lastWeek, today.weekday == 1),
            SizedBox(height: 12),
            _daySwitch(days, sel, countOf),
            SizedBox(height: 10),
            _srcChips(ofDay),
            SizedBox(height: 14),
            _gauge(won.length, ofSrc.length, sel),
            SizedBox(height: 12),
            _wonLostSwitch(won.length, lost.length),
            SizedBox(height: 12),
            KndBanner(),
          ];

          if (items.isEmpty) {
            children.addAll([
              SizedBox(height: 30),
              kMessage(ofSrc.isEmpty
                  ? 'Aucun pronostic terminé ce jour-là pour cette source.'
                  : _showLost
                      ? 'Aucun pronostic perdu ce jour-là.'
                      : 'Aucun pronostic gagné ce jour-là.'),
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
                ..add(_group('${sel.toIso8601String()}|$_src|$_showLost|${e.key}', e.key, e.value))
                ..add(SizedBox(height: 10));
              rows += e.value.length;
              if (rows ~/ 10 > block) {
                block = rows ~/ 10;
                children.add(KndBanner(afterCards: block * 10, total: items.length));
              }
            }
          }

          children.add(Padding(
            padding: EdgeInsets.only(top: 10),
            child: T(kHonest, textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11.5, height: 1.4)),
          ));

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

  String _pct(int w, int n) => n == 0 ? '–' : '${(w * 100 / n).round()} %';

  /// Bilan de la semaine en cours (remis à zéro chaque lundi) + semaine précédente : gagnés sur terminés.
  Widget _weekCard(List<Forecast> week, List<Forecast> lastWeek, bool isMonday) {
    final w = week.where((f) => f.won == true).length, n = week.length;
    final pw = lastWeek.where((f) => f.won == true).length, pn = lastWeek.length;
    Widget stat(String label, String value, String sub) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T(tr(label).toUpperCase(),
                style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
            SizedBox(height: 4),
            T(value, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            T(sub, style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12)),
          ]),
        );
    String sub(int w, int n) => '$w ${tr('gagnés sur')} $n';
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
          T('Bilan de la semaine', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        ]),
        SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          stat('Cette semaine', isMonday ? '–' : _pct(w, n), isMonday ? tr('nouveau départ ce lundi') : sub(w, n)),
          Container(width: 1, height: 52, color: Color(0x44FFFFFF), margin: EdgeInsets.symmetric(horizontal: 12)),
          stat('Semaine dernière', _pct(pw, pn), sub(pw, pn)),
        ]),
      ]),
    );
  }

  Widget _daySwitch(List<DateTime> days, DateTime sel, Map<DateTime, (int, int)> counts) {
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
                    T(_same(d, yesterday) ? 'Hier' : '${dayName(d.weekday)} ${d.day}',
                        style: TextStyle(color: _same(d, sel) ? Colors.white : K.text, fontSize: 13, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    T('${counts[d]?.$1 ?? 0}/${counts[d]?.$2 ?? 0} ✓',
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
                    child: T('${tr(label)} · $count',
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

  /// Jauge honnête : gagnés sur l'ensemble des pronostics terminés du jour.
  Widget _gauge(int w, int n, DateTime day) {
    final l = n - w;
    final p = n == 0 ? 0.0 : w / n;
    final isYesterday = _same(day, _d0(DateTime.now()).subtract(Duration(days: 1)));
    final when = isYesterday ? tr('Hier') : '${dayName(day.weekday)} ${day.day}';
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: K.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          T(n == 0 ? '–' : '${(p * 100).round()} %',
              style: TextStyle(color: K.text, fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
          SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: T('${tr('de pronostics gagnés')} · $when',
                  style: TextStyle(color: K.muted, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
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
        T(
          n == 0
              ? tr('Aucun pronostic terminé ce jour-là.')
              : '${tr('Sur')} $n ${tr('pronostics terminés')} : $w ${tr('gagnés')}, $l ${tr('perdus')}.',
          style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }

  /// Onglets « Gagnés » / « Perdus » : tout est visible, rien n'est caché.
  Widget _wonLostSwitch(int w, int l) {
    Widget half(String label, int count, bool lostTab, Color c) {
      final sel = _showLost == lostTab;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _showLost = lostTab),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 150),
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? c.withValues(alpha: 0.18) : K.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? c : K.border),
            ),
            child: T('${tr(label)} · $count',
                style: TextStyle(color: sel ? c : K.muted, fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }

    return Row(children: [
      half('Gagnés', w, false, K.green),
      SizedBox(width: 8),
      half('Perdus', l, true, K.red),
    ]);
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
              Icon(_showLost ? Icons.cancel_outlined : Icons.emoji_events_outlined, color: _showLost ? K.red : K.amber, size: 15),
              SizedBox(width: 8),
              Expanded(
                child: T(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: _showLost ? Color(0x33EF4444) : Color(0x3322C55E), borderRadius: BorderRadius.circular(10)),
                child: T('${list.length} ${_showLost ? '✗' : '✓'}',
                    style: TextStyle(color: _showLost ? K.red : K.green, fontSize: 12, fontWeight: FontWeight.w800)),
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
