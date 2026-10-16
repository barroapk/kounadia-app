import 'package:flutter/material.dart';
import '../../services/primatips_service.dart';
import '../../widgets/forecast_card.dart' show K, kMessage, hm, two;
import '../../widgets/k_ui.dart';
import '../pt_match_screen.dart';

class FactsScreen extends StatefulWidget {
  const FactsScreen({super.key});

  @override
  State<FactsScreen> createState() => _FactsScreenState();
}

class _FactsScreenState extends State<FactsScreen> {
  int _off = 0;
  late Future<List<PtFact>> _f = _load();

  String _day() {
    final d = DateTime.now().toUtc().add(Duration(days: _off));
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<List<PtFact>> _load() => PrimaTipsService.facts(_day(), today: _off == 0);

  void _go(int off) {
    if (off == _off) return;
    setState(() {
      _off = off;
      _f = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Hier', "Aujourd'hui", 'Demain'];
    return Scaffold(
      backgroundColor: K.bg,
      appBar: kAppBar('Faits du jour'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Row(children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: kPill(labels[i], _off == i - 1, () => _go(i - 1)),
                ),
              ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<PtFact>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return kLoader();
              if (snap.hasError) {
                return kMessage(snap.error.toString(), onRetry: () => setState(() => _f = _load()));
              }
              final list = snap.data!;
              if (list.isEmpty) return kMessage('Aucun fait marquant pour cette journée.');
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: list.length,
                itemBuilder: (_, i) => _card(list[i]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _status(PtFact f) {
    const s = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800);
    switch (f.state) {
      case 'live':
        return Text(f.status, style: s.copyWith(color: K.red));
      case 'finished':
        return Text('Terminé', style: s.copyWith(color: K.muted));
      case 'postponed':
        return Text('Reporté', style: s.copyWith(color: K.amber));
    }
    final d = f.date;
    return Text(d != null ? hm(d) : f.hour, style: s.copyWith(color: K.indigoText));
  }

  Widget _team(String n, bool win, TextAlign a) => Text(n,
      textAlign: a,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: win ? FontWeight.w800 : FontWeight.w600));

  Widget _card(PtFact f) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: K.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: const BorderSide(color: K.border)),
        child: InkWell(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => PtMatchScreen(match: f.toMatch()))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                PtImage(f.flag, w: 20, h: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${frName(f.country)} · ${f.league}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                _status(f),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _team(f.home, f.homeWin, TextAlign.right)),
                Container(
                  width: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: f.live ? K.red.withAlpha(40) : K.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(f.hasScore ? f.score : 'vs',
                      style: TextStyle(
                          color: f.hasScore ? K.text : K.muted, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                Expanded(child: _team(f.away, f.awayWin, TextAlign.left)),
              ]),
              if (f.facts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(height: 1, color: K.border),
                ...f.facts.map((t) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.lightbulb_outline_rounded, color: K.amber, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t, style: const TextStyle(color: K.text, fontSize: 13, height: 1.35)),
                        ),
                      ]),
                    )),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
