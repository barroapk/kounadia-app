import 'dart:convert';
import 'package:http/http.dart' as http;
import 'kfeed.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_match.dart';
import 'kounadia_data_service.dart' show FriendlyError;
import 'fav_leagues.dart';
import 'notif.dart';
import 'live_socket.dart' show LiveSocket, ptUrl;

class ScoresService {
  static final _live = 'https://primatips.com/liveresults?day=0';
  static final _ua = {'User-Agent': 'KOUNADIA-App/1.0'};

  /// [quiet] : lecture seule (coupons en direct), sans mise à jour des favoris ni des abonnements aux notifications.
  static Future<(Map<String, List<LiveMatch>>, bool)> load({bool quiet = false}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      final r = await KFeed.get('scores/scores.json?v=$bust').timeout(Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('indisponible');
      final body = utf8.decode(r.bodyBytes);
      final days = _parse(body);
      if (!quiet) {
        FavLeagues.autoSeed(days.values.expand((l) => l).map((m) => m.leagueLabel));
        Notif.leagues(days.values.expand((l) => l).map((m) => m.leagueLabel));
      }
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
    Future<List<Map<String, dynamic>>> one(String u) async {
      final r = await http.get(Uri.parse(ptUrl(u)), headers: _ua).timeout(Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      return (d is List) ? d.whereType<Map<String, dynamic>>().toList() : [];
    }

    final today = await one(_live);
    // Après minuit : les matchs d'hier soir sont dans la liste d'hier (jusqu'à 5 h).
    if (DateTime.now().toUtc().hour >= 5) return today;
    try {
      final ids = {for (final x in today) '${x['id']}'};
      return [...today, ...(await one(_live.replaceFirst('day=0', 'day=-1'))).where((x) => !ids.contains('${x['id']}'))];
    } catch (_) {
      return today;
    }
  }
}

/// Direct PrimaTips : id -> (buts dom., buts ext., minute ou 'Fin').
String _minute(String st) {
  final fin = RegExp(r'^(FT|AET|PEN)', caseSensitive: false).hasMatch(st);
  return fin ? 'Fin' : RegExp(r'^\d').hasMatch(st) ? "$st'" : (st.toUpperCase() == 'HT' ? 'MT' : st);
}

/// Direct de chaque match : score + minute. Utilise d'abord le direct du robot (à la seconde),
/// sinon interroge le site (secours).
Future<Map<int, (int?, int?, String)>> liveById() async {
  final out = <int, (int?, int?, String)>{};
  if (LiveSocket.fresh && LiveSocket.last.isNotEmpty) {
    LiveSocket.last.forEach((id, v) => out[id] = (v.$1, v.$2, _minute(v.$3.trim())));
    return out;
  }
  try {
    for (final l in await ScoresService.live()) {
      final id = (l['id'] as num?)?.toInt();
      if (id == null) continue;
      out[id] = ((l['hs'] as num?)?.toInt(), (l['as'] as num?)?.toInt(), _minute((l['st'] ?? '').toString().trim()));
    }
  } catch (_) {}
  return out;
}
