import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'account.dart';
import 'live_socket.dart' show kLiveBase;

/// Codes 1xBet des coupons du jour, saisis par KOUNADIA dans KOUNADIA Admin (robot KOUNADIA).
/// Single et coupon gratuit : pour tous ; coupons VIP et Coups sûrs : avec le ticket Premium.
class Codes {
  static final data = ValueNotifier<Map<String, String>>({});
  static String day = '';
  static DateTime? _at;
  static Future<void>? _pending;

  /// Code du coupon [key] pour le jour [forDay] (null si aucun).
  static String? of(String key, String? forDay) => forDay != null && forDay == day ? data.value[key] : null;

  /// Relit les codes (au plus toutes les 2 minutes, sauf [force]).
  static Future<void> load({bool force = false}) {
    final at = _at;
    if (!force && at != null && DateTime.now().difference(at) < const Duration(minutes: 2)) return Future.value();
    return _pending ??= _fetch().whenComplete(() => _pending = null);
  }

  static Future<void> _fetch() async {
    if (kLiveBase.isEmpty) return;
    try {
      final t = Account.ticket;
      final r = await http
          .get(Uri.parse('$kLiveBase/codes'), headers: {if (t != null) 'Authorization': 'Bearer $t'})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return;
      final j = jsonDecode(r.body);
      if (j is! Map) return;
      final c = <String, String>{};
      final m = j['codes'];
      if (m is Map) {
        m.forEach((k, v) {
          final s = '$v';
          if (RegExp(r'^[A-Z0-9]{4,24}$').hasMatch(s)) c['$k'] = s;
        });
      }
      day = (j['day'] ?? '').toString();
      _at = DateTime.now();
      if (!mapEquals(c, data.value)) data.value = c;
    } catch (_) {}
  }
}
