import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/v2.dart';
import 'live_socket.dart';
import 'v2_service.dart';
import 'scores_service.dart';

/// Direct des événements KOUNADIA V2.
/// - Score et minute : robot KOUNADIA en temps réel (quelques secondes), comme l'onglet Matchs.
/// - Corners, fautes, tirs, tirs cadrés : ESPN, relu chaque minute pendant les matchs concernés.
class V2Live {
  /// Change à chaque nouvelle donnée : les écrans se redessinent.
  static final tick = ValueNotifier<int>(0);
  static final Map<Object, List<V2Leg>> _by = {};
  static Iterable<V2Leg> get _legs => _by.values.expand((x) => x);
  static StreamSubscription? _sock;
  static Timer? _timer;

  /// Un écran suit ces événements (remplace sa liste précédente). Appeler [stop] quand l'écran disparaît.
  static void follow(Object owner, Iterable<V2Leg> legs) {
    _by[owner] = legs.toList();
    _sock ??= LiveSocket.updates.stream.listen(_onSocket);
    if (LiveSocket.last.isNotEmpty) _onSocket(Map.of(LiveSocket.last));
    _timer ??= Timer.periodic(Duration(seconds: 60), (_) => _stats());
    _live ??= Timer.periodic(Duration(seconds: 20), (_) => _refreshLive());
    _stats();
  }

  static void stop(Object owner) {
    _by.remove(owner);
    if (_by.isNotEmpty) return;
    _sock?.cancel();
    _sock = null;
    _timer?.cancel();
    _timer = null;
    _live?.cancel();
    _live = null;
  }

  static Timer? _live;

  /// Toutes les 20 s : la minute avance à l'écran ; si le robot ne répond plus, on lit le direct du site.
  static Future<void> _refreshLive() async {
    final now = DateTime.now();
    final ids = <int>{
      for (final l in _legs)
        if (l.ptId != null && l.r != 'won' && l.r != 'lost' && l.r != 'void' && l.date != null && now.isAfter(l.date!)) l.ptId!,
    };
    if (ids.isEmpty) return;
    if (LiveSocket.fresh) {
      _onSocket({for (final id in ids) if (LiveSocket.last[id] != null) id: LiveSocket.last[id]!});
      tick.value++;
      return;
    }
    try {
      final m = <int, (int?, int?, String)>{};
      for (final x in await ScoresService.live()) {
        final id = (x['id'] as num?)?.toInt();
        if (id == null || !ids.contains(id)) continue;
        m[id] = ((x['hs'] as num?)?.toInt(), (x['as'] as num?)?.toInt(), (x['st'] ?? '').toString().trim());
      }
      if (m.isNotEmpty) _onSocket(m);
      tick.value++;
    } catch (_) {}
  }

  static void _onSocket(Map<int, (int?, int?, String)> m) {
    var changed = false;
    for (final l in _legs) {
      final id = l.ptId;
      final v = id == null ? null : m[id];
      if (v == null || v.$1 == null || v.$2 == null) continue;
      if (l.r == 'won' || l.r == 'lost' || l.r == 'void') continue;
      if (l.date != null && l.date!.isAfter(DateTime.now())) continue;
      final score = '${v.$1}-${v.$2}';
      final st = v.$3;
      final fin = RegExp(r'^(FT|AET|PEN)', caseSensitive: false).hasMatch(st);
      final minute = fin ? 'Fin' : (LiveSocket.minuteOf(id!, st) ?? (st.toUpperCase() == 'HT' ? 'MT' : st));
      if (score == l.score && minute == l.minute) continue;
      l.score = score;
      l.minute = minute;
      if (fin) {
        final r = V2Service.quick(l.mk, v.$1!, v.$2!);
        if (r != null) l.r = r ? 'won' : 'lost';
      } else if (l.r == null) {
        l.r = 'live';
      }
      changed = true;
    }
    if (changed) tick.value++;
  }

  static final _client = http.Client();

  /// Statistiques en direct (ESPN) des matchs commencés et pas encore réglés.
  static Future<void> _stats() async {
    final now = DateTime.now();
    final todo = <String, List<V2Leg>>{};
    for (final l in _legs) {
      if (l.espnId == null || l.espnLg == null || l.date == null) continue;
      if (l.r == 'won' || l.r == 'lost' || l.r == 'void') continue;
      if (now.isBefore(l.date!) || now.isAfter(l.date!.add(Duration(hours: 3)))) continue;
      todo.putIfAbsent('${l.espnLg}|${l.espnId}', () => []).add(l);
    }
    var changed = false;
    for (final e in todo.entries.take(25)) {
      final parts = e.key.split('|');
      try {
        final r = await _client
            .get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/soccer/${parts[0]}/summary?event=${parts[1]}'))
            .timeout(Duration(seconds: 12));
        if (r.statusCode != 200) continue;
        final s = parseSummary(Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map));
        if (s == null) continue;
        for (final l in e.value) {
          if (s.st.isNotEmpty) l.st = s.st;
          if (s.h1 != null) l.h1 = s.h1;
          if (l.ptId == null && s.hg != null && s.ag != null) {
            // Match sans direct KOUNADIA : score et minute d'ESPN.
            l.score = '${s.hg}-${s.ag}';
            l.minute = s.done ? 'Fin' : (s.clock.isEmpty ? null : s.clock);
            if (l.r == null && s.state == 'in') l.r = 'live';
          }
          if (s.done && l.statKey != null) {
            final pair = l.statPair;
            final line = RegExp(r'([+-])(\d+\.5)$').firstMatch(l.mk);
            if (pair != null && pair[0] != null && pair[1] != null && line != null) {
              final tot = pair[0]! + pair[1]!;
              final x = double.parse(line[2]!);
              l.r = (line[1] == '+' ? tot > x : tot < x) ? 'won' : 'lost';
            }
          }
        }
        changed = true;
      } catch (_) {}
    }
    if (changed) tick.value++;
  }

  /// Lecture du détail ESPN (même règles que le moteur).
  static ({String state, bool done, String clock, int? hg, int? ag, List<int>? h1, Map<String, List<int?>> st})? parseSummary(
      Map<String, dynamic> j) {
    final comps = ((j['header'] as Map?)?['competitions'] as List?) ?? const [];
    final comp = comps.isEmpty ? null : comps.first as Map?;
    final cs = (comp?['competitors'] as List?) ?? const [];
    Map? side(String s) => cs.cast<Map?>().firstWhere((x) => x?['homeAway'] == s, orElse: () => null);
    final h = side('home'), a = side('away');
    if (h == null || a == null) return null;
    int? n(dynamic v) => v == null ? null : num.tryParse('$v')?.round();
    final type = ((comp?['status'] as Map?)?['type'] as Map?) ?? const {};
    const names = {'c': 'wonCorners', 'f': 'foulsCommitted', 's': 'totalShots', 't': 'shotsOnTarget'};
    final st = <String, List<int?>>{};
    final hid = '${(h['team'] as Map?)?['id'] ?? h['id']}', aid = '${(a['team'] as Map?)?['id'] ?? a['id']}';
    for (final t in ((j['boxscore'] as Map?)?['teams'] as List?) ?? const []) {
      final tid = '${((t as Map)['team'] as Map?)?['id']}';
      final i = tid == hid ? 0 : tid == aid ? 1 : -1;
      if (i < 0) continue;
      for (final e in names.entries) {
        Map? s;
        for (final x in ((t['statistics'] as List?) ?? const [])) {
          if (x is Map && x['name'] == e.value) s = x;
        }
        final v = n(s?['displayValue'] ?? s?['value']);
        if (v == null) continue;
        (st[e.key] ??= [null, null])[i] = v;
      }
    }
    int? half(Map c) {
      final ls = (c['linescores'] as List?) ?? const [];
      return ls.isEmpty ? null : n((ls.first as Map?)?['displayValue']);
    }
    final h1 = half(h) != null && half(a) != null ? [half(h)!, half(a)!] : null;
    return (
      state: '${type['state'] ?? ''}',
      done: type['completed'] == true,
      clock: '${(comp?['status'] as Map?)?['displayClock'] ?? ''}',
      hg: n(h['score']),
      ag: n(a['score']),
      h1: h1,
      st: st,
    );
  }
}
