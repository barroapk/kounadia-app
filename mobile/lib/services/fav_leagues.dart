import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_prefs.dart';

/// Championnats favoris (clé = "Pays - Championnat", comme dans l'onglet Matchs).
class FavLeagues {
  static final set = ValueNotifier<Set<String>>({});
  static Future<void>? _f;

  static Future<void> load() => _f ??= _load();

  /// Relit les favoris (après récupération depuis le compte).
  static Future<void> reload() {
    _f = null;
    return load();
  }

  static Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      set.value = (p.getStringList('fav_leagues') ?? const <String>[]).toSet();
    } catch (_) {}
  }

  static String _n(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static (String, String) _split(String s) {
    final i = s.indexOf(' - ');
    return i < 0 ? ('', _n(s)) : (_n(s.substring(0, i)), _n(s.substring(i + 3)));
  }

  /// Un favori couvre un championnat si :
  /// - même libellé ;
  /// - favori « Pays » seul (ex. "England") → tous les championnats du pays ;
  /// - favori « Compétition » seule (ex. "Champions League") → ce nom figure dans le championnat ;
  /// - même pays et noms de championnat qui se recoupent (ex. saison, groupe).
  static bool matches(String fav, String league) {
    if (fav == league) return true;
    final (c, l) = _split(league);
    final (fc, fl) = _split(fav);
    if (fc.isEmpty) return fl.isNotEmpty && (fl == c || (' $l ').contains(' $fl '));
    if (fc == l) return true; // "Champions League - Group A" ↔ "Europe - Champions League"
    return fc == c && fl.isNotEmpty && l.isNotEmpty && (l.contains(fl) || fl.contains(l));
  }

  static bool has(String league) => set.value.any((f) => matches(f, league));

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
    final hit = s.where((f) => matches(f, league)).toList();
    if (hit.isEmpty) {
      s.add(league);
    } else {
      s.removeAll(hit);
    }
    await _save(s);
  }

  /// Ajoute ou retire exactement cette clé (écran Mes championnats).
  static Future<void> toggleExact(String key) async {
    await load();
    final s = {...set.value};
    if (!s.remove(key)) s.add(key);
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
