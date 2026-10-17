import 'dart:convert';
import 'package:http/http.dart' as http;
import 'kfeed.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_match.dart';
import 'kounadia_data_service.dart' show FriendlyError;

class ScoresService {
  static final _live = 'https://primatips.com/liveresults?day=0';
  static final _ua = {'User-Agent': 'KOUNADIA-App/1.0'};

  static Future<(Map<String, List<LiveMatch>>, bool)> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      final r = await KFeed.get('scores/scores.json?v=$bust').timeout(Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('indisponible');
      final body = utf8.decode(r.bodyBytes);
      final days = _parse(body);
      await prefs.setString('kscores', body);
      return (days, false);
    } catch (e) {
      final cached = prefs.getString('kscores');
      if (cached != null) {
        try {
          return (_parse(cached), true);
        } catch (_) {}
      }
      throw FriendlyError(
          'Vous êtes hors connexion ou les scores sont momentanément indisponibles. Réessayez dans un instant.');
    }
  }

  static List<LiveMatch> _list(dynamic v) => ((v as List?) ?? [])
      .map((e) => LiveMatch.fromJson(e as Map<String, dynamic>))
      .toList();

  static Map<String, List<LiveMatch>> _parse(String body) {
    final d = jsonDecode(body) as Map<String, dynamic>;
    final days = d['days'];
    if (days is Map<String, dynamic>) {
      return days.map((k, v) => MapEntry(k, _list(v)));
    }
    return {(d['date'] ?? '').toString(): _list(d['matches'])};
  }

  static Future<List<Map<String, dynamic>>> live() async {
    final r = await http.get(Uri.parse(_live), headers: _ua).timeout(Duration(seconds: 10));
    if (r.statusCode != 200) return [];
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return (d is List) ? d.whereType<Map<String, dynamic>>().toList() : [];
  }
}

/// Direct PrimaTips : id -> (buts dom., buts ext., minute ou 'Fin').
Future<Map<int, (int?, int?, String)>> liveById() async {
  final out = <int, (int?, int?, String)>{};
  try {
    for (final l in await ScoresService.live()) {
      final id = (l['id'] as num?)?.toInt();
      if (id == null) continue;
      final st = (l['st'] ?? '').toString().trim();
      final fin = RegExp(r'^(FT|AET|PEN)', caseSensitive: false).hasMatch(st);
      final min = fin ? 'Fin' : RegExp(r'^\d').hasMatch(st) ? "$st'" : (st.toUpperCase() == 'HT' ? 'MT' : st);
      out[id] = ((l['hs'] as num?)?.toInt(), (l['as'] as num?)?.toInt(), min);
    }
  } catch (_) {}
  return out;
}
