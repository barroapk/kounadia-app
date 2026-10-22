import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/countries.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'live_socket.dart' show kLiveBase;

/// Langues proposées (code, nom affiché).
const kLangs = <(String, String)>[
  ('fr', 'Français'), ('en', 'English'), ('es', 'Español'), ('pt', 'Português'), ('ar', 'العربية'),
];

String langName(String code) {
  for (final (c, n) in kLangs) {
    if (c == code) return n;
  }
  return code;
}

/// Pays, langue et devise de l'utilisateur (choisis à la première ouverture).
class UserPrefs {
  static final changed = ValueNotifier<int>(0);
  static String? iso;
  static String lang = 'fr';
  static String currency = 'XOF';
  static bool done = false;

  static KCountry? get country => countryByIso(iso);

  /// Langue disponible dans l'application (sinon anglais).
  static String supported(String l) => kLangs.any((e) => e.$1 == l) ? l : 'en';

  /// Pays deviné d'après le téléphone (sinon Burkina Faso).
  static KCountry guess() {
    try {
      final cc = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      final c = countryByIso(cc?.toUpperCase());
      if (c != null) return c;
    } catch (_) {}
    return countryByIso('BF')!;
  }

  /// Pays réel de l'utilisateur (d'après sa connexion internet), sinon d'après le téléphone.
  static Future<KCountry> detect() async {
    try {
      // Dans le navigateur, Cloudflare refuse l'appel direct : le robot renvoie le pays.
      final u = kIsWeb && kLiveBase.isNotEmpty ? '$kLiveBase/geo' : 'https://www.cloudflare.com/cdn-cgi/trace';
      final r = await http.get(Uri.parse(u)).timeout(Duration(seconds: 5));
      final m = RegExp(r'^loc=([A-Z]{2})\s*$', multiLine: true).firstMatch(r.body);
      final c = countryByIso(m?.group(1));
      if (c != null) return c;
    } catch (_) {}
    return guess();
  }

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      iso = p.getString('u_country');
      lang = supported(p.getString('u_lang') ?? 'fr');
      currency = p.getString('u_currency') ?? country?.currency ?? 'XOF';
      done = p.getBool('u_setup') ?? false;
    } catch (_) {}
  }

  static Future<void> _store() async {
    changed.value++;
    try {
      final p = await SharedPreferences.getInstance();
      if (iso != null) await p.setString('u_country', iso!);
      await p.setString('u_lang', lang);
      await p.setString('u_currency', currency);
      await p.setBool('u_setup', done);
    } catch (_) {}
  }

  /// Nouveau pays : la devise suit le pays (modifiable ensuite dans Paramètres).
  static Future<void> setCountry(KCountry c) {
    iso = c.iso;
    currency = c.currency;
    return _store();
  }

  static Future<void> setLang(String l) {
    lang = supported(l);
    return _store();
  }

  static Future<void> setCurrency(String c) {
    currency = c;
    return _store();
  }

  static Future<void> finishSetup(KCountry c, String l) {
    iso = c.iso;
    currency = c.currency;
    lang = supported(l);
    done = true;
    return _store();
  }

  /// Fuseau du téléphone, ex. « GMT+0 », « GMT+5:30 ».
  static String gmt() {
    final o = DateTime.now().timeZoneOffset;
    final m = o.inMinutes.abs();
    final s = o.isNegative ? '-' : '+';
    return 'GMT$s${m ~/ 60}${m % 60 == 0 ? '' : ':${(m % 60).toString().padLeft(2, '0')}'}';
  }
}
