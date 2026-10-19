import 'dart:async';
import 'package:flutter/material.dart';
import '../models/forecast.dart';
import '../models/live_match.dart';
import '../models/vip.dart';
import '../services/scores_service.dart';
import '../services/vip_service.dart';
import '../services/tip_eval.dart';
import '../widgets/forecast_card.dart';
import '../widgets/knd_banner.dart';

/// Convertit un Coup sûr en carte de pronostic (même style que Kounadia IA / Expert).
Forecast sureForecast(VipLeg l, [LiveMatch? m, (int?, int?, String)? x]) {
  var score = l.score;
  String? minute;
  if (m != null && m.hs != null && m.as_ != null && (m.status == 'live' || m.status == 'finished')) {
    score = '${m.hs}-${m.as_}';
    minute = m.status == 'finished' ? 'Fin' : m.minute;
  }
  if (x != null && x.$1 != null && x.$2 != null) {
    score = '${x.$1}-${x.$2}';
    minute = x.$3;
  }
  return settle(Forecast(
    id: 'sure_${l.id}',
    source: 'sure',
    date: m?.date ?? l.date ?? DateTime.now(),
    hasTime: l.date != null,
    league: l.league,
    home: l.home,
    away: l.away,
    homeLogo: l.hl,
    awayLogo: l.al,
    tipFr: l.label,
    confidence: l.conf / 10,
    score: score,
    won: l.result == 'won' ? true : l.result == 'lost' ? false : null,
    minute: minute,
  ), code: l.pick);
}

class SureTab extends StatefulWidget {
  SureTab({super.key});

  @override
  State<SureTab> createState() => _SureTabState();
}

class _SureTabState extends State<SureTab> {
  VipData? _data;
  Map<int, LiveMatch> _live = {};
  Map<int, (int?, int?, String)> _lv = {};
  String? _error;
  bool _loading = true;
  Timer? _timer;
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _load();
    // Résultats au fur et à mesure : mise à jour discrète toutes les 2 minutes.
    _timer = Timer.periodic(Duration(minutes: 1), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final d = await VipService.load();
      var live = <int, LiveMatch>{};
      final lv = await liveById();
      try {
        final (days, _) = await ScoresService.load();
        live = {for (final l in days.values) for (final m in l) m.id: m};
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _data = d;
        _live = live;
        _lv = lv;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_data == null) _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return Center(child: CircularProgressIndicator(color: K.indigo));
    if (_error != null && _data == null) return kMessage(_error!, onRetry: _load);
    final d = _data!;
    final day = d.today;
    final legs = day?.singles ?? const <VipLeg>[];
    final items = legs.map((l) => sureForecast(l, _live[l.id], _lv[l.id])).toList()..sort((a, b) => a.date.compareTo(b.date));
    final now = DateTime.now();
    final ymd = '${now.year}-${two(now.month)}-${two(now.day)}';

    final children = <Widget>[
      if (d.offline) kOfflineBanner(),
      _hero(items),
      SizedBox(height: 14),
      KndBanner(),
    ];
    if (items.isEmpty) {
      children.addAll([
        SizedBox(height: 30),
        kMessage("Les Coup sûr du jour sont publiés chaque matin à 6h.\nRevenez un peu plus tard."),
      ]);
    } else {
      if (day != null && day.date != ymd) {
        children.add(Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('Sélection du ${day.date.split('-').reversed.join('/')} · nouvelle sélection à 6h',
              style: TextStyle(color: K.amber, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ));
      }
      final groups = <String, List<Forecast>>{};
      for (final f in items) {
        groups.putIfAbsent(f.league.isEmpty ? 'Autres compétitions' : f.league, () => []).add(f);
      }
      for (final e in groups.entries) {
        children
          ..add(_group(e.key, e.value))
          ..add(SizedBox(height: 10));
      }
    }
    children.add(Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text(
        "Sélection la plus fiable selon l'analyse KOUNADIA (confiance ≥ 70 %, modèle et PrimaTips d'accord). "
        "Paris à jouer séparément. Aucun gain n'est garanti. 18+ · Jouez de manière responsable.",
        textAlign: TextAlign.center,
        style: TextStyle(color: K.muted, fontSize: 11.5, height: 1.4),
      ),
    ));
    return RefreshIndicator(
      color: K.indigo,
      backgroundColor: K.card,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12, 0, 12, 96),
        children: children,
      ),
    );
  }

  Widget _hero(List<Forecast> items) {
    final done = items.where((f) => f.won != null).length;
    final won = items.where((f) => f.won == true).length;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E7490), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
          child: Icon(Icons.verified_rounded, color: Colors.white, size: 30),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Coup sûr du jour', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text(
              items.isEmpty
                  ? 'Publié chaque matin à 6h · matchs de 8h à 4h'
                  : '${items.length} pronostic${items.length > 1 ? 's' : ''} simples · résultats en direct',
              style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12.5, height: 1.35),
            ),
          ]),
        ),
        if (done > 0)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Color(0x33000000), borderRadius: BorderRadius.circular(12)),
            child: Text('$won/$done ✓', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
          ),
      ]),
    );
  }

  Widget _group(String title, List<Forecast> list) {
    final collapsed = _collapsed.contains(title);
    final rows = <Widget>[];
    if (!collapsed) {
      for (var i = 0; i < list.length; i++) {
        if (i > 0) rows.add(Container(height: 1, color: K.border));
        rows.add(ForecastCard(f: list[i], grouped: true, result: list[i].won != null));
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
          onTap: () => setState(() => collapsed ? _collapsed.remove(title) : _collapsed.add(title)),
          child: Container(
            color: K.groupHead,
            padding: EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              Icon(Icons.emoji_events_outlined, color: K.amber, size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text('${list.length}', style: TextStyle(color: K.muted, fontSize: 12)),
              Icon(collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, color: K.muted, size: 22),
            ]),
          ),
        ),
        ...rows,
      ]),
    );
  }
}
