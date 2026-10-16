import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coupon.dart';

class CouponStore {
  static const _k = 'kounadia_coupons';

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
      await p.setString(_k, jsonEncode(l.take(30).map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  static Future<bool> add(Coupon c) async {
    final l = await all();
    if (l.any((x) => x.signature == c.signature)) return false;
    l.insert(0, c);
    await saveAll(l);
    return true;
  }

  static Future<void> remove(Coupon c) async {
    final l = await all();
    l.removeWhere((x) => x.signature == c.signature);
    await saveAll(l);
  }
}
