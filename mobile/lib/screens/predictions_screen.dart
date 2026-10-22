import 'dart:async';
import 'package:flutter/material.dart';
import '../models/forecast.dart';
import '../services/kounadia_data_service.dart';
import '../widgets/forecast_card.dart';
import '../widgets/knd_banner.dart';
import 'sure_tab.dart';
import '../l10n/tr.dart';

class PredictionsScreen extends StatefulWidget {
  PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  late Future<TodayData> _f = KounadiaData.today();
  final Set<String> _collapsed = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(minutes: 1), (_) {
      final nf = KounadiaData.today();
      nf.then((_) {
        if (mounted) setState(() => _f = nf);
      }).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _f = KounadiaData.today());
    try {
      await _f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: K.bg,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: K.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: K.border),
                ),
                child: TabBar(
                  indicator: BoxDecoration(color: K.indigo, borderRadius: BorderRadius.circular(9)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: EdgeInsets.all(3),
                  labelPadding: EdgeInsets.zero,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: K.muted,
                  labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                  tabs: [Tab(text: tr('Kounadia IA')), Tab(text: tr('Expert')), Tab(text: tr('Coup sûr'))],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(children: [_tab(true), _tab(false), SureTab()]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(bool ia) => FutureBuilder<TodayData>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return Center(child: CircularProgressIndicator(color: K.indigo));
          }
          if (snap.hasError && !snap.hasData) return kMessage(snap.error.toString(), onRetry: _refresh);
          final d = snap.data!;
          return ia
              ? _list('ia', d.ia, d.offline, "Aucun pronostic Kounadia IA pour aujourd'hui.", d.iaDay)
              : _list('ex', d.expert, d.offline, "Aucun pronostic Expert pour aujourd'hui.", d.exDay);
        },
      );

  Widget _group(String key, String title, List<Forecast> list) {
    final collapsed = _collapsed.contains(key);
    final rows = <Widget>[];
    if (!collapsed) {
      for (var i = 0; i < list.length; i++) {
        if (i > 0) rows.add(Container(height: 1, color: K.border));
        rows.add(ForecastCard(f: list[i], grouped: true, result: list[i].won != null));
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
                child: T(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              T('${list.length}', style: TextStyle(color: K.muted, fontSize: 12)),
              Icon(collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, color: K.muted, size: 22),
            ]),
          ),
        ),
        ...rows,
      ]),
    );
  }

  Widget _list(String tab, List<Forecast> items, bool offline, String empty, DateTime? day) {
    final children = <Widget>[
      if (offline) kOfflineBanner(),
      if (day != null && items.isNotEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: T('Pronostics du ${two(day.day)}/${two(day.month)} · les nouveaux arrivent bientôt',
              style: TextStyle(color: K.amber, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
    ];
    if (items.isEmpty) {
      children.addAll([KndBanner(), SizedBox(height: 50), kMessage(empty)]);
    } else {
      final sorted = [...items]..sort((a, b) => a.date.compareTo(b.date));
      final groups = <String, List<Forecast>>{};
      for (final f in sorted) {
        groups.putIfAbsent(f.league.isEmpty ? 'Autres compétitions' : f.league, () => []).add(f);
      }
      children.add(Padding(
        padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
        child: T(
          "${items.length} pronostic${items.length > 1 ? 's' : ''} · ${groups.length} compétition${groups.length > 1 ? 's' : ''}",
          style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ));
      if (tab == 'ia') children.add(_scoreNote());
      children.add(KndBanner());
      var rows = 0;
      var block = 0;
      for (final e in groups.entries) {
        children
          ..add(_group('$tab|${e.key}', e.key, e.value))
          ..add(SizedBox(height: 10));
        rows += e.value.length;
        if (rows ~/ 10 > block) {
          block = rows ~/ 10;
          children.add(KndBanner(afterCards: block * 10, total: items.length));
        }
      }
    }
    children.add(Padding(
      padding: EdgeInsets.only(top: 8),
      child: T(kHonest, textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11.5, height: 1.4)),
    ));
    return RefreshIndicator(
      color: K.indigo,
      backgroundColor: K.card,
      onRefresh: _refresh,
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12, 0, 12, 96),
        children: children,
      ),
    );
  }

  /// Le pronostic = la ligne en couleur ; le score de l'IA n'est qu'une indication.
  Widget _scoreNote() => Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: K.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: K.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, color: K.indigoText, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: T(
              "Le pronostic, c'est la ligne en couleur (ex. « Victoire Arsenal »). Le score indicatif n'est pas un pari sur le score exact : c'est une information pour t'aider à analyser le match.",
              style: TextStyle(color: K.text, fontSize: 12.5, height: 1.4),
            ),
          ),
        ]),
      );
}
