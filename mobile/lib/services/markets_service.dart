import 'dart:convert';
import 'package:http/http.dart' as http;
import 'kfeed.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MatchMarkets {
  final String? hl;
  final String? al;
  /// clé (ou15, ou25, ou35, btts) → (cotes [oui/plus, non/moins], probabilités)
  final Map<String, (List<double>, List<int>)> m;
  MatchMarkets(this.hl, this.al, this.m);
}

class MarketsService {
  static Map<int, MatchMarkets>? _mem;
  static DateTime? _at;

  static Future<Map<int, MatchMarkets>> load() async {
    if (_mem != null && _at != null && DateTime.now().difference(_at!) < Duration(minutes: 10)) {
      return _mem!;
    }
    final prefs = await SharedPreferences.getInstance();
    String? body;
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 600000;
      final r = await KFeed.get('markets/markets.json?v=$bust').timeout(Duration(seconds: 20));
      if (r.statusCode == 200) {
        body = utf8.decode(r.bodyBytes);
        await prefs.setString('kmarkets', body);
      }
    } catch (_) {}
    body ??= prefs.getString('kmarkets');
    if (body == null) return _mem ?? {};
    final out = <int, MatchMarkets>{};
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      ((j['m'] as Map?) ?? {}).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id == null || v is! Map) return;
        final mm = <String, (List<double>, List<int>)>{};
        for (final key in ['ou15', 'ou25', 'ou35', 'btts']) {
          final x = v[key];
          if (x is Map && x['o'] is List && x['p'] is List) {
            final o = (x['o'] as List).map((e) => (e as num).toDouble()).toList();
            final p = (x['p'] as List).map((e) => (e as num).toInt()).toList();
            if (o.length == 2 && p.length == 2) mm[key] = (o, p);
          }
        }
        out[id] = MatchMarkets(v['hl']?.toString(), v['al']?.toString(), mm);
      });
    } catch (_) {}
    _mem = out;
    _at = DateTime.now();
    return out;
  }
}
