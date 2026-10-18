import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/countries.dart';

/// Langues proposées (code, nom affiché).
const kLangs = <(String, String)>[
  ('fr', 'Français'), ('en', 'English'), ('es', 'Español'), ('pt', 'Português'),
  ('ar', 'العربية'), ('sw', 'Kiswahili'), ('zh', '中文'), ('hi', 'हिन्दी'),
  ('ru', 'Русский'), ('de', 'Deutsch'), ('it', 'Italiano'), ('tr', 'Türkçe'),
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
  static String get dial => country?.dial ?? '226';

  /// Pays deviné d'après le téléphone (sinon Burkina Faso).
  static KCountry guess() {
    try {
      final cc = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      final c = countryByIso(cc?.toUpperCase());
      if (c != null) return c;
    } catch (_) {}
    return countryByIso('BF')!;
  }

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      iso = p.getString('u_country');
      lang = p.getString('u_lang') ?? 'fr';
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
    lang = l;
    return _store();
  }

  static Future<void> setCurrency(String c) {
    currency = c;
    return _store();
  }

  static Future<void> finishSetup(KCountry c, String l) {
    iso = c.iso;
    currency = c.currency;
    lang = l;
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
