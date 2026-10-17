import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'kfeed.dart';
import 'scores_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/forecast.dart';

class FriendlyError implements Exception {
  final String message;
  FriendlyError(this.message);
  @override
  String toString() => message;
}

class TodayData {
  final List<Forecast> ia;
  final List<Forecast> expert;
  final bool offline;
  TodayData(this.ia, this.expert, this.offline);
}

class HistoryData {
  final List<Forecast> items;
  final bool offline;
  HistoryData(this.items, this.offline);
}

class KounadiaData {

  static String _friendly(Object e) {
    if (e is SocketException || e is TimeoutException || e is http.ClientException) {
      return 'Vous êtes hors connexion. Vérifiez votre connexion internet puis réessayez.';
    }
    return 'Les pronostics sont momentanément indisponibles. Réessayez dans quelques instants.';
  }

  static Future<(dynamic, bool)> _get(String file) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'kdata_$file';
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 300000;
      final r = await KFeed.get('pronos/$file?v=$bust')
          .timeout(Duration(seconds: 20));
      if (r.statusCode != 200) throw HttpException('indisponible');
      final body = utf8.decode(r.bodyBytes);
      final data = jsonDecode(body);
      await prefs.setString(key, body);
      return (data, false);
    } catch (e) {
      final cached = prefs.getString(key);
      if (cached != null) {
        try {
          return (jsonDecode(cached), true);
        } catch (_) {}
      }
      throw FriendlyError(_friendly(e));
    }
  }

  static bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  static Future<TodayData> today() async {
    final (data, offline) = await _get('today.json');
    final m = (data is Map<String, dynamic>) ? data : <String, dynamic>{};
    List<Forecast> parse(String k, String src) => ((m[k] as List?) ?? [])
        .map((e) => Forecast.fromJson(e as Map<String, dynamic>, src))
        .where((f) => _isToday(f.date))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    var ia = parse('ia', 'ia');
    var ex = parse('expert', 'expert');
    try {
      final (h, _) = await _get('history.json');
      final res = <String, Map<String, dynamic>>{};
      for (final e in (h is List ? h : const [])) {
        if (e is Map && e['id'] != null) res[e['id'].toString()] = Map<String, dynamic>.from(e);
      }
      Forecast merge(Forecast f) {
        final r = res[f.id];
        if (r == null || r['won'] is! bool) return f;
        return Forecast(
          id: f.id, source: f.source, date: f.date, hasTime: f.hasTime, league: f.league,
          home: f.home, away: f.away, homeLogo: f.homeLogo, awayLogo: f.awayLogo,
          homeColors: f.homeColors, awayColors: f.awayColors, tipFr: f.tipFr, predicted: f.predicted,
          confidence: f.confidence, agree: f.agree, models: f.models,
          score: r['score']?.toString(), won: r['won'] as bool,
        );
      }
      ia = ia.map(merge).toList();
      ex = ex.map(merge).toList();
    } catch (_) {}
    try {
      final (days, _) = await ScoresService.load();
      final all = [for (final l in days.values) ...l];
      final lv = await liveById();
      Forecast live(Forecast f) {
        if (f.won != null) return f;
        final tol = f.hasTime ? 3 : 14;
        for (final m in all) {
          final x = lv[m.id];
          final hs = x?.$1 ?? m.hs, aw = x?.$2 ?? m.as_;
          if (hs == null || aw == null) continue;
          if (x == null && m.status != 'live' && m.status != 'finished') continue;
          if (m.date != null && m.date!.difference(f.date).inHours.abs() > tol) continue;
          if (!_same(m.home, f.home) || !_same(m.away, f.away)) continue;
          return Forecast(
            id: f.id, source: f.source, date: f.date, hasTime: f.hasTime, league: f.league,
            home: f.home, away: f.away, homeLogo: f.homeLogo, awayLogo: f.awayLogo,
            homeColors: f.homeColors, awayColors: f.awayColors, tipFr: f.tipFr, predicted: f.predicted,
            confidence: f.confidence, agree: f.agree, models: f.models,
            score: '$hs-$aw', won: null,
            minute: x?.$3 ?? (m.status == 'finished' ? 'Fin' : m.minute),
          );
        }
        return f;
      }
      ia = ia.map(live).toList();
      ex = ex.map(live).toList();
    } catch (_) {}
    return TodayData(ia, ex, offline);
  }

  static Future<HistoryData> history() async {
    final (data, offline) = await _get('history.json');
    final items = ((data is List) ? data : [])
        .map((e) => Forecast.fromJson(
            e as Map<String, dynamic>, (e['source'] ?? 'ia').toString()))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return HistoryData(items, offline);
  }
}

String _nm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
bool _same(String a, String b) {
  final x = _nm(a), y = _nm(b);
  if (x.isEmpty || y.isEmpty) return false;
  return x == y || (x.length >= 5 && y.length >= 5 && (x.contains(y) || y.contains(x)));
}
