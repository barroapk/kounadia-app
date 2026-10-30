import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'sync.dart';

const kApiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://knd-api-5bgz.onrender.com');

/// Adresse e-mail valide (même règle que le serveur).
final kEmailRe = RegExp(r'^[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}$');
bool isEmail(String s) => kEmailRe.hasMatch(s.trim().toLowerCase());

class KUser {
  final String username;
  final String? email;
  final DateTime? premiumUntil;
  /// Ticket Premium signé par le serveur (24 h max) : ouvre le contenu Premium chez le robot.
  final String? ticket;
  KUser(this.username, this.email, this.premiumUntil, [this.ticket]);
  bool get premium => premiumUntil != null && premiumUntil!.isAfter(DateTime.now());

  factory KUser.fromJson(Map<String, dynamic> j) {
    final e = (j['email'] ?? '').toString();
    return KUser(
      (j['username'] ?? '').toString(),
      e.isEmpty ? null : e,
      DateTime.tryParse((j['premiumUntil'] ?? '').toString())?.toLocal(),
      j['ticket'] is String && (j['ticket'] as String).isNotEmpty ? j['ticket'] as String : null,
    );
  }
  Map<String, dynamic> toJson() => {
        'username': username, 'email': email, 'premiumUntil': premiumUntil?.toUtc().toIso8601String(),
        if (ticket != null) 'ticket': ticket,
      };
}

class KPlan {
  final String id, label;
  final int price, days;
  const KPlan(this.id, this.label, this.price, this.days);
}

const kPlans = [
  KPlan('day', '3 jours', 525, 3),
  KPlan('week', '1 semaine', 1050, 7),
  KPlan('month', '1 mois', 4200, 30),
  KPlan('quarter', '3 mois', 10500, 90),
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
    if (_token != null) refresh(renew: true);
  }

  /// Certaines réponses ne contiennent pas l'e-mail : on garde celui déjà connu.
  static KUser _keepEmail(KUser u) =>
      u.email != null || user.value?.email == null ? u : KUser(u.username, user.value!.email, u.premiumUntil, u.ticket);

  /// Ticket Premium encore valable (le serveur en donne un nouveau à chaque actualisation du compte).
  static String? get ticket => premium ? user.value?.ticket : null;

  static Future<void>? _renewing;
  static DateTime? _renewedAt;

  /// Ticket refusé ou absent : on redemande le statut au serveur (au plus une fois toutes les 10 min).
  static Future<void> renewTicket() {
    final last = _renewedAt;
    if (_renewing == null && last != null && DateTime.now().difference(last) < const Duration(minutes: 10)) {
      return Future.value();
    }
    _renewedAt = DateTime.now();
    return _renewing ??= refresh().whenComplete(() => _renewing = null);
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
    await Sync.pull();
  }

  /// Réglages sauvegardés dans le compte.
  static Future<Map<String, dynamic>> getPrefs() async {
    final j = await _call('GET', '/kounadia/me/prefs');
    final p = j['prefs'];
    return p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
  }

  static Future<void> putPrefs(Map<String, dynamic> prefs) async {
    await _call('POST', '/kounadia/me/prefs', {'prefs': prefs});
  }

  static Future<void> register(String username, String email, String pw, String pw2) async =>
      _fromAuth(await _call('POST', '/kounadia/auth/signup',
          {'username': username, 'email': email.trim().toLowerCase(), 'password': pw, 'password2': pw2}));

  static Future<void> login(String email, String pw) async =>
      _fromAuth(await _call('POST', '/kounadia/auth/signin', {'email': email.trim().toLowerCase(), 'password': pw}));

  static Future<void> logout() => _save(null, null);

  /// Changer son mot de passe (connecté).
  static Future<void> changePassword(String old, String pw, String pw2) async {
    final j = await _call('POST', '/kounadia/me/password', {'old': old, 'password': pw, 'password2': pw2});
    // Le serveur ferme les autres sessions et donne une nouvelle session à ce téléphone.
    if (j['token'] is String && j['user'] is Map) {
      await _save(j['token'] as String, _keepEmail(KUser.fromJson(Map<String, dynamic>.from(j['user'] as Map))));
    }
  }

  /// Mot de passe oublié : envoie un code à l'e-mail du compte.
  static Future<void> forgot(String email) async {
    await _call('POST', '/kounadia/auth/forgot', {'email': email.trim().toLowerCase()});
  }

  /// Code reçu par e-mail + nouveau mot de passe (connecte directement).
  static Future<void> resetPassword(String email, String code, String pw, String pw2) async =>
      _fromAuth(await _call('POST', '/kounadia/auth/reset',
          {'email': email.trim().toLowerCase(), 'code': code, 'password': pw, 'password2': pw2}));

  /// Ajouter / modifier l'e-mail du compte (anciens comptes).
  static Future<void> setEmail(String email) async {
    final j = await _call('POST', '/kounadia/me/email', {'email': email.trim().toLowerCase()});
    await _save(_token, KUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)));
  }

  /// Réveille le serveur (Render gratuit) avant que l'utilisateur ne choisisse une offre.
  static void warmUp() {
    http.get(Uri.parse(kApiBase)).timeout(Duration(seconds: 70)).then((_) {}, onError: (_) {});
  }

  /// Met à jour le statut Premium ; [renew] renouvelle aussi la session (elle n'expire pas tant que l'app est utilisée).
  static Future<void> refresh({bool renew = false}) async {
    if (_token == null) return;
    try {
      final j = await _call('GET', '/kounadia/me');
      await _save(_token, _keepEmail(KUser.fromJson(Map<String, dynamic>.from(j['user'] as Map))));
    } catch (_) {}
    if (!renew || _token == null) return;
    try {
      final j = await _call('GET', '/kounadia/me/session');
      await _save(j['token'].toString(), KUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)));
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
      await _save(_token, _keepEmail(KUser.fromJson(Map<String, dynamic>.from(j['user'] as Map))));
    }
    return st;
  }
}
