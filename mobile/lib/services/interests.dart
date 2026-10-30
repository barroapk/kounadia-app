import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centres d'intérêt (sur le téléphone uniquement) : équipes et championnats que l'utilisateur regarde,
/// suit ou recherche. Sert aux notifications d'infos personnalisées (rares et espacées).
/// Les points baissent avec le temps : ce qui n'intéresse plus disparaît tout seul.
class Interests {
  static Map<String, double> _teams = {}, _leagues = {};
  static bool _loaded = false;
  static int _day = 0;
  /// Infos personnalisées activées (Paramètres).
  static final enabled = ValueNotifier<bool>(true);

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      enabled.value = p.getBool('info_on') ?? true;
      _teams = _dec(p.getString('int_teams'));
      _leagues = _dec(p.getString('int_leagues'));
      _day = p.getInt('int_day') ?? 0;
      final today = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
      if (_day > 0 && today > _day) {
        final f = _pow(0.94, today - _day); // −6 % par jour
        _teams.updateAll((_, v) => v * f);
        _leagues.updateAll((_, v) => v * f);
        _teams.removeWhere((_, v) => v < 0.3);
        _leagues.removeWhere((_, v) => v < 0.3);
      }
      _day = today;
    } catch (_) {}
  }

  static double _pow(double b, int e) {
    var r = 1.0;
    for (var i = 0; i < e && i < 400; i++) {
      r *= b;
    }
    return r;
  }

  static Map<String, double> _dec(String? s) {
    if (s == null) return {};
    try {
      return (jsonDecode(s) as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      // On garde les 40 plus forts de chaque liste.
      List<MapEntry<String, double>> top(Map<String, double> m) => (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(40).toList();
      _teams = Map.fromEntries(top(_teams));
      _leagues = Map.fromEntries(top(_leagues));
      await p.setString('int_teams', jsonEncode(_teams));
      await p.setString('int_leagues', jsonEncode(_leagues));
      await p.setInt('int_day', _day);
    } catch (_) {}
  }

  /// Match ouvert, mis en favori ou joué dans un coupon.
  static Future<void> match(String home, String away, String league, {double w = 1}) async {
    await load();
    for (final t in [home, away]) {
      if (t.trim().isEmpty) continue;
      _teams[t] = (_teams[t] ?? 0) + w;
    }
    if (league.trim().isNotEmpty) _leagues[league] = (_leagues[league] ?? 0) + w;
    await _save();
  }

  /// Recherche d'une équipe ou d'un championnat.
  static Future<void> search(String team) async {
    await load();
    if (team.trim().isEmpty) return;
    _teams[team] = (_teams[team] ?? 0) + 1.5;
    await _save();
  }

  /// Profil envoyé au robot : les équipes et championnats qui comptent vraiment (au moins 2 points).
  static Future<Map<String, dynamic>?> profile(Iterable<String> favLeagues) async {
    await load();
    if (!enabled.value) return {'off': true};
    List<String> best(Map<String, double> m, int n) =>
        (m.entries.where((e) => e.value >= 2).toList()..sort((a, b) => b.value.compareTo(a.value))).take(n).map((e) => e.key).toList();
    final teams = best(_teams, 8);
    final leagues = {...favLeagues.take(6), ...best(_leagues, 6)}.take(8).toList();
    if (teams.isEmpty && leagues.isEmpty) return null;
    return {'teams': teams, 'leagues': leagues};
  }

  static Future<void> setEnabled(bool on) async {
    enabled.value = on;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('info_on', on);
    } catch (_) {}
  }
}
