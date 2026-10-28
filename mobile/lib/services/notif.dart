import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'live_socket.dart' show kLiveBase;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/tr.dart';
import 'coupon_store.dart';
import 'account.dart';
import '../screens/account_screen.dart';
import 'fav_leagues.dart';
import 'user_prefs.dart';
import '../screens/match_open.dart';

// Identifiants Firebase injectés à la compilation (secret GOOGLE_SERVICES_JSON).
const _apiKey = String.fromEnvironment('FB_API_KEY');
const _appId = String.fromEnvironment('FB_APP_ID');
const _sender = String.fromEnvironment('FB_SENDER');
const _project = String.fromEnvironment('FB_PROJECT');

/// Clé du "ScaffoldMessenger" global : affiche les alertes reçues quand l'app est ouverte.
final kMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Navigateur global : ouvre le match quand on touche une notification.
final kNavKey = GlobalKey<NavigatorState>();

/// Même calcul que le robot Cloudflare (FNV-1a 32 bits) : nom de sujet d'un championnat.
String leagueHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// Notifications en direct (buts, coup d'envoi, mi-temps, fin) via Firebase.
/// Chaque téléphone s'abonne seulement à ses championnats favoris, ses matchs suivis
/// et les matchs de ses coupons.
class Notif {
  static bool _ok = false;
  static final enabled = ValueNotifier<bool>(true);
  static Set<String> _labels = {};
  static bool _busy = false, _again = false;

  static Future<void> init() async {
    // Compilation sans Firebase, ou navigateur (iPhone) : pas de notifications Firebase.
    if (kIsWeb || _apiKey.isEmpty || _appId.isEmpty) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: _apiKey, appId: _appId, messagingSenderId: _sender, projectId: _project),
      );
      _ok = true;
      final p = await SharedPreferences.getInstance();
      enabled.value = p.getBool('notif_on') ?? true;
      FirebaseMessaging.onMessage.listen(_foreground);
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      FavLeagues.set.addListener(sync);
      // Nouveau jeton Firebase : on le redonne au robot.
      FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
        try {
          final p = await SharedPreferences.getInstance();
          await p.remove('notif_cp');
        } catch (_) {}
        sync();
      });
      UserPrefs.changed.addListener(sync);
    } catch (_) {}
  }

  /// Demande l'autorisation (Android 13+), puis met les abonnements à jour.
  static Future<void> start() async {
    if (!_ok) return;
    if (enabled.value) {
      try {
        await FirebaseMessaging.instance.requestPermission();
      } catch (_) {}
    }
    await sync();
    try {
      final m = await FirebaseMessaging.instance.getInitialMessage();
      if (m != null) _open(m);
    } catch (_) {}
  }

  /// Notification touchée : ouvre directement le match concerné.
  static void _open(RemoteMessage m) {
    final id = int.tryParse(m.data['id']?.toString() ?? '');
    final ctx = kNavKey.currentContext;
    if (m.data['t'] == 'premium' && ctx != null) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => AccountScreen()));
      return;
    }
    if (id != null && ctx != null) openMatchId(ctx, id);
  }

  static Future<void> setEnabled(bool on) async {
    enabled.value = on;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('notif_on', on);
    } catch (_) {}
    if (on) {
      await start();
    } else {
      await sync();
    }
  }

  /// Championnats présents dans les matchs chargés (appelé après chaque chargement).
  static void leagues(Iterable<String> labels) {
    _labels = labels.toSet();
    sync();
  }

  static void _foreground(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    kMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 5),
        action: m.data['id'] == null && m.data['t'] != 'premium' ? null : SnackBarAction(label: tr('Voir'), onPressed: () => _open(m)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.title ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
          if ((n.body ?? '').isNotEmpty) Text(n.body!),
        ]),
      ));
  }

  /// Coupons en cours et matchs suivis confiés au robot : il envoie les buts directement
  /// à ce téléphone (plus rapide) et prévient dès qu'un coupon est gagné ou perdu.
  static Future<void> _coupons(Set<String> topics) async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = enabled.value
          ? [
              for (final c in await CouponStore.all())
                if (c.status == 'pending' || c.status == 'live')
                  {
                    'sig': c.signature,
                    'odd': c.total.toStringAsFixed(2).replaceAll('.', ','),
                    'legs': [
                      for (final g in c.legs) {'id': g.matchId, 'pick': g.pick, 'home': g.home, 'away': g.away}
                    ],
                  }
            ]
          : <Map<String, dynamic>>[];
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || kLiveBase.isEmpty) return;
      final live = (topics.where((t) => t.contains('_l2_') || t.contains('_m2_')).toList()..sort());
      // Abonné Premium : son ticket signé permet au robot de lui rappeler la fin de son abonnement.
      final tk = Account.user.value?.ticket;
      final body = jsonEncode({'token': token, 'lang': appLang, 'coupons': list, 'topics': live, if (tk != null) 'ticket': tk});
      if (p.getString('notif_cp') == body) return; // rien de nouveau
      final r = await http
          .post(Uri.parse('$kLiveBase/coupons'), headers: {'content-type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) await p.setString('notif_cp', body);
    } catch (_) {}
  }

  static Future<void> sync() async {
    if (!_ok) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        final p = await SharedPreferences.getInstance();
        final had = (p.getStringList('notif_topics') ?? const <String>[]).toSet();
        final want = <String>{};
        if (enabled.value) {
          final l = appLang;
          if (_labels.isEmpty) {
            // Matchs pas encore chargés : on garde les championnats déjà suivis.
            want.addAll(had.where((t) => t.startsWith('${l}_l2_')));
          } else {
            for (final x in _labels) {
              if (FavLeagues.has(x)) want.add('${l}_l2_${leagueHash(x)}');
            }
          }
          for (final id in p.getStringList('score_favs') ?? const <String>[]) {
            want.add('${l}_m2_$id');
          }
          for (final c in await CouponStore.all()) {
            for (final g in c.legs) {
              if (g.result == 'pending' || g.result == 'live') want.add('${l}_m2_${g.matchId}');
            }
          }
          want.add('${l}_tips'); // Coup sûr et pronostics du jour
        }
        if (want.length == had.length && want.containsAll(had)) {
          continue;
        }
        final m = FirebaseMessaging.instance;
        for (final t in want.difference(had)) {
          await m.subscribeToTopic(t);
        }
        for (final t in had.difference(want)) {
          await m.unsubscribeFromTopic(t);
        }
        await p.setStringList('notif_topics', want.toList());
      } while (_again);
      final prefs = await SharedPreferences.getInstance();
      await _coupons((prefs.getStringList('notif_topics') ?? const <String>[]).toSet());
    } catch (_) {
      // Hors connexion : nouvel essai au prochain chargement.
    } finally {
      _busy = false;
    }
  }
}
