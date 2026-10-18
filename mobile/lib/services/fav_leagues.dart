import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_prefs.dart';

/// Championnats favoris (clé = "Pays - Championnat", comme dans l'onglet Matchs).
class FavLeagues {
  static final set = ValueNotifier<Set<String>>({});
  static Future<void>? _f;

  static Future<void> load() => _f ??= _load();

  static Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      set.value = (p.getStringList('fav_leagues') ?? const <String>[]).toSet();
    } catch (_) {}
  }

  static bool has(String league) => set.value.contains(league);

  static Future<void> _save(Set<String> s) async {
    set.value = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('fav_leagues', s.toList());
    } catch (_) {}
  }

  static Future<void> toggle(String league) async {
    await load();
    final s = {...set.value};
    if (!s.remove(league)) s.add(league);
    await _save(s);
  }

  /// Ajoute une seule fois les championnats du pays de l'utilisateur
  /// (s'il en retire un, il ne revient pas).
  static Future<void> autoSeed(Iterable<String> labels) async {
    final c = UserPrefs.country;
    if (c == null) return;
    await load();
    try {
      final p = await SharedPreferences.getInstance();
      final done = (p.getStringList('fav_auto') ?? const <String>[]).toSet();
      final names = c.aliases.map((e) => e.toLowerCase()).toSet();
      final s = {...set.value};
      var add = false;
      for (final l in labels.toSet()) {
        final i = l.indexOf(' - ');
        if (i < 0 || !names.contains(l.substring(0, i).trim().toLowerCase())) continue;
        if (done.add(l)) {
          s.add(l);
          add = true;
        }
      }
      if (add) {
        await p.setStringList('fav_auto', done.toList());
        await _save(s);
      }
    } catch (_) {}
  }
}
