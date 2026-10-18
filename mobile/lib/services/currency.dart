import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_prefs.dart';

/// Conversion indicative du F CFA vers la devise de l'utilisateur.
/// Le paiement reste en F CFA (MoneyFusion) ; ceci n'est qu'un affichage.
class Fx {
  static Map<String, double> _rates = {'XOF': 1, 'XAF': 1, 'EUR': 1 / 655.957};
  static bool _busy = false;

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('fx_rates');
      if (raw != null) _apply(raw);
      final at = p.getInt('fx_at') ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - at > 12 * 3600 * 1000) _fetch();
    } catch (_) {}
  }

  static void _apply(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final r = (j['rates'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    if (r.isNotEmpty) _rates = {..._rates, ...r, 'XOF': 1, 'XAF': 1};
  }

  static Future<void> _fetch() async {
    if (_busy) return;
    _busy = true;
    try {
      final r = await http.get(Uri.parse('https://open.er-api.com/v6/latest/XOF')).timeout(Duration(seconds: 15));
      if (r.statusCode == 200) {
        final body = utf8.decode(r.bodyBytes);
        final j = jsonDecode(body) as Map<String, dynamic>;
        if (j['result'] == 'success') {
          _apply(body);
          final p = await SharedPreferences.getInstance();
          await p.setString('fx_rates', jsonEncode({'rates': j['rates']}));
          await p.setInt('fx_at', DateTime.now().millisecondsSinceEpoch);
          UserPrefs.changed.value++;
        }
      }
    } catch (_) {}
    _busy = false;
  }

  static String symbol(String code) {
    if (code == 'XOF' || code == 'XAF') return 'F CFA';
    try {
      return NumberFormat.simpleCurrency(name: code).currencySymbol;
    } catch (_) {
      return code;
    }
  }

  /// « ≈ 0,38 € » dans la devise choisie, ou null si F CFA / taux inconnu.
  static String? approx(int fcfa) {
    final c = UserPrefs.currency;
    if (c == 'XOF' || c == 'XAF') return null;
    final r = _rates[c];
    if (r == null) return null;
    final v = fcfa * r;
    try {
      final f = NumberFormat.currency(locale: 'fr', name: c, symbol: symbol(c), decimalDigits: v >= 100 ? 0 : 2);
      return '≈ ${f.format(v)}';
    } catch (_) {
      return '≈ ${v.toStringAsFixed(v >= 100 ? 0 : 2)} $c';
    }
  }
}
