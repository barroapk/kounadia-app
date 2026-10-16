import 'package:flutter/material.dart';
import '../models/live_match.dart';
import '../services/match_detail_service.dart';
import '../services/analytics.dart';
import '../services/logo_cache.dart';
import '../widgets/forecast_card.dart' show K, kMessage, hm;
import '../widgets/jersey.dart';

class PtMatchScreen extends StatefulWidget {
  final LiveMatch match;
  PtMatchScreen({super.key, required this.match});

  @override
  State<PtMatchScreen> createState() => _PtMatchScreenState();
}

class _PtMatchScreenState extends State<PtMatchScreen> {
  late Future<MatchDetail> _f = MatchDetailService.load(widget.match);

  @override
  void initState() {
    super.initState();
    Analytics.log('match_open', {'league': widget.match.leagueLabel});
  }

  LiveMatch get m => widget.match;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: K.bg,
        appBar: AppBar(
          backgroundColor: K.bg,
          foregroundColor: K.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(m.leagueLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        body: FutureBuilder<MatchDetail>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator(color: K.indigo));
            }
            if (snap.hasError) {
              return kMessage(snap.error.toString(),
                  onRetry: () => setState(() => _f = MatchDetailService.load(m)));
            }
            final d = snap.data!;
            return Column(
              children: [
                Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 10), child: _header(d)),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: K.indigo,
                  indicatorWeight: 3,
                  labelColor: K.text,
                  unselectedLabelColor: K.muted,
                  dividerColor: K.border,
                  labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  tabs: [
                    Tab(text: 'Pronostics'),
                    Tab(text: 'Forme'),
                    Tab(text: 'H2H'),
                    Tab(text: 'Classement'),
                    Tab(text: 'Stats'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _tipsTab(d),
                      _formTab(d),
                      _h2hTab(d),
                      _tableTab(d),
                      _statsTab(d),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------- Éléments communs ----------

  Widget _list(List<Widget> children) => ListView(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: children,
      );

  Widget _title(String t) => Padding(
        padding: EdgeInsets.fromLTRB(2, 6, 2, 10),
        child: Text(t.toUpperCase(),
            style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
      );

  BoxDecoration get _box => BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.border),
      );

  String _d(String iso) {
    final p = iso.trim().split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0].substring(2)}' : iso;
  }

  Color _oc(String? o) => o == 'win'
      ? K.green
      : o == 'draw'
          ? K.amber
          : o == 'loss'
              ? K.red
              : K.border;

  String _ol(String? o) => o == 'win'
      ? 'V'
      : o == 'draw'
          ? 'N'
          : o == 'loss'
              ? 'D'
              : '';

  Widget _badge(String? o) => Container(
        width: 22,
        height: 22,
        margin: EdgeInsets.only(left: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _oc(o), borderRadius: BorderRadius.circular(6)),
        child: Text(_ol(o),
            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
      );

  Widget _gameRow(GameRow g) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 62, child: Text(_d(g.date), style: TextStyle(color: K.muted, fontSize: 11.5))),
          Expanded(
            child: Text(g.home,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: K.text, fontSize: 13, fontWeight: g.homeBold ? FontWeight.w800 : FontWeight.w500)),
          ),
          Container(
            width: 52,
            margin: EdgeInsets.symmetric(horizontal: 8),
            padding: EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: g.outcome == null ? Colors.transparent : _oc(g.outcome).withAlpha(45),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _oc(g.outcome).withAlpha(140)),
            ),
            child: Text(g.score,
                style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Text(g.away,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: K.text, fontSize: 13, fontWeight: g.awayBold ? FontWeight.w800 : FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _games(List<GameRow> list) {
    final rows = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      if (i > 0) rows.add(Container(height: 1, color: K.border));
      rows.add(_gameRow(list[i]));
    }
    return Container(decoration: _box, clipBehavior: Clip.antiAlias, child: Column(children: rows));
  }

  // ---------- En-tête ----------

  Widget _teamCol(String name, String? logo) => Column(
        children: [
          TeamCrest(name: name, logo: logo ?? LogoCache.get(name), size: 48),
          SizedBox(height: 8),
          Text(name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _header(MatchDetail d) {
    String center;
    if (d.liveScore != null && d.liveScore!.contains('-')) {
      center = d.liveScore!;
    } else if (m.hs != null && m.as_ != null) {
      center = '${m.hs} - ${m.as_}';
    } else {
      center = m.date != null ? hm(m.date!) : '--:--';
    }
    String status;
    Color sc;
    switch (m.status) {
      case 'live':
        status = (d.liveStatus?.isNotEmpty ?? false) ? d.liveStatus! : (m.minute ?? 'En direct');
        sc = K.red;
        break;
      case 'finished':
        status = 'Terminé';
        sc = K.muted;
        break;
      case 'postponed':
        status = 'Reporté';
        sc = K.amber;
        break;
      default:
        status = 'À venir';
        sc = K.pending;
    }
    return Container(
      padding: EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: K.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _teamCol(m.home, d.homeLogo)),
          SizedBox(
            width: 96,
            child: Column(children: [
              SizedBox(height: 10),
              FittedBox(
                child: Text(center,
                    style: TextStyle(color: K.text, fontSize: 26, fontWeight: FontWeight.w800)),
              ),
              SizedBox(height: 6),
              Text(status,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: sc, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(child: _teamCol(m.away, d.awayLogo)),
        ],
      ),
    );
  }

  // ---------- Onglet Pronostics ----------

  Widget _tipsTab(MatchDetail d) {
    if (d.markets.isEmpty) return kMessage('Aucun pronostic détaillé pour ce match.');
    return _list([
      ...d.markets.map(_market),
      if (d.updated != null)
        Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Cotes moyennes avant-match · mise à jour ${d.updated}',
              style: TextStyle(color: K.muted, fontSize: 11.5)),
        ),
    ]);
  }

  Widget _market(Market x) {
    final c = x.status == 'won'
        ? K.green
        : x.status == 'lost'
            ? K.red
            : K.pending;
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _box,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(x.nameFr, style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(x.pickFr(m.home, m.away),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (x.odd.isNotEmpty)
                Text('@ ${x.odd}', style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w800)),
              if (x.prob != null) Text('${x.prob} %', style: TextStyle(color: K.muted, fontSize: 12.5)),
            ],
          ),
          if (x.status != 'pending')
            Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(x.status == 'won' ? Icons.check_circle_rounded : Icons.cancel_rounded, color: c, size: 22),
            ),
        ],
      ),
    );
  }

  // ---------- Onglet Forme ----------

  Widget _formHeader(String name, String? logo, List<GameRow> list) {
    final last5 = list.take(5).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          TeamCrest(name: name, logo: logo ?? LogoCache.get(name), size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          ...last5.map((g) => _badge(g.outcome)),
        ],
      ),
    );
  }

  Widget _formTab(MatchDetail d) {
    if (d.homeForm.isEmpty && d.awayForm.isEmpty) return kMessage('Forme indisponible pour ce match.');
    return _list([
      _formHeader(m.home, d.homeLogo, d.homeForm),
      if (d.homeForm.isNotEmpty) _games(d.homeForm),
      SizedBox(height: 22),
      _formHeader(m.away, d.awayLogo, d.awayForm),
      if (d.awayForm.isNotEmpty) _games(d.awayForm),
      if (d.homeNext.isNotEmpty || d.awayNext.isNotEmpty) ...[
        SizedBox(height: 22),
        _title('Prochains matchs'),
        if (d.homeNext.isNotEmpty) _games(d.homeNext),
        SizedBox(height: 10),
        if (d.awayNext.isNotEmpty) _games(d.awayNext),
      ],
    ]);
  }

  // ---------- Onglet H2H ----------

  Widget _h2hTab(MatchDetail d) {
    if (d.h2h.isEmpty) return kMessage('Aucune confrontation récente entre ces deux équipes.');
    final w = d.h2h.where((g) => g.outcome == 'win').length;
    final n = d.h2h.where((g) => g.outcome == 'draw').length;
    final l = d.h2h.where((g) => g.outcome == 'loss').length;
    final total = (w + n + l) == 0 ? 1 : (w + n + l);
    Widget seg(int v, Color c) => v == 0 ? SizedBox.shrink() : Expanded(flex: v, child: Container(height: 8, color: c));
    Widget cnt(String label, int v, Color c, CrossAxisAlignment a) => Column(
          crossAxisAlignment: a,
          children: [
            Text('$v', style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.muted, fontSize: 12)),
          ],
        );
    return _list([
      Container(
        padding: EdgeInsets.all(16),
        decoration: _box,
        child: Column(children: [
          Row(children: [
            Expanded(child: cnt(m.home, w, K.green, CrossAxisAlignment.start)),
            Expanded(child: cnt('Nuls', n, K.amber, CrossAxisAlignment.center)),
            Expanded(child: cnt(m.away, l, K.red, CrossAxisAlignment.end)),
          ]),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: total == 0 ? SizedBox.shrink() : Row(children: [seg(w, K.green), seg(n, K.amber), seg(l, K.red)]),
          ),
        ]),
      ),
      SizedBox(height: 16),
      _title('${d.h2h.length} dernières confrontations'),
      _games(d.h2h),
    ]);
  }

  // ---------- Onglet Classement ----------

  Widget _tableTab(MatchDetail d) {
    if (d.table.isEmpty) return kMessage('Classement indisponible pour cette compétition.');
    final palette = [K.green, K.indigo, Color(0xFF06B6D4), K.amber, Color(0xFFA855F7)];
    final zones = <String, Color>{};
    for (final r in d.table) {
      if (r.zone.isEmpty || zones.containsKey(r.zone)) continue;
      zones[r.zone] = RegExp(r'releg', caseSensitive: false).hasMatch(r.zone)
          ? K.red
          : palette[zones.length % palette.length];
    }
    final hs = TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w700);
    Widget cell(String t, double w, TextStyle s) => SizedBox(width: w, child: Text(t, textAlign: TextAlign.center, style: s));

    final rows = <Widget>[
      Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(children: [
          cell('#', 26, hs),
          Expanded(child: Text('Équipe', style: hs)),
          cell('J', 28, hs),
          cell('Diff', 38, hs),
          cell('Pts', 34, hs),
        ]),
      ),
    ];
    for (final r in d.table) {
      final mine = r.team == m.home || r.team == m.away;
      final ts = TextStyle(color: K.text, fontSize: 13, fontWeight: mine ? FontWeight.w800 : FontWeight.w500);
      rows.add(Container(height: 1, color: K.border));
      rows.add(Container(
        color: mine ? Color(0x264F46E5) : null,
        padding: EdgeInsets.fromLTRB(0, 8, 12, 8),
        child: Row(children: [
          Container(width: 4, height: 20, color: zones[r.zone] ?? Colors.transparent),
          SizedBox(width: 8),
          cell('${r.pos}', 26, ts),
          Expanded(child: Text(r.team, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts)),
          cell(r.mp, 28, ts),
          cell(r.diff, 38, ts),
          cell(r.pts, 34, ts.copyWith(fontWeight: FontWeight.w800)),
        ]),
      ));
    }
    return _list([
      _title(d.tableTitle.isEmpty ? 'Classement' : d.tableTitle),
      Container(decoration: _box, clipBehavior: Clip.antiAlias, child: Column(children: rows)),
      if (zones.isNotEmpty) ...[
        SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: zones.entries
              .map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(2))),
                    SizedBox(width: 6),
                    Text(e.key, style: TextStyle(color: K.muted, fontSize: 12)),
                  ]))
              .toList(),
        ),
      ],
    ]);
  }

  // ---------- Onglet Stats ----------

  double? _num(String s) => double.tryParse(s.replaceAll('%', '').replaceAll(',', '.').trim());

  Widget _statRow(StatRow s) {
    final a = _num(s.a);
    final b = _num(s.b);
    final sum = (a ?? 0) + (b ?? 0);
    final ra = sum > 0 && a != null ? (a / sum * 1000).round() : 1;
    final rb = sum > 0 && b != null ? (b / sum * 1000).round() : 1;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Column(children: [
        Row(children: [
          Text(s.a, style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
          Expanded(
            child: Text(s.label,
                textAlign: TextAlign.center,
                style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          Text(s.b, style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
        ]),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(children: [
            Expanded(flex: ra == 0 ? 1 : ra, child: Container(height: 5, color: K.indigo)),
            SizedBox(width: 3),
            Expanded(flex: rb == 0 ? 1 : rb, child: Container(height: 5, color: K.amber)),
          ]),
        ),
      ]),
    );
  }

  Widget _statsTab(MatchDetail d) {
    if (d.teamStats.isEmpty && d.leagueStats.isEmpty) return kMessage('Statistiques indisponibles pour ce match.');
    final rows = <Widget>[];
    for (var i = 0; i < d.teamStats.length; i++) {
      if (i > 0) rows.add(Container(height: 1, color: K.border));
      rows.add(_statRow(d.teamStats[i]));
    }
    final league = <Widget>[];
    for (final s in d.leagueStats) {
      if (s.header) {
        league.add(Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Text(s.label, style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
        ));
      } else {
        league.add(Padding(
          padding: EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Row(children: [
            Expanded(child: Text(s.label, style: TextStyle(color: K.muted, fontSize: 13))),
            Text(s.value, style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ));
      }
    }
    return _list([
      if (rows.isNotEmpty) ...[
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(child: Text(m.home, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.indigo, fontSize: 13.5, fontWeight: FontWeight.w800))),
            Text('vs', style: TextStyle(color: K.muted, fontSize: 12)),
            Expanded(child: Text(m.away, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.amber, fontSize: 13.5, fontWeight: FontWeight.w800))),
          ]),
        ),
        Container(decoration: _box, clipBehavior: Clip.antiAlias, child: Column(children: rows)),
      ],
      if (league.isNotEmpty) ...[
        SizedBox(height: 22),
        _title(d.leagueStatsTitle.isEmpty ? 'Championnat' : 'Championnat · ${d.leagueStatsTitle}'),
        Container(
          decoration: _box,
          padding: EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: league),
        ),
      ],
    ]);
  }
}
