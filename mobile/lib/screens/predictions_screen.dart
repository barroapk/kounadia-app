import 'package:flutter/material.dart';
import '../models/sg_tip.dart';
import '../models/nerdy_tip.dart';
import '../services/sg_tips_service.dart';
import '../services/nerdy_tips_service.dart';

class _C {
  static const bg = Color(0xFF0E0F12);
  static const card = Color(0xFF17191E);
  static const line = Color(0xFF24272E);
  static const gold = Color(0xFFF5C542);
  static const goldSoft = Color(0x1FF5C542);
  static const goldBorder = Color(0x80F5C542);
  static const text = Color(0xFFF2F2F2);
  static const muted = Color(0xFF8B8F98);
  static const green = Color(0xFF3DDC84);
  static const orange = Color(0xFFFF9F43);
}

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  final _sg = SgTipsService();
  final _nt = NerdyTipsService();
  late Future<List<SgTip>> _sgF;
  late Future<List<NerdyTip>> _ntF;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _sgF = _sg.getToday();
    _ntF = _nt.getToday();
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _sgF;
    } catch (_) {}
    try {
      await _ntF;
    } catch (_) {}
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  String _todayFr() {
    const j = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const m = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
      'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    final d = DateTime.now();
    return '${j[d.weekday - 1]} ${d.day} ${m[d.month - 1]}';
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
      length: 2,
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: _C.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: _C.text,
          toolbarHeight: 68,
          titleSpacing: 20,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pronostics du jour',
                  style: TextStyle(
                      color: _C.text, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(_todayFr(),
                  style: const TextStyle(color: _C.muted, fontSize: 13)),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: _C.gold,
            indicatorWeight: 3,
            labelColor: _C.gold,
            unselectedLabelColor: _C.muted,
            dividerColor: _C.line,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
            tabs: [Tab(text: 'KOUNADIA IA'), Tab(text: 'EXPERT')],
          ),
        ),
        body: TabBarView(
          children: [
            _listOf<SgTip>(_sgF, _sgCard, "Aucun pronostic IA pour aujourd'hui."),
            _listOf<NerdyTip>(_ntF, _ntCard, "Aucun pronostic expert pour aujourd'hui."),
          ],
        ),
      ),
    );
  }

  Widget _listOf<T>(Future<List<T>> future, Widget Function(T) cardOf, String empty) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _C.gold));
        }
        if (snap.hasError) {
          return _message('Pronostics indisponibles', retry: true);
        }
        final items = snap.data ?? <T>[];
        return RefreshIndicator(
          color: _C.gold,
          backgroundColor: _C.card,
          onRefresh: _refresh,
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [const SizedBox(height: 120), _message(empty)],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => cardOf(items[i]),
                ),
        );
      },
    );
  }

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
              OutlinedButton(
                onPressed: () => setState(_load),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.gold,
                  side: const BorderSide(color: _C.gold),
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: _C.line, borderRadius: BorderRadius.circular(20)),
      child: Text(t,
          style: const TextStyle(
              color: _C.text, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _team(String name, {bool end = false}) {
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _C.line,
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
        color: _C.goldSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.goldBorder),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: _C.gold, fontWeight: FontWeight.w700, fontSize: 14)),
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
      opacity: started ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.line),
        ),
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
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                  ),
                  _chip(started ? 'Commencé' : _hm(date)),
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
                alignment: Alignment.centerLeft,
                child: _pickPill(t.labelFr)),
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
                      color: i < t.agree ? _C.gold : _C.line,
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
                ? _C.gold
                : _C.orange;
    return _shell(
      league: t.league,
      date: t.date,
      home: t.home,
      away: t.away,
      footer: Row(
        children: [
          Expanded(
            child: Align(
                alignment: Alignment.centerLeft,
                child: _pickPill(t.tipFr)),
          ),
          if (c != null) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${c.toStringAsFixed(1)}/10',
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
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
}
