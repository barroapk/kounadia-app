import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';

/// Statistiques anonymes : identifiant aléatoire, aucune donnée personnelle.
class Analytics {
  static const _version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static String? _device;
  static final List<Map<String, dynamic>> _queue = [];
  static final Set<String> _once = {};
  static Timer? _timer;
  static bool _sending = false;

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      var id = p.getString('k_device');
      if (id == null || id.length < 8) {
        final r = Random.secure();
        id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
        await p.setString('k_device', id);
      }
      _device = id;
      for (final s in p.getStringList('k_events') ?? const <String>[]) {
        try {
          _queue.add(Map<String, dynamic>.from(jsonDecode(s) as Map));
        } catch (_) {}
      }
      await p.remove('k_events');
    } catch (_) {}
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => flush());
    log('app_open');
  }

  static void log(String name, [Map<String, dynamic>? props]) {
    if (_queue.length >= 300) return;
    _queue.add({
      'name': name,
      'props': props ?? <String, dynamic>{},
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (_queue.length >= 30) flush();
  }

  static int _crashes = 0;
  static String _cut(String s, int n) => s.length <= n ? s : s.substring(0, n);

  /// Plantage de l'app : type, message et début de la pile (5 au maximum par ouverture, rien de personnel).
  /// Pas de vrais plantages : logo ou drapeau qui n'a pas pu se charger (réseau coupé : le maillot s'affiche
  /// à la place), ou erreur venant d'une extension du navigateur (version iPhone).
  static bool _noise(Object error, StackTrace? stack) {
    final m = error.toString();
    if (stack?.toString().contains('chrome-extension://') ?? false) return true;
    final net = RegExp(r'ClientException|SocketException|HttpException|HandshakeException|Connection closed|connection abort|Failed host lookup|Connection reset|timed out', caseSensitive: false).hasMatch(m);
    final img = RegExp(r'\.(png|jpe?g|webp|svg|gif)(\?|$|,|\s)', caseSensitive: false).hasMatch(m) || m.contains('/images/');
    return net && img;
  }

  static void crash(Object error, StackTrace? stack, {bool fatal = false}) {
    if (_noise(error, stack)) return;
    if (_crashes >= 5) return;
    _crashes++;
    log('crash', {
      'type': error.runtimeType.toString(),
      'msg': _cut(error.toString().replaceAll(RegExp(r'\s+'), ' '), 300),
      'stack': _cut(stack?.toString() ?? '', 1500),
      'fatal': fatal,
    });
    flush();
  }

  static void once(String key, String name, [Map<String, dynamic>? props]) {
    if (_once.add(key)) log(name, props);
  }

  static Future<void> flush() async {
    if (_sending || _queue.isEmpty || _device == null || kSupabaseUrl.isEmpty) return;
    _sending = true;
    final batch = _queue.take(50).toList();
    try {
      final body = jsonEncode(batch
          .map((e) => {...e, 'device_id': _device, 'app_version': _version})
          .toList());
      final r = await http
          .post(
            Uri.parse('$kSupabaseUrl/rest/v1/kounadia_events'),
            headers: {
              'apikey': kSupabaseAnon,
              'Authorization': 'Bearer $kSupabaseAnon',
              'Content-Type': 'application/json',
              'Prefer': 'return=minimal',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode >= 200 && r.statusCode < 500) {
        _queue.removeRange(0, batch.length);
        // Les événements gardés hors ligne sont maintenant envoyés : on évite les doublons.
        final p = await SharedPreferences.getInstance();
        await p.remove('k_events');
      }
    } catch (_) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setStringList('k_events', _queue.take(200).map(jsonEncode).toList());
      } catch (_) {}
    } finally {
      _sending = false;
    }
  }
}
