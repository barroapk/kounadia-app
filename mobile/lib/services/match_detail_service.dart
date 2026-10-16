import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/live_match.dart';
import 'kounadia_data_service.dart' show FriendlyError;
import 'logo_cache.dart';

class Market {
  final String name;
  final String pick;
  final String odd;
  final int? prob;
  final String status;

  const Market(this.name, this.pick, this.odd, this.prob, this.status);

  String get nameFr {
    final n = name.trim();
    if (n == 'Standard 1X2') return 'Résultat du match';
    if (n == 'Double Chance') return 'Double chance';
    if (n == 'Both Teams to Score') return 'Les deux équipes marquent';
    final g = RegExp(r'Over/Under\s+([\d.]+)').firstMatch(n);
    if (g != null) return 'Plus/Moins ${g[1]!.replaceAll('.', ',')} buts';
    return n;
  }

  String pickFr(String home, String away) {
    final p = pick.trim();
    switch (p.toUpperCase()) {
      case '1':
        return 'Victoire $home';
      case 'X':
        return 'Match nul';
      case '2':
        return 'Victoire $away';
      case '1X':
        return '$home ou nul';
      case 'X2':
        return '$away ou nul';
      case '12':
        return 'Pas de match nul';
      case 'BTS':
        return 'Oui';
      case 'OTS':
        return 'Non';
    }
    final g = RegExp(r'^(Over|Under)\s+([\d.]+)', caseSensitive: false).firstMatch(p);
    if (g != null) {
      return '${g[1]!.toLowerCase() == 'over' ? 'Plus' : 'Moins'} de ${g[2]!.replaceAll('.', ',')} buts';
    }
    return p;
  }
}

class MatchDetail {
  final String? homeLogo;
  final String? awayLogo;
  final String? liveScore;
  final String? liveStatus;
  final String? updated;
  final List<Market> markets;

  const MatchDetail({
    this.homeLogo,
    this.awayLogo,
    this.liveScore,
    this.liveStatus,
    this.updated,
    required this.markets,
  });
}

class MatchDetailService {
  static const _base = 'https://primatips.com';
  static const _ua = {'User-Agent': 'KOUNADIA-App/1.0 (+https://github.com/barroapk/kounadia-data)'};

  static String _txt(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .trim();

  static String _abs(String u) => u.startsWith('http') ? u : '$_base$u';

  static Future<MatchDetail> load(LiveMatch m) async {
    try {
      final r = await http
          .get(Uri.parse(m.url), headers: _ua)
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) {
        throw const FriendlyError('Les détails de ce match sont momentanément indisponibles.');
      }
      final d = _parse(utf8.decode(r.bodyBytes));
      if (d.homeLogo != null) await LogoCache.put(m.home, d.homeLogo!);
      if (d.awayLogo != null) await LogoCache.put(m.away, d.awayLogo!);
      return d;
    } on FriendlyError {
      rethrow;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        throw const FriendlyError('Vous êtes hors connexion. Vérifiez votre connexion internet puis réessayez.');
      }
      throw const FriendlyError('Les détails de ce match sont momentanément indisponibles.');
    }
  }

  static MatchDetail _parse(String h) {
    final imgs = RegExp(r'<img class="football-team" src="([^"]+)"')
        .allMatches(h)
        .map((x) => _abs(x[1]!))
        .toList();

    final markets = <Market>[];
    for (final t in RegExp(r'<table class="odds">([\s\S]*?)</table>').allMatches(h)) {
      final table = t[1]!;
      final name = _txt(RegExp(r'class="dce">([^<]+)</span>').firstMatch(table)?[1] ?? '');
      final labels = RegExp(r'<th>([^<]*)</th>').allMatches(table).map((x) => _txt(x[1]!)).toList();
      List<String> rowCells(String key) {
        for (final row in RegExp(r'<tr>([\s\S]*?)</tr>').allMatches(table)) {
          final rr = row[1]!;
          if (!rr.contains(key)) continue;
          return RegExp(r'<td class="odd[^"]*">([^<]*)</td>')
              .allMatches(rr)
              .map((x) => _txt(x[1]!))
              .where((v) => v.isNotEmpty)
              .toList();
        }
        return const [];
      }

      final probs = rowCells('Probability')
          .map((v) => int.tryParse(v.replaceAll('%', '').trim()))
          .toList();
      final tipM = RegExp(r'<td class="tip ?([a-z ]*)"[^>]*>([^<]+)</td>').firstMatch(table);
      if (tipM == null) continue;
      final cls = tipM[1]!.trim();
      final parts = _txt(tipM[2]!).split('@');
      final pick = parts.first.trim();
      final odd = parts.length > 1 ? parts[1].trim() : '';
      String label = pick;
      if (pick.toLowerCase().startsWith('over')) label = 'Ovr';
      if (pick.toLowerCase().startsWith('under')) label = 'Und';
      final idx = labels.indexOf(label);
      final prob = (idx >= 0 && idx < probs.length) ? probs[idx] : null;
      final status = RegExp(r'\b(win|wn|won)\b').hasMatch(cls)
          ? 'won'
          : RegExp(r'\b(loss|ls|lost|lose)\b').hasMatch(cls)
              ? 'lost'
              : 'pending';
      markets.add(Market(name, pick, odd, prob, status));
    }

    String? one(String re) {
      final x = RegExp(re).firstMatch(h);
      return x == null ? null : _txt(x[1]!);
    }

    return MatchDetail(
      homeLogo: imgs.isNotEmpty ? imgs[0] : null,
      awayLogo: imgs.length > 1 ? imgs[1] : null,
      liveScore: one(r'id="live-score"[^>]*>([\s\S]*?)</div>'),
      liveStatus: one(r'id="live-status"[^>]*>([\s\S]*?)</div>'),
      updated: one(r'last update ([0-9-]+ [0-9:]+)'),
      markets: markets,
    );
  }
}
