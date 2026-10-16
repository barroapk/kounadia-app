import 'package:flutter/material.dart';
import '../models/forecast.dart';
import '../services/kounadia_data_service.dart';
import '../widgets/forecast_card.dart';
import '../widgets/knd_banner.dart';

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  late Future<TodayData> _f = KounadiaData.today();
  final Set<String> _collapsed = {};

  Future<void> _refresh() async {
    setState(() => _f = KounadiaData.today());
    try {
      await _f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: K.bg,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                  indicatorPadding: const EdgeInsets.all(3),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: K.muted,
                  labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  tabs: const [Tab(text: 'Kounadia IA'), Tab(text: 'Expert')],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<TodayData>(
                future: _f,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: K.indigo));
                  }
                  if (snap.hasError) return kMessage(snap.error.toString(), onRetry: _refresh);
                  final d = snap.data!;
                  return TabBarView(children: [
                    _list('ia', d.ia, d.offline, "Aucun pronostic Kounadia IA pour aujourd'hui."),
                    _list('ex', d.expert, d.offline, "Aucun pronostic Expert pour aujourd'hui."),
                  ]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(String key, String title, List<Forecast> list) {
    final collapsed = _collapsed.contains(key);
    final rows = <Widget>[];
    if (!collapsed) {
      for (var i = 0; i < list.length; i++) {
        if (i > 0) rows.add(Container(height: 1, color: K.border));
        rows.add(ForecastCard(f: list[i], grouped: true));
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
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              const Icon(Icons.emoji_events_outlined, color: K.amber, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text('${list.length}', style: const TextStyle(color: K.muted, fontSize: 12)),
              Icon(collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, color: K.muted, size: 22),
            ]),
          ),
        ),
        ...rows,
      ]),
    );
  }

  Widget _list(String tab, List<Forecast> items, bool offline, String empty) {
    final children = <Widget>[if (offline) kOfflineBanner()];
    if (items.isEmpty) {
      children.addAll([const KndBanner(), const SizedBox(height: 50), kMessage(empty)]);
    } else {
      final sorted = [...items]..sort((a, b) => a.date.compareTo(b.date));
      final groups = <String, List<Forecast>>{};
      for (final f in sorted) {
        groups.putIfAbsent(f.league.isEmpty ? 'Autres compétitions' : f.league, () => []).add(f);
      }
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
        child: Text(
          "${items.length} pronostic${items.length > 1 ? 's' : ''} · ${groups.length} compétition${groups.length > 1 ? 's' : ''}",
          style: const TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ));
      children.add(const KndBanner());
      var rows = 0;
      var block = 0;
      for (final e in groups.entries) {
        children
          ..add(_group('$tab|${e.key}', e.key, e.value))
          ..add(const SizedBox(height: 10));
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
        children: children,
      ),
    );
  }
}
