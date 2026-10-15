import 'package:flutter/material.dart';
import '../models/forecast.dart';
import '../services/kounadia_data_service.dart';
import '../widgets/forecast_card.dart';

class TipHistoryScreen extends StatefulWidget {
  const TipHistoryScreen({super.key});

  @override
  State<TipHistoryScreen> createState() => _TipHistoryScreenState();
}

class _TipHistoryScreenState extends State<TipHistoryScreen> {
  late Future<HistoryData> _f = KounadiaData.history();
  String _period = 'all';
  String _src = 'all';
  String _res = 'all';

  Future<void> _refresh() async {
    setState(() => _f = KounadiaData.history());
    try {
      await _f;
    } catch (_) {}
  }

  int _dayDiff(DateTime d) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
  }

  String _dayLabel(DateTime d) {
    switch (_dayDiff(d)) {
      case 0:
        return "Aujourd'hui";
      case 1:
        return 'Hier';
      case 2:
        return 'Avant-hier';
      default:
        return frDay(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      body: FutureBuilder<HistoryData>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: K.indigo));
          }
          if (snap.hasError) {
            return kMessage(snap.error.toString(), onRetry: _refresh);
          }
          final data = snap.data!;
          final items = data.items.where((f) {
            final dd = _dayDiff(f.date);
            final okPeriod = _period == 'all' ? dd <= 2 : dd == int.parse(_period);
            final okSrc = _src == 'all' || f.source == _src;
            final okRes = _res == 'all' || (_res == 'won') == (f.won == true);
            return okPeriod && okSrc && okRes;
          }).toList();

          final children = <Widget>[
            if (data.offline) kOfflineBanner(),
            _chips([('all', '3 jours'), ('0', "Aujourd'hui"), ('1', 'Hier'), ('2', 'Avant-hier')],
                _period, (v) => _period = v),
            const SizedBox(height: 8),
            _chips([('all', 'Toutes sources'), ('ia', 'Kounadia IA'), ('expert', 'Expert')],
                _src, (v) => _src = v),
            const SizedBox(height: 8),
            _chips([('all', 'Tous'), ('won', 'Validés'), ('lost', 'Perdus')], _res, (v) => _res = v),
            const SizedBox(height: 14),
            _perf(items),
          ];

          if (items.isEmpty) {
            children.addAll([
              const SizedBox(height: 40),
              kMessage('Aucun résultat pour ces filtres.'),
            ]);
          } else {
            String? day;
            for (final f in items) {
              final label = _dayLabel(f.date);
              if (label != day) {
                day = label;
                children.add(Padding(
                  padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
                  child: Text(label,
                      style: const TextStyle(
                          color: K.text, fontSize: 17, fontWeight: FontWeight.w800)),
                ));
              }
              children
                ..add(ForecastCard(f: f, result: true))
                ..add(const SizedBox(height: 14));
            }
          }

          return RefreshIndicator(
            color: K.indigo,
            backgroundColor: K.card,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: children,
            ),
          );
        },
      ),
    );
  }

  Widget _chips(List<(String, String)> opts, String selected, void Function(String) onPick) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in opts)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => onPick(value)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected == value ? K.indigo : K.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected == value ? K.indigo : K.border),
                  ),
                  child: Text(label,
                      style: TextStyle(
                        color: selected == value ? Colors.white : K.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: K.muted, fontSize: 13)),
      ],
    );
  }

  Widget _perf(List<Forecast> list) {
    final total = list.length;
    final won = list.where((f) => f.won == true).length;
    final rate = total == 0 ? 0.0 : won / total;
    final c = rate >= 0.6 ? K.green : rate >= 0.45 ? K.amber : K.red;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: K.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TAUX DE RÉUSSITE',
                        style: TextStyle(
                            color: K.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(total == 0 ? 'Aucun résultat' : '$won validés sur $total',
                        style: const TextStyle(
                            color: K.text, fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Text(total == 0 ? '—' : '${(rate * 100).round()} %',
                  style: TextStyle(color: c, fontSize: 30, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 10,
              backgroundColor: const Color(0x33EF4444),
              color: c,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legend(K.green, '$won validés'),
              const SizedBox(width: 18),
              _legend(K.red, '${total - won} perdus'),
            ],
          ),
        ],
      ),
    );
  }
}
