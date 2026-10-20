import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coupon.dart';
import 'notif.dart';

class CouponStore {
  static final _k = 'kounadia_coupons';

  static Future<List<Coupon>> all() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_k);
      if (s == null) return [];
      return (jsonDecode(s) as List).map((e) => Coupon.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<Coupon> l) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_k, jsonEncode(l.take(max).map((c) => c.toJson()).toList()));
    } catch (_) {}
    Notif.sync();
  }

  static final max = 5;

  /// 'ok', 'dup' (déjà enregistré) ou 'full' (5 coupons max).
  static Future<String> add(Coupon c) async {
    final l = await all();
    if (l.any((x) => x.signature == c.signature)) return 'dup';
    if (l.length >= max) return 'full';
    l.insert(0, c);
    await saveAll(l);
    return 'ok';
  }

  static Future<void> remove(Coupon c) async {
    final l = await all();
    l.removeWhere((x) => x.signature == c.signature);
    await saveAll(l);
  }
}
