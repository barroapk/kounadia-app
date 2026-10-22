import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'kfeed.dart';
import 'scores_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/forecast.dart';
import 'tip_eval.dart';
import '../models/live_match.dart';

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
  /// Jour affiché quand ce n'est pas aujourd'hui (pronostics de la veille gardés jusqu'aux nouveaux).
  final DateTime? iaDay, exDay;
  TodayData(this.ia, this.expert, this.offline, {this.iaDay, this.exDay});
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

  static final Map<String, (DateTime, dynamic, bool)> _mem = {};

  /// Lecture d'un fichier ; gardé 3 minutes en mémoire (la page se rafraîchit chaque minute).
  static Future<(dynamic, bool)> _get(String file) async {
    final c = _mem[file];
    if (c != null && DateTime.now().difference(c.$1) < const Duration(minutes: 3) && !c.$3) return (c.$2, c.$3);
    final r = await _fetch(file);
    _mem[file] = (DateTime.now(), r.$1, r.$2);
    return r;
  }

  static Future<(dynamic, bool)> _fetch(String file) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'kdata_$file';
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 300000;
      final r = await (file == 'today.json'
              ? KFeed.getPremium('pronos/$file', query: '?v=$bust')
              : KFeed.get('pronos/$file?v=$bust'))
          .timeout(Duration(seconds: 30));
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
    final prefs = await SharedPreferences.getInstance();
    // Pronostics du jour ; s'il n'y en a pas encore, on garde ceux de la veille.
    (List<Forecast>, DateTime?) parse(String k, String src) {
      final raw = ((m[k] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final keep = raw.where((e) => _isToday(Forecast.fromJson(e, src).date)).toList();
      var saved = <Map<String, dynamic>>[];
      try {
        final c = prefs.getString('klast_$k');
        if (c != null) saved = (jsonDecode(c) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
      if (keep.isNotEmpty) {
        // Les pronostics du jour déjà affichés restent, même si la source les retire (match commencé ou fini).
        final ids = keep.map((e) => '${e['id']}').toSet();
        for (final e in saved) {
          try {
            if (!ids.contains('${e['id']}') && _isToday(Forecast.fromJson(e, src).date)) keep.add(e);
          } catch (_) {}
        }
        prefs.setString('klast_$k', jsonEncode(keep));
      } else {
        keep.addAll(saved);
      }
      final list = keep.map((e) => Forecast.fromJson(e, src)).toList()..sort((a, b) => a.date.compareTo(b.date));
      final old = list.isNotEmpty && !_isToday(list.first.date);
      if (old && DateTime.now().difference(list.first.date).inHours > 36) return (<Forecast>[], null);
      return (list, old ? list.first.date : null);
    }
    var (ia, iaDay) = parse('ia', 'ia');
    var (ex, exDay) = parse('expert', 'expert');
    try {
      final res = <String, Map<String, dynamic>>{};
      // Résultats déjà vus sur ce téléphone (gardés même si la source ne les publie plus).
      try {
        for (final e in (jsonDecode(prefs.getString(_localKey) ?? '[]') as List).whereType<Map>()) {
          if (e['id'] != null) res[e['id'].toString()] = Map<String, dynamic>.from(e);
        }
      } catch (_) {}
      dynamic h = const [];
      try {
        h = (await _get('history.json')).$1;
      } catch (_) {}
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
      // Score et minute en direct : on cherche le match le plus ressemblant (noms écrits différemment selon les sites).
      Forecast live(Forecast f) {
        if (f.won != null) return f;
        final tol = f.hasTime ? 3 : 14;
        LiveMatch? best;
        var bs = 0.0;
        for (final m in all) {
          if (m.date != null && m.date!.difference(f.date).inHours.abs() > tol) continue;
          final s = matchSim(f.home, f.away, m.home, m.away);
          if (s > bs) {
            bs = s;
            best = m;
          }
        }
        final m = best;
        if (m == null) return f;
        final x = lv[m.id];
        final hs = x?.$1 ?? m.hs, aw = x?.$2 ?? m.as_;
        if (hs == null || aw == null) return f;
        if (x == null && m.status != 'live' && m.status != 'finished') return f;
        return settle(f.copyWith(
          score: '$hs-$aw',
          minute: x?.$3 ?? (m.status == 'finished' ? 'Fin' : m.minute),
        ));
      }
      ia = ia.map(live).toList();
      ex = ex.map(live).toList();
    } catch (_) {}
    await _keep([...ia, ...ex]);
    return TodayData(ia, ex, offline, iaDay: iaDay, exDay: exDay);
  }

  // ---------- Historique gardé sur le téléphone ----------
  // Les résultats vus dans « Prédictions » sont gardés 14 jours, même si la source ne les publie pas.
  static const _localKey = 'khist_local';

  static Map<String, dynamic> _toJson(Forecast f) => {
        'id': f.id, 'source': f.source, 'date': f.date.toUtc().toIso8601String(), 'hasTime': f.hasTime,
        'league': f.league, 'home': f.home, 'away': f.away, 'homeLogo': f.homeLogo, 'awayLogo': f.awayLogo,
        'tipFr': f.tipFr, 'predicted': f.predicted, 'confidence': f.confidence, 'score': f.score, 'won': f.won,
      };

  static Future<void> _keep(List<Forecast> list) async {
    final done = list.where((f) => f.won != null && f.id.isNotEmpty).toList();
    if (done.isEmpty) return;
    try {
      final p = await SharedPreferences.getInstance();
      final m = <String, Map<String, dynamic>>{};
      for (final e in (jsonDecode(p.getString(_localKey) ?? '[]') as List).whereType<Map>()) {
        m[e['id'].toString()] = Map<String, dynamic>.from(e);
      }
      var changed = false;
      for (final f in done) {
        if (m[f.id]?['won'] == f.won) continue;
        m[f.id] = _toJson(f);
        changed = true;
      }
      if (!changed) return;
      final min = DateTime.now().subtract(const Duration(days: 14));
      final keep = m.values.where((e) => (DateTime.tryParse('${e['date']}') ?? min).isAfter(min)).toList();
      await p.setString(_localKey, jsonEncode(keep.length > 3000 ? keep.sublist(keep.length - 3000) : keep));
    } catch (_) {}
  }

  static Future<HistoryData> history() async {
    final (data, offline) = await _get('history.json');
    final byId = <String, Forecast>{};
    try {
      final p = await SharedPreferences.getInstance();
      for (final e in (jsonDecode(p.getString(_localKey) ?? '[]') as List).whereType<Map>()) {
        final f = Forecast.fromJson(Map<String, dynamic>.from(e), (e['source'] ?? 'ia').toString());
        byId[f.id] = f;
      }
    } catch (_) {}
    for (final e in ((data is List) ? data : const []).whereType<Map>()) {
      final f = Forecast.fromJson(Map<String, dynamic>.from(e), (e['source'] ?? 'ia').toString());
      byId[f.id] = f; // le résultat publié par le serveur passe avant
    }
    final items = byId.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return HistoryData(items, offline);
  }
}
