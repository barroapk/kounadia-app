import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../services/v2_service.dart';
import '../../widgets/forecast_card.dart' show K, kMessage;
import 'v2_widgets.dart' show kV2Unavailable;

String _n(dynamic v) => v == null ? '–' : '$v'.replaceAll('.', ',');
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

// Ordre d'affichage : les grands championnats d'abord, puis les autres.
const _order = ['E0', 'SP1', 'I1', 'D1', 'F1', 'P1', 'N1', 'B1', 'T1', 'SC0', 'G1', 'E1', 'SP2', 'I2', 'D2', 'F2', 'E2', 'E3', 'SC1', 'SC2', 'SC3'];
int _rank(Map<String, dynamic> l) {
  final i = _order.indexOf('${l['code']}');
  return i < 0 ? 99 : i;
}

/// Statistiques des championnats (saison en cours) : buts, +2,5, les deux marquent, corners, fautes, tirs, cartons.
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
      appBar: AppBar(
          backgroundColor: K.bg,
          foregroundColor: K.text,
          title: T('Statistiques des championnats', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return Center(child: CircularProgressIndicator(color: K.indigo));
          if (snap.hasError || (snap.data ?? const []).isEmpty) return kMessage(kV2Unavailable, onRetry: _reload);
          final list = [...snap.data!]..sort((a, b) => _rank(a).compareTo(_rank(b)));
          return RefreshIndicator(
            color: K.indigo,
            onRefresh: _reload,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 40),
              itemCount: list.length + 1,
              separatorBuilder: (_, __) => SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(4, 4, 4, 2),
                    child: T('Saison en cours · moyennes par match. Touche un championnat pour le détail par équipe.',
                        style: TextStyle(color: K.muted, fontSize: 12.5)),
                  );
                }
                return _LeagueCard(list[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Barre victoire domicile / nul / victoire extérieur.
Widget _resultBar(Map<String, dynamic> l) {
  final h = _d(l['home']), d = _d(l['draw']), a = _d(l['away']);
  if (h + d + a <= 0) return SizedBox.shrink();
  Widget part(double v, Color c) => Expanded(flex: (v * 10).round().clamp(1, 1000), child: Container(height: 8, color: c));
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Row(children: [part(h, K.green), part(d, K.muted.withAlpha(120)), part(a, K.indigo)]),
    ),
    SizedBox(height: 5),
    Row(children: [
      Expanded(
          child: Text('${tr('Domicile')} ${_n(l['home'])} %',
              style: TextStyle(color: K.green, fontSize: 11.5, fontWeight: FontWeight.w800))),
      Text('${tr('Nul')} ${_n(l['draw'])} %', style: TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
      Expanded(
          child: Text('${tr('Extérieur')} ${_n(l['away'])} %',
              textAlign: TextAlign.end, style: TextStyle(color: K.indigoText, fontSize: 11.5, fontWeight: FontWeight.w800))),
    ]),
  ]);
}

Widget _kpi(String label, String value, {Color? color}) => Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value, style: TextStyle(color: color ?? K.text, fontSize: 17, fontWeight: FontWeight.w900)),
          SizedBox(height: 2),
          T(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: K.muted, fontSize: 11)),
        ]),
      ),
    );

Widget _kpiRow(List<Widget> k) => Row(children: [
      for (var i = 0; i < k.length; i++) ...[if (i > 0) SizedBox(width: 6), k[i]],
    ]);

class _LeagueCard extends StatelessWidget {
  final Map<String, dynamic> l;
  _LeagueCard(this.l);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: K.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _LeagueScreen(l))),
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: K.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  T('${l['name']}', style: TextStyle(color: K.text, fontSize: 15.5, fontWeight: FontWeight.w900)),
                  Text('${tr('${l['country']}')} · ${_n(l['n'])} ${tr('matchs')}', style: TextStyle(color: K.muted, fontSize: 12)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: K.muted),
            ]),
            SizedBox(height: 10),
            _kpiRow([
              _kpi('Buts / match', _n(l['goals']), color: K.indigoText),
              _kpi('+2,5 buts', '${_n(l['o25'])} %'),
              _kpi('Les deux marquent', '${_n(l['btts'])} %'),
            ]),
            SizedBox(height: 6),
            _kpiRow([
              _kpi('Corners', _n(l['corners'])),
              _kpi('Fautes', _n(l['fouls'])),
              _kpi('Cartons', _n(l['cards'])),
            ]),
            SizedBox(height: 10),
            _resultBar(l),
          ]),
        ),
      ),
    );
  }
}

/// Détail d'un championnat : chiffres clés, meilleurs par thème et tableau des équipes.
class _LeagueScreen extends StatefulWidget {
  final Map<String, dynamic> l;
  _LeagueScreen(this.l);

  @override
  State<_LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<_LeagueScreen> {
  String _sort = 'pts';
  // (clé, libellé, plus petit = meilleur, unité)
  static const _cols = [
    ('pts', 'Points', false, ''),
    ('gf', 'Buts marqués', false, ''),
    ('ga', 'Buts encaissés', true, ''),
    ('o25', '+2,5 buts', false, ' %'),
    ('bt', 'Les deux marquent', false, ' %'),
    ('cs', 'Sans encaisser', false, ' %'),
    ('cf', 'Corners', false, ''),
    ('f', 'Fautes', false, ''),
    ('y', 'Cartons', false, ''),
  ];

  List<Map<String, dynamic>> get _teams =>
      ((widget.l['teams'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Widget _section(String title, Widget child) => Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w900)),
          SizedBox(height: 10),
          child,
        ]),
      );

  /// Meilleure équipe sur un thème (ex. meilleure attaque).
  Widget _leader(IconData icon, Color c, String label, String key, {bool low = false, String unit = ''}) {
    final t = _teams.where((x) => x[key] is num).toList();
    if (t.isEmpty) return SizedBox.shrink();
    t.sort((a, b) => low ? _d(a[key]).compareTo(_d(b[key])) : _d(b[key]).compareTo(_d(a[key])));
    final best = t.first;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: c.withAlpha(36), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: c, size: 19),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T(label, style: TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
            Text('${best['team']}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
        Text('${_n(best[key])}$unit', style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final col = _cols.firstWhere((c) => c.$1 == _sort);
    final teams = _teams
      ..sort((a, b) {
        final x = _d(a[_sort]), y = _d(b[_sort]);
        return col.$3 ? x.compareTo(y) : y.compareTo(x);
      });
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
          backgroundColor: K.bg,
          foregroundColor: K.text,
          title: T('${l['name']}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      body: ListView(padding: EdgeInsets.fromLTRB(12, 8, 12, 40), children: [
        _section(
          '${tr('Chiffres clés')} · ${_n(l['n'])} ${tr('matchs')}',
          Column(children: [
            _kpiRow([
              _kpi('Buts / match', _n(l['goals']), color: K.indigoText),
              _kpi('+2,5 buts', '${_n(l['o25'])} %'),
              _kpi('Les deux marquent', '${_n(l['btts'])} %'),
            ]),
            SizedBox(height: 6),
            _kpiRow([
              _kpi('Corners', _n(l['corners'])),
              _kpi('Fautes', _n(l['fouls'])),
              _kpi('Cartons', _n(l['cards'])),
            ]),
            SizedBox(height: 6),
            _kpiRow([
              _kpi('Tirs', _n(l['shots'])),
              _kpi('Tirs cadrés', _n(l['sot'])),
            ]),
            SizedBox(height: 12),
            _resultBar(l),
          ]),
        ),
        _section(
          tr('Les meilleurs par thème'),
          Column(children: [
            _leader(Icons.sports_soccer_rounded, K.green, 'Meilleure attaque (buts par match)', 'gf'),
            _leader(Icons.shield_rounded, K.indigo, 'Meilleure défense (buts encaissés)', 'ga', low: true),
            _leader(Icons.trending_up_rounded, K.amber, 'Le plus de matchs à +2,5 buts', 'o25', unit: ' %'),
            _leader(Icons.flag_rounded, Color(0xFF06B6D4), 'Le plus de corners', 'cf'),
            _leader(Icons.lock_rounded, K.green, 'Le plus de matchs sans encaisser', 'cs', unit: ' %'),
            _leader(Icons.style_rounded, K.red, 'Le plus de cartons', 'y'),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: T('Classer les équipes par', style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w900)),
        ),
        SizedBox(
          height: 38,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final c in _cols)
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: T(c.$2),
                  selected: _sort == c.$1,
                  onSelected: (_) => setState(() => _sort = c.$1),
                  selectedColor: K.indigoSoft,
                  backgroundColor: K.card,
                  labelStyle: TextStyle(color: _sort == c.$1 ? K.indigoText : K.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
                  side: BorderSide(color: K.border),
                  showCheckmark: false,
                ),
              ),
          ]),
        ),
        SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.border)),
          child: Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(children: [
                SizedBox(width: 28, child: Text('#', style: TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w800))),
                Expanded(child: T('Équipe', style: TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w800))),
                T(col.$2, style: TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ]),
            ),
            for (var i = 0; i < teams.length; i++) ...[
              Container(height: 1, color: K.border),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  SizedBox(
                      width: 28,
                      child: Text('${i + 1}',
                          style: TextStyle(color: i < 3 ? K.indigoText : K.muted, fontSize: 13, fontWeight: FontWeight.w900))),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${teams[i]['team']}', style: TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text(
                          '${teams[i]['n']} ${tr('matchs')} · ${tr('buts')} ${_n(teams[i]['gf'])}-${_n(teams[i]['ga'])} · '
                          '${tr('corners')} ${_n(teams[i]['cf'])} · ${tr('cartons')} ${_n(teams[i]['y'])}',
                          style: TextStyle(color: K.muted, fontSize: 11.5)),
                    ]),
                  ),
                  SizedBox(width: 8),
                  Text('${_n(teams[i][_sort])}${col.$4}',
                      style: TextStyle(color: K.indigoText, fontSize: 15, fontWeight: FontWeight.w900)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
