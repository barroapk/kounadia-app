import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../services/v2_service.dart';
import '../../widgets/forecast_card.dart' show K, kMessage;
import 'v2_widgets.dart' show kV2Unavailable;

String _n(dynamic v) => v == null ? '–' : '$v'.replaceAll('.', ',');

/// Statistiques des championnats (saison en cours) : buts, +2,5, les deux marquent, corners, fautes, cartons.
class LeaguesStatsScreen extends StatefulWidget {
  LeaguesStatsScreen({super.key});

  @override
  State<LeaguesStatsScreen> createState() => _LeaguesStatsScreenState();
}

class _LeaguesStatsScreenState extends State<LeaguesStatsScreen> {
  late Future<List<Map<String, dynamic>>> _f = V2Service.leagues();

  Future<void> _reload() async {
    setState(() => _f = V2Service.leagues());
    try {
      await _f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(backgroundColor: K.bg, foregroundColor: K.text, title: T('Statistiques des championnats', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return Center(child: CircularProgressIndicator(color: K.indigo));
          if (snap.hasError || (snap.data ?? const []).isEmpty) return kMessage(kV2Unavailable, onRetry: _reload);
          final list = snap.data!;
          return RefreshIndicator(
            color: K.indigo,
            onRefresh: _reload,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 40),
              itemCount: list.length,
              separatorBuilder: (_, __) => SizedBox(height: 10),
              itemBuilder: (_, i) {
                final l = list[i];
                return Material(
                  color: K.card,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _LeagueScreen(l))),
                    child: Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: T('${l['country']} - ${l['name']}',
                                style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w900)),
                          ),
                          Icon(Icons.chevron_right_rounded, color: K.muted),
                        ]),
                        SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          _chip('Buts', _n(l['goals'])),
                          _chip('+2,5', '${_n(l['o25'])} %'),
                          _chip('Les deux marquent', '${_n(l['btts'])} %'),
                          _chip('Corners', _n(l['corners'])),
                          _chip('Fautes', _n(l['fouls'])),
                          _chip('Cartons', _n(l['cards'])),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

Widget _chip(String k, String v) => Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        T(k, style: TextStyle(color: K.muted, fontSize: 12)),
        SizedBox(width: 6),
        Text(v, style: TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w900)),
      ]),
    );

/// Détail d'un championnat : moyennes par match et tableau des équipes.
class _LeagueScreen extends StatefulWidget {
  final Map<String, dynamic> l;
  _LeagueScreen(this.l);

  @override
  State<_LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<_LeagueScreen> {
  String _sort = 'pts';
  static const _cols = [
    ('pts', 'Points'),
    ('gf', 'Buts marqués'),
    ('ga', 'Buts encaissés'),
    ('cf', 'Corners'),
    ('f', 'Fautes'),
    ('y', 'Cartons'),
    ('o25', '+2,5 %'),
    ('bt', 'Les deux marquent %'),
    ('cs', 'Sans encaisser %'),
  ];

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final teams = ((l['teams'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList()
      ..sort((a, b) => ((b[_sort] as num?) ?? -1).compareTo((a[_sort] as num?) ?? -1));
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(backgroundColor: K.bg, foregroundColor: K.text, title: T('${l['name']}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      body: ListView(padding: EdgeInsets.fromLTRB(12, 10, 12, 40), children: [
        Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T('Moyennes par match', style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w900)),
            SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _chip('Matchs', _n(l['n'])),
              _chip('Buts', _n(l['goals'])),
              _chip('+2,5', '${_n(l['o25'])} %'),
              _chip('Les deux marquent', '${_n(l['btts'])} %'),
              _chip('Victoire dom.', '${_n(l['home'])} %'),
              _chip('Nul', '${_n(l['draw'])} %'),
              _chip('Victoire ext.', '${_n(l['away'])} %'),
              _chip('Corners', _n(l['corners'])),
              _chip('Fautes', _n(l['fouls'])),
              _chip('Tirs', _n(l['shots'])),
              _chip('Tirs cadrés', _n(l['sot'])),
              _chip('Cartons', _n(l['cards'])),
            ]),
          ]),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final (k, t) in _cols)
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: T(t),
                  selected: _sort == k,
                  onSelected: (_) => setState(() => _sort = k),
                  selectedColor: K.indigoSoft,
                  backgroundColor: K.card,
                  labelStyle: TextStyle(color: _sort == k ? K.indigoText : K.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
                  side: BorderSide(color: K.border),
                  showCheckmark: false,
                ),
              ),
          ]),
        ),
        SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
          child: Column(children: [
            for (var i = 0; i < teams.length; i++) ...[
              if (i > 0) Container(height: 1, color: K.border),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  SizedBox(width: 26, child: Text('${i + 1}', style: TextStyle(color: K.muted, fontSize: 13, fontWeight: FontWeight.w800))),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${teams[i]['team']}', style: TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text(
                          '${teams[i]['n']} ${tr('matchs')} · ${tr('buts')} ${_n(teams[i]['gf'])}-${_n(teams[i]['ga'])} · ${tr('corners')} ${_n(teams[i]['cf'])} · ${tr('fautes')} ${_n(teams[i]['f'])}',
                          style: TextStyle(color: K.muted, fontSize: 11.5)),
                    ]),
                  ),
                  Text(_n(teams[i][_sort]), style: TextStyle(color: K.indigoText, fontSize: 15, fontWeight: FontWeight.w900)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
