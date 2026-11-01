import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Vidéo des temps forts d'un grand match (chaîne YouTube officielle d'un club, du championnat ou d'un diffuseur).
class HlVideo {
  final String id, title, channel;
  final bool embed; // lecture possible dans l'app
  final bool club; // chaîne d'un des deux clubs
  HlVideo(this.id, this.title, this.channel, this.embed, this.club);
  String get url => 'https://www.youtube.com/watch?v=$id';
  String get thumb => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
}

/// Liste des temps forts trouvés par KOUNADIA (mise à jour toutes les 30 minutes).
class Highlights {
  static const _url = 'https://raw.githubusercontent.com/barroapk/kfeed/hl/hl.json';
  static final changed = ValueNotifier<int>(0);
  static Map<String, HlVideo> _v = {};
  static DateTime? _at;
  static Future<void>? _running;

  static HlVideo? of(int matchId) => _v['$matchId'];

  /// Charge la liste si elle a plus de 10 minutes (ou jamais chargée).
  static Future<void> load({bool force = false}) {
    if (!force && _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 10)) return Future.value();
    return _running ??= _load().whenComplete(() => _running = null);
  }

  static Future<void> _load() async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
      if (_v.isEmpty) _parse(p.getString('k_hl'));
      final r = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final body = utf8.decode(r.bodyBytes);
        if (_parse(body)) await p.setString('k_hl', body);
      }
      _at = DateTime.now();
    } catch (_) {
      _at = DateTime.now().subtract(const Duration(minutes: 8)); // nouvel essai dans 2 minutes
    }
  }

  static bool _parse(String? body) {
    if (body == null || body.isEmpty) return false;
    try {
      final v = (jsonDecode(body) as Map)['v'];
      if (v is! Map) return false;
      final out = <String, HlVideo>{};
      v.forEach((k, x) {
        if (x is! Map || x['v'] == null) return;
        out['$k'] = HlVideo('${x['v']}', '${x['t'] ?? ''}', '${x['c'] ?? ''}', x['e'] != 0, x['k'] == 'club');
      });
      final diff = out.length != _v.length || out.keys.any((k) => _v[k]?.id != out[k]!.id);
      _v = out;
      if (diff) changed.value++;
      return true;
    } catch (_) {
      return false;
    }
  }
}
