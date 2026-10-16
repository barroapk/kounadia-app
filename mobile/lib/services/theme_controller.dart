import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thème : 'dark', 'light' ou 'auto' (clair de 6h à 18h, sombre de 18h à 6h).
class ThemeCtl {
  static final mode = ValueNotifier<String>('dark');

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      mode.value = p.getString('theme_mode') ?? 'dark';
    } catch (_) {}
  }

  static bool get isDark {
    switch (mode.value) {
      case 'light':
        return false;
      case 'auto':
        final h = DateTime.now().hour;
        return h < 6 || h >= 18;
      default:
        return true;
    }
  }

  static Future<void> set(String m) async {
    mode.value = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('theme_mode', m);
    } catch (_) {}
  }
}
