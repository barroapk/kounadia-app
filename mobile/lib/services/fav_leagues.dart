import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Championnats favoris (clé = "Pays - Championnat", comme dans l'onglet Matchs).
class FavLeagues {
  static final set = ValueNotifier<Set<String>>({});
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      set.value = (p.getStringList('fav_leagues') ?? const <String>[]).toSet();
    } catch (_) {}
  }

  static bool has(String league) => set.value.contains(league);

  static Future<void> toggle(String league) async {
    final s = {...set.value};
    if (!s.remove(league)) s.add(league);
    set.value = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('fav_leagues', s.toList());
    } catch (_) {}
  }
}
