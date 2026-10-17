import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';

/// Statistiques anonymes : identifiant aléatoire, aucune donnée personnelle.
class Analytics {
  static const _version = '1.0.0';
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
