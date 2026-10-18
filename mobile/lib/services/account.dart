import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const kApiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://knd-api-5bgz.onrender.com');

class KUser {
  final String username;
  final String phone;
  final DateTime? premiumUntil;
  KUser(this.username, this.phone, this.premiumUntil);
  bool get premium => premiumUntil != null && premiumUntil!.isAfter(DateTime.now());

  factory KUser.fromJson(Map<String, dynamic> j) => KUser(
        (j['username'] ?? '').toString(),
        (j['phone'] ?? '').toString(),
        DateTime.tryParse((j['premiumUntil'] ?? '').toString())?.toLocal(),
      );
  Map<String, dynamic> toJson() =>
      {'username': username, 'phone': phone, 'premiumUntil': premiumUntil?.toUtc().toIso8601String()};
}

class KPlan {
  final String id, label;
  final int price, days;
  const KPlan(this.id, this.label, this.price, this.days);
}

const kPlans = [
  KPlan('day', '3 jours', 250, 3),
  KPlan('week', 'Hebdomadaire', 500, 7),
  KPlan('month', 'Mensuel', 2000, 30),
  KPlan('year', 'Annuel', 20000, 365),
];

/// Compte KOUNADIA : session, statut Premium, paiement MoneyFusion (via knd-api).
class Account {
  static final user = ValueNotifier<KUser?>(null);
  static String? _token;

  static bool get loggedIn => _token != null && user.value != null;
  static bool get premium => user.value?.premium ?? false;

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _token = p.getString('k_session');
      final u = p.getString('k_user');
      if (_token != null && u != null) user.value = KUser.fromJson(jsonDecode(u) as Map<String, dynamic>);
    } catch (_) {}
    if (_token != null) refresh();
  }

  static Future<void> _save(String? token, KUser? u) async {
    _token = token;
    user.value = u;
    try {
      final p = await SharedPreferences.getInstance();
      if (token == null || u == null) {
        await p.remove('k_session');
        await p.remove('k_user');
      } else {
        await p.setString('k_session', token);
        await p.setString('k_user', jsonEncode(u.toJson()));
      }
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> _call(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$kApiBase$path');
    final h = {'Content-Type': 'application/json', if (_token != null) 'Authorization': 'Bearer $_token'};
    late http.Response r;
    try {
      r = method == 'GET'
          ? await http.get(uri, headers: h).timeout(Duration(seconds: 70))
          : await http.post(uri, headers: h, body: jsonEncode(body ?? {})).timeout(Duration(seconds: 70));
    } catch (_) {
      throw 'Connexion impossible. Vérifie internet puis réessaie.';
    }
    Map<String, dynamic> j = {};
    try {
      j = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
    } catch (_) {}
    if (r.statusCode >= 400) {
      if (r.statusCode == 401 && _token != null && !path.startsWith('/kounadia/auth')) await _save(null, null);
      final m = j['message'];
      throw m is List ? m.join(', ') : (m ?? 'Erreur ${r.statusCode}').toString();
    }
    return j;
  }

  static Future<void> _fromAuth(Map<String, dynamic> j) async {
    await _save(j['token'].toString(), KUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)));
  }

  static Future<void> register(String username, String phone, String pw, String pw2) async =>
      _fromAuth(await _call('POST', '/kounadia/auth/register',
          {'username': username, 'phone': phone, 'password': pw, 'password2': pw2}));

  static Future<void> login(String phone, String pw) async =>
      _fromAuth(await _call('POST', '/kounadia/auth/login', {'phone': phone, 'password': pw}));

  static Future<void> logout() => _save(null, null);

  /// Réveille le serveur (Render gratuit) avant que l'utilisateur ne choisisse une offre.
  static void warmUp() {
    http.get(Uri.parse(kApiBase)).timeout(Duration(seconds: 70)).then((_) {}, onError: (_) {});
  }

  /// Met à jour le statut Premium depuis le serveur (silencieux en cas d'échec).
  static Future<void> refresh() async {
    if (_token == null) return;
    try {
      final j = await _call('GET', '/kounadia/me');
      await _save(_token, KUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)));
    } catch (_) {}
  }

  /// Lance un paiement : renvoie (jeton, lien MoneyFusion).
  static Future<(String, String)> startPayment(String plan) async {
    final j = await _call('POST', '/kounadia/pay', {'plan': plan});
    return (j['token'].toString(), j['url'].toString());
  }

  /// 'paid', 'pending', 'failure'… (le serveur vérifie auprès de MoneyFusion).
  static Future<String> paymentStatus(String token) async {
    final j = await _call('GET', '/kounadia/pay/status/${Uri.encodeComponent(token)}');
    final st = (j['status'] ?? 'pending').toString();
    if (st == 'paid' && j['user'] is Map) {
      await _save(_token, KUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)));
    }
    return st;
  }
}
