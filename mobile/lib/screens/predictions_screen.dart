import 'package:flutter/material.dart';
import '../models/sg_tip.dart';
import '../models/nerdy_tip.dart';
import '../models/tip_result.dart';
import '../services/sg_tips_service.dart';
import '../services/nerdy_tips_service.dart';
import '../services/tip_results_service.dart';

class _C {
  static const bg = Color(0xFFF4F5F7);
  static const card = Colors.white;
  static const line = Color(0xFFE5E7EB);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0x1A16A34A);
  static const greenBorder = Color(0x6616A34A);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0x1ADC2626);
  static const amber = Color(0xFFD97706);
}

const _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
  'août', 'septembre', 'octobre', 'novembre', 'décembre'];

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  final _sg = SgTipsService();
  final _nt = NerdyTipsService();
  final _hist = TipResultsService();
  late Future<List<SgTip>> _sgF;
  late Future<List<NerdyTip>> _ntF;
  late Future<List<TipResult>> _histF;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _sgF = _sg.getToday();
    _ntF = _nt.getToday();
    _histF = _hist.getAll();
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _sgF;
    } catch (_) {}
    try {
      await _ntF;
    } catch (_) {}
    try {
      await _histF;
    } catch (_) {}
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  String _dateFr(DateTime d) => '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    return _dateFr(d);
  }

  String _initials(String n) {
    final p = n.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) {
      return p[0].substring(0, p[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (p[0][0] + p[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: _C.text,
          toolbarHeight: 68,
          titleSpacing: 20,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pronostics',
                  style: TextStyle(
                      color: _C.text, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(_dateFr(DateTime.now()),
                  style: const TextStyle(color: _C.muted, fontSize: 13)),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: _C.green,
            indicatorWeight: 3,
            labelColor: _C.green,
            unselectedLabelColor: _C.muted,
            dividerColor: _C.line,
            labelStyle: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            tabs: [
              Tab(text: 'KOUNADIA IA'),
              Tab(text: 'EXPERT'),
              Tab(text: 'HISTORIQUE'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _listOf<SgTip>(_sgF, _sgCard, "Aucun pronostic IA pour aujourd'hui."),
            _listOf<NerdyTip>(_ntF, _ntCard, "Aucun pronostic expert pour aujourd'hui."),
            _historyTab(),
          ],
        ),
      ),
    );
  }

  // ---------- Listes ----------

  Widget _scroll(List<Widget> children) {
    return RefreshIndicator(
      color: _C.green,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: children,
      ),
    );
  }

  Widget _listOf<T>(Future<List<T>> future, Widget Function(T) cardOf, String empty) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _C.green));
        }
        if (snap.hasError) return _message('Pronostics indisponibles', retry: true);
        final items = snap.data ?? <T>[];
        if (items.isEmpty) {
          return _scroll([const SizedBox(height: 100), _message(empty)]);
        }
        final children = <Widget>[];
        for (final it in items) {
          children
            ..add(cardOf(it))
            ..add(const SizedBox(height: 12));
        }
        return _scroll(children);
      },
    );
  }

  Widget _historyTab() {
    return FutureBuilder<List<TipResult>>(
      future: _histF,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _C.green));
        }
        if (snap.hasError) return _message('Historique indisponible', retry: true);
        final items = snap.data ?? <TipResult>[];
        if (items.isEmpty) {
          return _scroll([
            const SizedBox(height: 100),
            _message('Aucun résultat disponible pour le moment.'),
          ]);
        }

        final won = items.where((r) => r.won).length;
        final children = <Widget>[_summary(won, items.length)];
        String? currentDay;
        for (final r in items) {
          final label = _dayLabel(r.date);
          if (label != currentDay) {
            currentDay = label;
            children.add(Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
              child: Text(label,
                  style: const TextStyle(
                      color: _C.text, fontSize: 15, fontWeight: FontWeight.w800)),
            ));
          }
          children
            ..add(_resultCard(r))
            ..add(const SizedBox(height: 10));
        }
        return _scroll(children);
      },
    );
  }

  // ---------- Éléments communs ----------

  Widget _message(String text, {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_soccer, color: _C.muted, size: 40),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.muted, fontSize: 15)),
            if (retry) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => setState(_load),
                style: FilledButton.styleFrom(backgroundColor: _C.green),
                child: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  BoxDecoration get _cardBox => BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      );

  Widget _chip(String t, {Color color = _C.muted, Color bg = _C.bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(t,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _team(String name, {bool end = false}) {
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _C.bg,
          child: Text(_initials(name),
              style: const TextStyle(
                  color: _C.text, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        Text(name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: end ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
                color: _C.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.2)),
      ],
    );
  }

  Widget _pickPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.greenBorder),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: _C.green, fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }

  Widget _shell({
    required String league,
    required DateTime date,
    required String home,
    required String away,
    Widget? center,
    required Widget footer,
  }) {
    final started = date.isBefore(DateTime.now());
    return Opacity(
      opacity: started ? 0.6 : 1,
      child: Container(
        decoration: _cardBox,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(league.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _C.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ),
                  _chip(started ? 'Commencé' : _hm(date), color: _C.text),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(child: _team(home)),
                  SizedBox(
                    width: 76,
                    child: Center(
                      child: center ??
                          const Text('VS',
                              style: TextStyle(
                                  color: _C.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Expanded(child: _team(away, end: true)),
                ],
              ),
            ),
            Container(height: 1, color: _C.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: footer,
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Cartes ----------

  Widget _sgCard(SgTip t) {
    return _shell(
      league: t.leagueName,
      date: t.date,
      home: t.home,
      away: t.away,
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.score.replaceAll('-', ' - '),
              style: const TextStyle(
                  color: _C.text, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('score prédit',
              style: TextStyle(color: _C.muted, fontSize: 10)),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: Align(
                alignment: Alignment.centerLeft, child: _pickPill(t.labelFr)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  t.models,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < t.agree ? _C.green : _C.line,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text("${t.agree}/${t.models} modèles d'accord",
                  style: const TextStyle(color: _C.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ntCard(NerdyTip t) {
    final c = t.confidence;
    final color = c == null
        ? _C.muted
        : c >= 7.5
            ? _C.green
            : c >= 6
                ? _C.amber
                : _C.muted;
    return _shell(
      league: t.league,
      date: t.date,
      home: t.home,
      away: t.away,
      footer: Row(
        children: [
          Expanded(
            child: Align(
                alignment: Alignment.centerLeft, child: _pickPill(t.tipFr)),
          ),
          if (c != null) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${c.toStringAsFixed(1)}/10',
                    style: TextStyle(
                        color: color, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                SizedBox(
                  width: 70,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: c / 10,
                      minHeight: 5,
                      backgroundColor: _C.line,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('confiance',
                    style: TextStyle(color: _C.muted, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary(int won, int total) {
    final rate = total == 0 ? 0.0 : won / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardBox,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$won/$total pronostics validés',
                    style: const TextStyle(
                        color: _C.text, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 8,
                    backgroundColor: _C.redSoft,
                    color: _C.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text('${(rate * 100).round()} %',
              style: const TextStyle(
                  color: _C.green, fontSize: 24, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _resultCard(TipResult r) {
    final ok = r.won;
    final goals = r.score.split('-');
    final hg = goals.isNotEmpty ? goals[0] : '';
    final ag = goals.length > 1 ? goals[1] : '';
    const teamStyle = TextStyle(
        color: _C.text, fontSize: 15, fontWeight: FontWeight.w600);
    const goalStyle = TextStyle(
        color: _C.text, fontSize: 15, fontWeight: FontWeight.w800);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBox,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? _C.greenSoft : _C.redSoft,
            ),
            child: Icon(ok ? Icons.check_rounded : Icons.close_rounded,
                color: ok ? _C.green : _C.red, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.league.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _C.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ),
                    _chip(r.source == 'ia' ? 'IA' : 'EXPERT'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: Text(r.home,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: teamStyle)),
                  Text(hg, style: goalStyle),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                      child: Text(r.away,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: teamStyle)),
                  Text(ag, style: goalStyle),
                ]),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(r.tipFr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: ok ? _C.green : _C.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    Text(ok ? 'Validé' : 'Perdu',
                        style: TextStyle(
                            color: ok ? _C.green : _C.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
