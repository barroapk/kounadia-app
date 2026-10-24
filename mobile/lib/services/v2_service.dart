import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/v2.dart';
import 'account.dart';
import 'kfeed.dart';
import 'kounadia_data_service.dart' show FriendlyError;
import 'scores_service.dart';

/// Données KOUNADIA V2 : public (coupons gratuits + historiques) ou Premium (tout, via le robot et le ticket).
class V2Service {
  static const _cachePub = 'kv2_pub';
  static const _cachePrem = 'kv2_prem';

  static Future<(String?, bool)> _get(bool premium) async {
    final prefs = await SharedPreferences.getInstance();
    final key = premium ? _cachePrem : _cachePub;
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 120000;
      final r = await (premium ? KFeed.getPremium('v2/v2.json', query: '?v=$bust') : KFeed.get('v2/v2.json?v=$bust'))
          .timeout(Duration(seconds: 30));
      if (r.statusCode == 200) {
        final body = utf8.decode(r.bodyBytes);
        if (body.trim().startsWith('{')) {
          await prefs.setString(key, body);
          return (body, false);
        }
      }
    } catch (_) {}
    return (prefs.getString(key), true);
  }

  static Future<V2Data>? _pending;
  static DateTime? _at;
  static bool? _atPremium;

  /// Une seule lecture partagée par les onglets (gardée 60 s, ou rechargée sur demande).
  static Future<V2Data> shared({bool force = false}) {
    final fresh = _at != null && DateTime.now().difference(_at!) < Duration(seconds: 60) && _atPremium == Account.premium;
    if (!force && fresh && _pending != null) return _pending!;
    _at = DateTime.now();
    _atPremium = Account.premium;
    final f = load();
    _pending = f;
    f.then<void>((_) {}, onError: (Object _) {
      _at = null; // échec : la prochaine ouverture réessaie
    });
    return f;
  }

  static Future<V2Data> load() async {
    final prem = Account.premium;
    var (text, off) = await _get(prem);
    if (text == null && prem) (text, off) = await _get(false);
    if (text == null) {
      throw FriendlyError('Les coupons sont momentanément indisponibles. Vérifie ta connexion puis réessaie.');
    }
    final j = Map<String, dynamic>.from(jsonDecode(text) as Map);
    final today = j['today'] is Map ? V2Day.fromJson(Map<String, dynamic>.from(j['today'] as Map)) : null;
    final hist = ((j['history'] as List?) ?? const [])
        .map((e) => V2Day.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    final stats = <String, V2Stat>{
      for (final e in ((j['stats'] as Map?) ?? const {}).entries)
        e.key.toString(): V2Stat.fromJson(Map<String, dynamic>.from(e.value as Map)),
    };
    // Direct : les matchs PrimaTips du jour passent en « en cours » puis gagné/perdu sans attendre le robot.
    if (today != null) await _live(today);
    final at = DateTime.tryParse((j['updatedAt'] ?? '').toString())?.toLocal();
    return V2Data(today, hist, stats, off, prem && today?.selection?.locked == false, at);
  }

  static Future<void> _live(V2Day d) async {
    try {
      final (days, _) = await ScoresService.load();
      final byId = {for (final l in days.values) for (final m in l) m.id: m};
      for (final l in d.allLegs) {
        if (l.r == 'won' || l.r == 'lost' || l.r == 'void') continue;
        final id = l.ptId;
        final m = id == null ? null : byId[id];
        if (m == null) continue;
        if (m.status == 'postponed') {
          l.r = 'void';
        } else if (m.hs != null && m.as_ != null && (m.status == 'live' || m.status == 'finished')) {
          l.score = '${m.hs}-${m.as_}';
          if (m.status == 'finished') {
            final v = quick(l.mk, m.hs!, m.as_!);
            if (v != null) l.r = v ? 'won' : 'lost';
          } else {
            l.r = 'live';
          }
        }
      }
      for (final c in d.coupons.values) {
        c?.refresh();
      }
      for (final c in d.selection?.coupons.values ?? const <V2Coupon?>[]) {
        c?.refresh();
      }
    } catch (_) {}
  }

  /// Règlement immédiat des paris qui ne dépendent que du score final (mêmes règles que le moteur).
  static bool? quick(String mk, int h, int a) {
    final t = h + a;
    switch (mk) {
      case '1':
        return h > a;
      case '2':
        return a > h;
      case '1X':
        return h >= a;
      case 'X2':
        return a >= h;
      case '12':
        return h != a;
      case 'BTTS oui':
        return h > 0 && a > 0;
      case 'BTTS non':
        return h == 0 || a == 0;
      case 'Dom. marque':
        return h > 0;
      case 'Ext. marque':
        return a > 0;
      case 'Dom. +1.5':
        return h > 1;
      case 'Ext. +1.5':
        return a > 1;
    }
    final g = RegExp(r'^([+-])(\d\.5)$').firstMatch(mk);
    if (g != null) {
      final line = double.parse(g[2]!);
      return g[1] == '+' ? t > line : t < line;
    }
    return null; // mi-temps, corners, fautes, tirs : réglés par le robot (statistiques officielles)
  }
}
