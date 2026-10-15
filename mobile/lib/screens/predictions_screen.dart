import 'package:flutter/material.dart';
import '../models/forecast.dart';
import '../services/kounadia_data_service.dart';
import '../widgets/forecast_card.dart';

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  late Future<TodayData> _f = KounadiaData.today();

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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: K.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: K.border),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: K.indigo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: K.muted,
                  labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
                  if (snap.hasError) {
                    return kMessage(snap.error.toString(), onRetry: _refresh);
                  }
                  final d = snap.data!;
                  return TabBarView(
                    children: [
                      _list(d.ia, d.offline, "Aucun pronostic Kounadia IA pour aujourd'hui."),
                      _list(d.expert, d.offline, "Aucun pronostic Expert pour aujourd'hui."),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Forecast> items, bool offline, String empty) {
    final children = <Widget>[
      if (offline) kOfflineBanner(),
      if (items.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(
            "${items.length} pronostic${items.length > 1 ? 's' : ''} aujourd'hui",
            style: const TextStyle(color: K.muted, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
    ];
    if (items.isEmpty) {
      children.addAll([const SizedBox(height: 80), kMessage(empty)]);
    } else {
      for (final f in items) {
        children
          ..add(ForecastCard(f: f))
          ..add(const SizedBox(height: 14));
      }
    }
    return RefreshIndicator(
      color: K.indigo,
      backgroundColor: K.card,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: children,
      ),
    );
  }
}
