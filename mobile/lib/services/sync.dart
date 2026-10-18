import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'account.dart';
import 'fav_leagues.dart';
import 'theme_controller.dart';
import 'user_prefs.dart';

/// Sauvegarde des réglages dans le compte : favoris, coupons, pays, langue, devise, thème.
/// - à la connexion : on récupère les données du compte (nouveau téléphone) ;
/// - ensuite : on envoie les changements (toutes les 2 min et quand l'app passe en arrière-plan).
class Sync {
  static const keys = [
    'fav_leagues', 'fav_auto', 'score_favs', 'kounadia_coupons',
    'u_country', 'u_lang', 'u_currency', 'theme_mode',
  ];
  static String? _last;
  static Timer? _t;
  static bool _busy = false;

  static Future<Map<String, dynamic>> _snapshot() async {
    final p = await SharedPreferences.getInstance();
    final m = <String, dynamic>{};
    for (final k in keys) {
      final v = p.get(k);
      if (v == null) continue;
      m[k] = v is List ? List<String>.from(v.map((e) => e.toString())) : v;
    }
    return m;
  }

  /// Démarrage de l'app : envoi périodique des changements.
  static void start() {
    _t ??= Timer.periodic(Duration(minutes: 2), (_) => push());
    Timer(Duration(seconds: 15), push);
  }

  static Future<void> push({bool force = false}) async {
    if (!Account.loggedIn || _busy) return;
    _busy = true;
    try {
      final snap = await _snapshot();
      final s = jsonEncode(snap);
      if (force || s != _last) {
        await Account.putPrefs(snap);
        _last = s;
      }
    } catch (_) {}
    _busy = false;
  }

  /// Après connexion : les données du compte remplacent celles du téléphone.
  /// Si le compte n'a encore rien, on y enregistre celles du téléphone.
  static Future<void> pull() async {
    if (!Account.loggedIn) return;
    try {
      final remote = await Account.getPrefs();
      if (remote.isEmpty) {
        await push(force: true);
        return;
      }
      final p = await SharedPreferences.getInstance();
      for (final k in keys) {
        if (!remote.containsKey(k)) continue;
        final v = remote[k];
        if (v is List) {
          await p.setStringList(k, v.map((e) => e.toString()).toList());
        } else if (v is bool) {
          await p.setBool(k, v);
        } else if (v is int) {
          await p.setInt(k, v);
        } else if (v is String) {
          await p.setString(k, v);
        }
      }
      await FavLeagues.reload();
      await UserPrefs.init();
      UserPrefs.changed.value++;
      await ThemeCtl.init();
      _last = jsonEncode(await _snapshot());
    } catch (_) {}
  }
}
