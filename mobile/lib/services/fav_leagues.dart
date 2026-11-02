import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_prefs.dart';
import 'footlive_service.dart' show FlCatalog, kFlCountries, kFlMore;
import '../config/countries.dart' show kCountries;

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
    unawaited(_loadPairs());
  }

  // ---------- Noms : un même pays ou une même compétition peut avoir plusieurs écritures ----------
  // Ex. « Cote d'Ivoire » (PrimaTips) = « Ivory Coast » (footlive) = « Côte d’Ivoire » (liste des pays) ;
  // « Cameroon - Championnat du Cameroun » (footlive) = « Cameroon - Elite One » (PrimaTips).
  // Sans cela, un favori enregistré sous un nom ne reconnaissait pas les matchs affichés sous l'autre.

  static const _from = 'àâäáãåçéèêëíìîïñóòôöõúùûüÿœæß’`´';
  static const _to = 'aaaaaaceeeeiiiinooooouuuuyoasxxx';

  /// Minuscules sans accents ni ponctuation.
  static String _n(String s) {
    var t = s.toLowerCase();
    for (var i = 0; i < _from.length; i++) {
      final r = _to[i] == 'x' ? "'" : _to[i];
      t = t.replaceAll(_from[i], r);
    }
    return t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static Map<String, String>? _iso;

  /// Nom de pays (toutes langues et écritures) → code du pays.
  static Map<String, String> get _countries {
    final m = _iso;
    if (m != null) return m;
    final out = <String, String>{};
    for (final c in kCountries) {
      out[_n(c.name)] = c.iso;
      for (final a in c.aliases) {
        out[_n(a)] = c.iso;
      }
    }
    for (final c in [...kFlCountries, ...kFlMore]) {
      final code = c.flag.toUpperCase();
      out.putIfAbsent(_n(c.en), () => code);
      out.putIfAbsent(_n(c.fr), () => code);
    }
    const extra = {
      'ivory coast': 'CI', 'cote d ivoire': 'CI', 'dr congo': 'CD', 'congo dr': 'CD', 'rd congo': 'CD', 'congo kinshasa': 'CD',
      'democratic republic of congo': 'CD', 'congo': 'CG', 'congo brazzaville': 'CG', 'usa': 'US', 'united states': 'US',
      'turkiye': 'TR', 'turkey': 'TR', 'south korea': 'KR', 'korea republic': 'KR', 'bosnia herz': 'BA',
      'bosnia and herzegovina': 'BA', 'czech republic': 'CZ', 'czechia': 'CZ', 'uae': 'AE', 'united arab emirates': 'AE',
    };
    out.addAll(extra);
    return _iso = out;
  }

  /// Pays sous une forme unique (son code s'il est connu).
  static String _cc(String country) {
    final n = _n(country);
    return _countries[n] ?? n;
  }

  /// Compétitions connues sous deux noms (catalogue KOUNADIA, mis à jour chaque jour) : nom footlive → nom PrimaTips.
  static Map<String, String> _same = {};
  static final Map<String, bool> _memo = {};

  static Future<void> _loadPairs() async {
    try {
      final cat = await FlCatalog.countries();
      final out = <String, String>{};
      cat.forEach((_, v) {
        if (v is! Map || v['comps'] is! Map) return;
        final en = '${v['en'] ?? ''}';
        (v['comps'] as Map).forEach((t, x) {
          // Seulement les paires sûres (même pays, notées avec la règle des deux équipes).
          if (x is Map && x['pt'] != null && x['ptv'] == 2 && en.isNotEmpty) {
            final (c1, l1) = _raw('$en - $t');
            final (c2, l2) = _raw('${x['pt']}');
            if (c1 == c2 && l1 != l2) out['$c1|$l1'] = '$c2|$l2';
          }
        });
      });
      _same = out;
      _memo.clear();
      set.value = {...set.value}; // l'onglet Matchs se redessine avec les noms reconnus
    } catch (_) {}
  }

  /// « Pays - Championnat » → (pays, championnat), le pays pris le plus long possible parmi les pays connus
  /// (ex. « Congo - Brazzaville - Ligue 1 »).
  static (String, String) _raw(String s) {
    if (_countries.containsKey(_n(s))) return ('', _n(s)); // pays seul (ex. « Congo - Kinshasa »)
    var best = -1;
    for (var i = s.indexOf(' - '); i >= 0; i = s.indexOf(' - ', i + 3)) {
      if (_countries.containsKey(_n(s.substring(0, i)))) best = i;
    }
    if (best < 0) best = s.indexOf(' - ');
    if (best < 0) return ('', _n(s));
    return (_cc(s.substring(0, best)), _n(s.substring(best + 3)));
  }

  static (String, String) _split(String s) {
    final (c, l) = _raw(s);
    if (c.isEmpty) return (c, l);
    final t = _same['$c|$l'];
    if (t == null) return (c, l);
    final i = t.indexOf('|');
    return (t.substring(0, i), t.substring(i + 1));
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
    if (fc.isEmpty) return fl.isNotEmpty && (_cc(fl) == c || (' $l ').contains(' $fl '));
    if (fc == l) return true; // "Champions League - Group A" ↔ "Europe - Champions League"
    return fc == c && fl.isNotEmpty && l.isNotEmpty && (l.contains(fl) || fl.contains(l));
  }

  static bool has(String league) {
    final favs = set.value;
    if (favs.isEmpty) return false;
    final k = '${favs.length}|${favs.hashCode}|$league';
    if (_memo.length > 4000) _memo.clear();
    return _memo[k] ??= favs.any((f) => matches(f, league));
  }

  static Future<void> _save(Set<String> s) async {
    set.value = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('fav_leagues', s.toList());
    } catch (_) {}
  }

  /// L'utilisateur a choisi lui-même au moins une fois (on ne lui repose plus la question).
  static Future<void> _chosen() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('fav_chosen', true);
    } catch (_) {}
  }

  static Future<void> toggle(String league) async {
    unawaited(_chosen());
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
    unawaited(_chosen());
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
      final s = {...set.value};
      var add = false;
      for (final l in labels.toSet()) {
        // Pays du match reconnu sous toutes ses écritures (ex. « Cote d'Ivoire » pour un utilisateur de Côte d'Ivoire).
        final (cc, _) = _raw(l);
        if (cc != c.iso) continue;
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
