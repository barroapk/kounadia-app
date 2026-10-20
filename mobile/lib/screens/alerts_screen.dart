import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_match.dart';
import '../services/coupon_store.dart';
import '../services/fav_leagues.dart';
import '../services/live_socket.dart';
import '../services/primatips_service.dart' show frLeague;
import '../services/scores_service.dart';
import '../widgets/forecast_card.dart' show K, kMessage, hm;
import '../widgets/k_ui.dart';
import '../l10n/tr.dart';
import 'match_open.dart';

/// Alertes : buts, coups d'envoi, mi-temps et fins de match de tes championnats favoris,
/// matchs suivis et coupons (36 dernières heures), mises à jour en direct.
class AlertsScreen extends StatefulWidget {
  AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Map<int, LiveMatch> _matches = {};
  List<MatchEvent> _events = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<List<MatchEvent>>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = LiveSocket.events.stream.listen((ev) {
      final mine = ev.where((e) => _matches.containsKey(e.id)).toList();
      if (mine.isNotEmpty && mounted) setState(() => _events = [...mine.reversed, ..._events]);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FavLeagues.load();
      final p = await SharedPreferences.getInstance();
      final follow = (p.getStringList('score_favs') ?? const <String>[]).map(int.tryParse).whereType<int>().toSet();
      for (final c in await CouponStore.all()) {
        follow.addAll(c.legs.map((g) => g.matchId));
      }
      final (days, _) = await ScoresService.load();
      final m = <int, LiveMatch>{};
      for (final l in days.values) {
        for (final x in l) {
          if (follow.contains(x.id) || FavLeagues.has(x.leagueLabel)) m[x.id] = x;
        }
      }
      final ev = await LiveSocket.log(m.keys);
      if (!mounted) return;
      setState(() {
        _matches = m;
        _events = ev;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Vous êtes hors connexion. Vérifiez votre connexion internet puis réessayez.';
        });
      }
    }
  }

  (IconData, Color, String) _kind(String t) => switch (t) {
        'goal' => (Icons.sports_soccer_rounded, K.green, tr('But')),
        'ko' => (Icons.play_circle_rounded, K.indigoText, tr("Coup d'envoi")),
        'ht' => (Icons.pause_circle_rounded, K.amber, tr('Mi-temps')),
        _ => (Icons.flag_rounded, K.muted, tr('Fin du match')),
      };

  Widget _row(MatchEvent e) {
    final m = _matches[e.id];
    if (m == null) return SizedBox.shrink();
    final (icon, color, label) = _kind(e.type);
    final score = e.hs != null && e.as_ != null ? '${e.hs} - ${e.as_}' : '-';
    final minute = RegExp(r'^\d').hasMatch(e.st) ? " · ${e.st}'" : '';
    final scorer = e.type == 'goal' ? ' · ${e.side == 'h' ? m.home : m.away}' : '';
    return InkWell(
      onTap: () => openMatch(context, m),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 11, 10, 11),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 21),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label$scorer$minute',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('${m.home}  $score  ${m.away}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w700)),
              Text(frLeague(m.leagueLabel),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.muted, fontSize: 12)),
            ]),
          ),
          SizedBox(width: 8),
          Text(hm(e.at), style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = kLoader();
    } else if (_error != null) {
      body = kMessage(_error!, onRetry: _load);
    } else {
      final ev = _events.where((e) => _matches.containsKey(e.id)).toList();
      if (ev.isEmpty) {
        body = kMessage(
            "Aucune alerte pour le moment. Mets une étoile sur tes championnats ou tes matchs pour suivre leurs buts et résultats ici.");
      } else {
        final today = DateTime.now();
        bool same(DateTime a) => a.year == today.year && a.month == today.month && a.day == today.day;
        final t = ev.where((e) => same(e.at)).toList();
        final y = ev.where((e) => !same(e.at)).toList();
        body = RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            if (t.isNotEmpty) ...[kTitle("Aujourd'hui"), kDividers(t.map(_row).toList())],
            if (y.isNotEmpty) ...[kTitle('Hier'), kDividers(y.map(_row).toList())],
          ]),
        );
      }
    }
    return Scaffold(backgroundColor: K.bg, appBar: kAppBar(tr('Alertes')), body: body);
  }
}
