import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'kfeed.dart';

/// Un fait marquant d'un grand match du jour (calculé par KOUNADIA chaque demi-heure).
/// La phrase est écrite par l'application dans la langue choisie (voir l10n/facts_text.dart).
class DayFact {
  final String id, lg, home, away, k, side, team, opp, players;
  final String? hl, al;
  final DateTime? date;
  final int n;
  final int? m;
  DayFact({
    required this.id,
    required this.lg,
    required this.home,
    required this.away,
    required this.k,
    required this.side,
    required this.team,
    required this.opp,
    required this.players,
    required this.n,
    this.m,
    this.hl,
    this.al,
    this.date,
  });

  /// Logo de l'équipe dont parle le fait.
  String? get logo => side == 'a' ? al : hl;

  static int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  factory DayFact.fromJson(Map<String, dynamic> j) => DayFact(
        id: '${j['id'] ?? ''}',
        lg: '${j['lg'] ?? ''}',
        home: '${j['h'] ?? ''}',
        away: '${j['a'] ?? ''}',
        k: '${j['k'] ?? ''}',
        side: '${j['s'] ?? ''}',
        team: '${j['t'] ?? ''}',
        opp: '${j['o'] ?? ''}',
        players: '${j['p'] ?? ''}',
        n: _i(j['n']),
        m: j['m'] == null ? null : _i(j['m']),
        hl: j['hl'] as String?,
        al: j['al'] as String?,
        date: DateTime.tryParse('${j['d'] ?? ''}')?.toLocal(),
      );
}

/// Faits du jour : chargés au démarrage puis toutes les 10 minutes ; gardés pour l'affichage hors connexion.
class FactsService {
  static const _cache = 'k_faits';
  static final changed = ValueNotifier<int>(0);
  static List<DayFact> _all = [];
  static DateTime? _at;
  static Future<void>? _running;

  /// Faits des matchs pas encore terminés (un match dure environ 1 h 55).
  static List<DayFact> get items {
    final now = DateTime.now();
    return _all.where((f) => f.date == null || f.date!.add(const Duration(minutes: 115)).isAfter(now)).toList();
  }

  static Future<void> load({bool force = false}) {
    if (!force && _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 10)) return Future.value();
    return _running ??= _load().whenComplete(() => _running = null);
  }

  static Future<void> _load() async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
      if (_all.isEmpty) _parse(p.getString(_cache));
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 300000;
      final r = await KFeed.get('v2/faits.json?v=$bust').timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final body = utf8.decode(r.bodyBytes);
        if (_parse(body)) await p.setString(_cache, body);
      }
      _at = DateTime.now();
    } catch (_) {}
  }

  static bool _parse(String? body) {
    if (body == null || !body.trim().startsWith('{')) return false;
    try {
      final j = jsonDecode(body) as Map;
      _all = [
        for (final x in (j['facts'] as List? ?? const []))
          if (x is Map) DayFact.fromJson(Map<String, dynamic>.from(x)),
      ];
      changed.value++;
      return true;
    } catch (_) {
      return false;
    }
  }
}
