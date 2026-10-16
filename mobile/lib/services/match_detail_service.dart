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

class GameRow {
  final String date;
  final String home;
  final String away;
  final String score;
  final String? outcome;
  final bool homeBold;
  final bool awayBold;
  const GameRow(this.date, this.home, this.away, this.score, this.outcome, this.homeBold, this.awayBold);
}

class StandRow {
  final int pos;
  final String team;
  final String zone;
  final String mp, w, d, l, gf, ga, diff, pts;
  const StandRow(this.pos, this.team, this.zone, this.mp, this.w, this.d, this.l, this.gf, this.ga,
      this.diff, this.pts);
}

class StatRow {
  final String label;
  final String a;
  final String b;
  const StatRow(this.label, this.a, this.b);
}

class LeagueStat {
  final String label;
  final String value;
  final bool header;
  const LeagueStat(this.label, this.value, this.header);
}

class MatchDetail {
  final String? homeLogo;
  final String? awayLogo;
  final String? liveScore;
  final String? liveStatus;
  final String? updated;
  final List<Market> markets;
  final List<GameRow> h2h;
  final List<GameRow> homeForm;
  final List<GameRow> awayForm;
  final List<GameRow> homeNext;
  final List<GameRow> awayNext;
  final String tableTitle;
  final List<StandRow> table;
  final List<StatRow> teamStats;
  final List<LeagueStat> leagueStats;
  final String leagueStatsTitle;

  const MatchDetail({
    this.homeLogo,
    this.awayLogo,
    this.liveScore,
    this.liveStatus,
    this.updated,
    required this.markets,
    this.h2h = const [],
    this.homeForm = const [],
    this.awayForm = const [],
    this.homeNext = const [],
    this.awayNext = const [],
    this.tableTitle = '',
    this.table = const [],
    this.teamStats = const [],
    this.leagueStats = const [],
    this.leagueStatsTitle = '',
  });
}

const _fr = {
  'Wins': 'Victoires',
  'Draws': 'Nuls',
  'Losses': 'Défaites',
  'Goals For': 'Buts marqués',
  'Goals Against': 'Buts encaissés',
  'Average Scored': 'Moy. buts marqués',
  'Average Conceded': 'Moy. buts encaissés',
  'Matches Scored': 'A marqué',
  'Matches Conceded': 'A encaissé',
  'Both Teams to Score': 'Les deux marquent',
  'Over 1.5': '+1,5 buts',
  'Over 2.5': '+2,5 buts',
  'Over 3.5': '+3,5 buts',
  'Home Win': 'Victoire domicile',
  'Draw': 'Match nul',
  'Away Win': 'Victoire extérieur',
  'Completed Matches': 'Matchs joués',
  'Goals per Game': 'Buts par match',
  'Home Goals per Game': 'Buts domicile / match',
  'Away Goals per Game': 'Buts extérieur / match',
  'Home Team Scored in': 'Domicile a marqué',
  'Away Team Scored in': 'Extérieur a marqué',
};

String frLabel(String s) => _fr[s.trim()] ?? s.trim();

class MatchDetailService {
  static const _base = 'https://primatips.com';
  static const _ua = {'User-Agent': 'KOUNADIA-App/1.0 (+https://github.com/barroapk/kounadia-data)'};

  static String _txt(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _abs(String u) => u.startsWith('http') ? u : '$_base$u';

  static Future<MatchDetail> load(LiveMatch m) async {
    try {
      final r = await http.get(Uri.parse(m.url), headers: _ua).timeout(const Duration(seconds: 20));
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

  static List<Market> _markets(String h) {
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

      final probs = rowCells('Probability').map((v) => int.tryParse(v.replaceAll('%', '').trim())).toList();
      final tipM = RegExp(r'<td class="tip ?([a-z ]*)"[^>]*>([^<]+)</td>').firstMatch(table);
      if (tipM == null) continue;
      final cls = tipM[1]!.trim();
      final parts = _txt(tipM[2]!).split('@');
      final pick = parts.first.trim();
      final odd = parts.length > 1 ? parts[1].trim() : '';
      var label = pick;
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
    return markets;
  }

  static List<GameRow> _games(String t) {
    final out = <GameRow>[];
    for (final r in RegExp(r'<tr[^>]*>([\s\S]*?)</tr>').allMatches(t)) {
      final row = r[1]!;
      final hm = RegExp(r'class="hteam"[^>]*>([\s\S]*?)</td>').firstMatch(row)?[1];
      final am = RegExp(r'class="ateam"[^>]*>([\s\S]*?)</td>').firstMatch(row)?[1];
      final res = RegExp(r'class="result ?([a-z]*)"[^>]*>([\s\S]*?)</td>').firstMatch(row);
      if (hm == null || am == null || res == null) continue;
      final date = _txt(RegExp(r'class="date"[^>]*>([\s\S]*?)</td>').firstMatch(row)?[1] ?? '');
      final cls = res[1]!;
      out.add(GameRow(date, _txt(hm), _txt(am), _txt(res[2]!), cls.isEmpty ? null : cls,
          hm.contains('<b>'), am.contains('<b>')));
    }
    return out;
  }

  static List<StandRow> standing(String t) {
    final rows = <StandRow>[];
    for (final r in RegExp(r'<tr[^>]*>([\s\S]*?)</tr>').allMatches(t)) {
      final row = r[1]!;
      final p = RegExp(r'<td class="position[^"]*"(?:\s+title="([^"]*)")?[^>]*>\s*(\d+)\s*</td>').firstMatch(row);
      if (p == null) continue;
      final team = _txt(RegExp(r'class="team"[^>]*>([\s\S]*?)</td>').firstMatch(row)?[1] ?? '');
      final n = RegExp(r'<td class="(?:matches|goals|diff|points)[^"]*">([^<]*)</td>')
          .allMatches(row)
          .map((x) => _txt(x[1]!))
          .toList();
      if (n.length < 8) continue;
      rows.add(StandRow(int.parse(p[2]!), team, p[1] ?? '', n[0], n[1], n[2], n[3], n[4], n[5], n[6], n[7]));
    }
    return rows;
  }

  static List<StatRow> _perft(String t) {
    final out = <StatRow>[];
    for (final r in RegExp(r'<tr[^>]*>([\s\S]*?)</tr>').allMatches(t)) {
      final row = r[1]!;
      final cap = RegExp(r'<td class="caption[^"]*"[^>]*>([\s\S]*?)</td>').firstMatch(row);
      final vals = RegExp(r'<td class="pos[^"]*"[^>]*>([^<]*)</td>').allMatches(row).map((x) => _txt(x[1]!)).toList();
      if (cap == null || vals.length < 2) continue;
      out.add(StatRow(frLabel(_txt(cap[1]!)), vals[0], vals[1]));
    }
    return out;
  }

  static List<LeagueStat> _lperf(String t) {
    final out = <LeagueStat>[];
    for (final r in RegExp(r'<tr[^>]*>([\s\S]*?)</tr>').allMatches(t)) {
      final row = r[1]!;
      final cap = RegExp(r'<td class="caption"[^>]*>([\s\S]*?)</td>').firstMatch(row);
      if (cap != null) {
        final c = _txt(cap[1]!).replaceFirst('Matches', 'Matchs').replaceFirst('Goals', 'Buts');
        out.add(LeagueStat(c, '', true));
        continue;
      }
      final lab = RegExp(r'class="label[^"]*"[^>]*>([\s\S]*?)</td>').firstMatch(row);
      final data = RegExp(r'class="data[^"]*"[^>]*>([^<]*)</td>').firstMatch(row);
      if (lab == null || data == null) continue;
      out.add(LeagueStat(frLabel(_txt(lab[1]!)), _txt(data[1]!), false));
    }
    return out;
  }

  static MatchDetail _parse(String h) {
    final imgs = RegExp(r'<img class="football-team" src="([^"]+)"').allMatches(h).map((x) => _abs(x[1]!)).toList();

    var h2h = <GameRow>[];
    final forms = <List<GameRow>>[];
    final nexts = <List<GameRow>>[];
    var table = <StandRow>[];
    var tableTitle = '';
    var teamStats = <StatRow>[];
    var leagueStats = <LeagueStat>[];
    var leagueTitle = '';

    final secRe = RegExp(
        r'<h2 class="games-title">([\s\S]*?)</h2>((?:(?!<h2)[\s\S])*?)<table class="([a-z-]+)">([\s\S]*?)</table>');
    for (final s in secRe.allMatches(h)) {
      final title = _txt(s[1]!);
      final cls = s[3]!;
      final body = s[4]!;
      switch (cls) {
        case 'games-stat':
          if (title.startsWith('H2H')) {
            h2h = _games(body);
          } else if (title.contains('last 12')) {
            forms.add(_games(body));
          }
          break;
        case 'next-games':
          nexts.add(_games(body));
          break;
        case 'standing':
          if (table.isEmpty) {
            table = standing(body);
            tableTitle = title.replaceFirst(RegExp(r'^Table\s+'), '');
          }
          break;
        case 'perft':
          if (teamStats.isEmpty) teamStats = _perft(body);
          break;
        case 'lperf':
          if (leagueStats.isEmpty) {
            leagueStats = _lperf(body);
            leagueTitle = title.replaceFirst(RegExp(r'^Overall Statistics for\s+'), '');
          }
          break;
      }
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
      markets: _markets(h),
      h2h: h2h,
      homeForm: forms.isNotEmpty ? forms[0] : const [],
      awayForm: forms.length > 1 ? forms[1] : const [],
      homeNext: nexts.isNotEmpty ? nexts[0] : const [],
      awayNext: nexts.length > 1 ? nexts[1] : const [],
      tableTitle: tableTitle,
      table: table,
      teamStats: teamStats,
      leagueStats: leagueStats,
      leagueStatsTitle: leagueTitle,
    );
  }
}
