import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_match.dart';
import 'kounadia_data_service.dart' show FriendlyError;

class ScoresService {
  static const _url =
      'https://raw.githubusercontent.com/barroapk/kounadia-data/scores/scores.json';
  static const _live = 'https://primatips.com/liveresults?day=0';
  static const _ua = {'User-Agent': 'KOUNADIA-App/1.0 (+https://github.com/barroapk/kounadia-data)'};

  static Future<(List<LiveMatch>, bool)> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      final r = await http.get(Uri.parse('$_url?v=$bust')).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('indisponible');
      final body = utf8.decode(r.bodyBytes);
      final list = _parse(body);
      await prefs.setString('kscores', body);
      return (list, false);
    } catch (e) {
      final cached = prefs.getString('kscores');
      if (cached != null) {
        try {
          return (_parse(cached), true);
        } catch (_) {}
      }
      throw const FriendlyError(
          'Vous êtes hors connexion ou les scores sont momentanément indisponibles. Réessayez dans un instant.');
    }
  }

  static List<LiveMatch> _parse(String body) {
    final d = jsonDecode(body) as Map<String, dynamic>;
    return ((d['matches'] as List?) ?? [])
        .map((e) => LiveMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> live() async {
    final r = await http.get(Uri.parse(_live), headers: _ua).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return const [];
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return (d is List) ? d.whereType<Map<String, dynamic>>().toList() : const [];
  }
}
