import 'dart:convert';
import 'package:http/http.dart' as http;
import 'kfeed.dart';
import 'account.dart';
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

  static Future<(String?, bool)> _get(String file) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 300000;
      final r = await (file == 'vip.json'
              ? KFeed.getPremium('vip/$file', query: '?v=$bust')
              : KFeed.get('vip/$file?v=$bust'))
          .timeout(Duration(seconds: 30));
      final body = r.statusCode == 200 ? utf8.decode(r.bodyBytes) : '';
      // Invitation « mets à jour » destinée aux anciennes versions : on garde la dernière vraie copie.
      if (r.statusCode == 200 && !body.contains('"upgrade":true')) {
        await prefs.setString('kvip_$file', body);
        return (body, false);
      }
    } catch (_) {}
    return (prefs.getString('kvip_$file'), true);
  }

  static Future<VipData> load() async {
    // Coup sûr du jour : seulement pour les abonnés (le robot refuse sans ticket Premium).
    final (t, off1) = Account.premium ? await _get('vip.json') : (null, false);
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
        for (final legs in [...d.coupons.map((c) => c.legs), d.singles]) {
          for (final l in legs) {
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
