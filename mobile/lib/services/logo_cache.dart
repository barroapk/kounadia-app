import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LogoCache {
  static final Map<String, String> _mem = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString('team_logos');
      if (s != null) {
        (jsonDecode(s) as Map).forEach((k, v) => _mem[k.toString()] = v.toString());
      }
    } catch (_) {}
    _loaded = true;
  }

  static String? get(String name) => _mem[name];

  static Future<void> put(String name, String url) async {
    if (name.isEmpty || _mem[name] == url) return;
    _mem[name] = url;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('team_logos', jsonEncode(_mem));
    } catch (_) {}
  }
}
