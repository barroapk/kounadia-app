import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vip.dart';
import 'coupon_engine.dart';
import 'kounadia_data_service.dart' show FriendlyError;
import 'scores_service.dart';

class VipData {
  final VipDay? today;
  final List<VipDay> history;
  final bool offline;
  VipData(this.today, this.history, this.offline);
}

class VipService {
  static final _base = 'https://raw.githubusercontent.com/barroapk/kounadia-data/vip';

  static Future<(String?, bool)> _get(String file) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 300000;
      final r = await http.get(Uri.parse('$_base/$file?v=$bust')).timeout(Duration(seconds: 20));
      if (r.statusCode == 200) {
        final body = utf8.decode(r.bodyBytes);
        await prefs.setString('kvip_$file', body);
        return (body, false);
      }
    } catch (_) {}
    return (prefs.getString('kvip_$file'), true);
  }

  static Future<VipData> load() async {
    final (t, off1) = await _get('vip.json');
    final (h, off2) = await _get('vip_history.json');
    if (t == null && h == null) {
      throw FriendlyError('Le coupon VIP est momentanément indisponible. Vérifiez votre connexion puis réessayez.');
    }
    VipDay? today;
    var hist = <VipDay>[];
    try {
      if (t != null) {
        final d = VipDay.fromJson(Map<String, dynamic>.from(jsonDecode(t) as Map));
        if (d.date.isNotEmpty) today = d;
      }
    } catch (_) {}
    try {
      if (h != null) {
        hist = (jsonDecode(h) as List).map((e) => VipDay.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    // Résultats en direct depuis les scores (plus rapide que le robot)
    try {
      final (days, _) = await ScoresService.load();
      final byId = {for (final l in days.values) for (final m in l) m.id: m};
      for (final d in [if (today != null) today, ...hist.take(2)]) {
        for (final c in d.coupons) {
          for (final l in c.legs) {
            if (l.result == 'won' || l.result == 'lost' || l.result == 'void') continue;
            final m = byId[l.id];
            if (m == null) continue;
            if (m.status == 'postponed') {
              l.result = 'void';
            } else if (m.status == 'finished' && m.hs != null && m.as_ != null) {
              l.result = CouponEngine.evalPick(l.pick, m.hs!, m.as_!) ? 'won' : 'lost';
            } else if (m.status == 'live') {
              l.result = 'live';
            }
          }
        }
      }
    } catch (_) {}
    return VipData(today, hist, off1 && off2);
  }
}
