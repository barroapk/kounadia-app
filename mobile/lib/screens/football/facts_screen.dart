import '../../widgets/k_err.dart';
import 'package:flutter/material.dart';
import '../../services/primatips_service.dart';
import '../../widgets/forecast_card.dart' show K, kMessage, hm, two;
import '../../widgets/k_ui.dart';
import '../pt_match_screen.dart';
import '../../l10n/tr.dart';

class FactsScreen extends StatefulWidget {
  FactsScreen({super.key});

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
    final labels = ['Hier', "Aujourd'hui", 'Demain'];
    return Scaffold(
      backgroundColor: K.bg,
      appBar: kAppBar('Faits du jour'),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Row(children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
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
                return kMessage(kErr(snap.error), onRetry: () => setState(() => _f = _load()));
              }
              final list = snap.data!;
              if (list.isEmpty) return kMessage('Aucun fait marquant pour cette journée.');
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
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
    final s = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800);
    switch (f.state) {
      case 'live':
        return T(f.status, style: s.copyWith(color: K.red));
      case 'finished':
        return T('Terminé', style: s.copyWith(color: K.muted));
      case 'postponed':
        return T('Reporté', style: s.copyWith(color: K.amber));
    }
    final d = f.date;
    return T(d != null ? hm(d) : f.hour, style: s.copyWith(color: K.indigoText));
  }

  Widget _team(String n, bool win, TextAlign a) => T(n,
      textAlign: a,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: win ? FontWeight.w800 : FontWeight.w600));

  Widget _card(PtFact f) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Material(
        color: K.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: BorderSide(color: K.border)),
        child: InkWell(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => PtMatchScreen(match: f.toMatch()))),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                PtImage(f.flag, w: 20, h: 14),
                SizedBox(width: 8),
                Expanded(
                  child: T('${tr(frName(f.country))} · ${f.league}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                _status(f),
              ]),
              SizedBox(height: 10),
              Row(children: [
                Expanded(child: _team(f.home, f.homeWin, TextAlign.right)),
                Container(
                  width: 58,
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  padding: EdgeInsets.symmetric(vertical: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: f.live ? K.red.withAlpha(40) : K.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: T(f.hasScore ? f.score : 'vs',
                      style: TextStyle(
                          color: f.hasScore ? K.text : K.muted, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                Expanded(child: _team(f.away, f.awayWin, TextAlign.left)),
              ]),
              if (f.facts.isNotEmpty) ...[
                SizedBox(height: 10),
                Container(height: 1, color: K.border),
                ...f.facts.map((t) => Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.lightbulb_outline_rounded, color: K.amber, size: 16),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: T(t, style: TextStyle(color: K.text, fontSize: 13, height: 1.35)),
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
