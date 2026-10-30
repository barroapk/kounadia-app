import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/live_match.dart';
import 'kounadia_data_service.dart' show FriendlyError;
import 'match_detail_service.dart' show StandRow, MatchDetailService;
import '../l10n/tr.dart' show appLang;
import 'live_socket.dart' show ptUrl;
import 'footlive_service.dart';
import '../config/countries.dart' show countryByIso;

class PtLink {
  final String name;
  final String path;
  final String img;
  PtLink(this.name, this.path, this.img);
}

class PtSection {
  final String title;
  final List<PtLink> items;
  PtSection(this.title, this.items);
}

class PtTable {
  final String title;
  final List<StandRow> rows;
  /// Classement footlive à charger quand on l'ouvre (lignes vides en attendant).
  final String? flPath;
  PtTable(this.title, this.rows, [this.flPath]);
}

class PtFormRow {
  final int pos;
  final String team, league, value, played, pct;
  PtFormRow(this.pos, this.team, this.league, this.value, this.played, this.pct);
}

class PtFormTable {
  final String title;
  final List<PtFormRow> rows;
  PtFormTable(this.title, this.rows);
}

class PtFact {
  final int id;
  final String url, day, hour, flag, country, league, home, away, score, status;
  final bool live, homeWin, awayWin;
  final List<double> odds;
  final List<String> facts;

  PtFact({
    required this.id,
    required this.url,
    required this.day,
    required this.hour,
    required this.flag,
    required this.country,
    required this.league,
    required this.home,
    required this.away,
    required this.score,
    required this.status,
    required this.live,
    required this.homeWin,
    required this.awayWin,
    required this.odds,
    required this.facts,
  });

  RegExpMatch? get _sc => RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(score);
  bool get hasScore => _sc != null;

  DateTime? get date {
    final d = DateTime.tryParse(day);
    final t = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hour);
    if (d == null || t == null) return null;
    return londonToLocal(d.year, d.month, d.day, int.parse(t[1]!), int.parse(t[2]!));
  }

  String get state => live
      ? 'live'
      : hasScore
          ? 'finished'
          : status.toLowerCase().startsWith('post')
              ? 'postponed'
              : 'upcoming';

  LiveMatch toMatch() {
    final s = _sc;
    return LiveMatch(
      id: id,
      url: url,
      date: date,
      country: country,
      league: league,
      flag: flag,
      home: home,
      away: away,
      probs: null,
      odds: odds.length == 3 ? odds : null,
      tip: '',
      tipOdd: null,
      tipStatus: 'pending',
      status: state,
      minute: live ? status : null,
      hs: s == null ? null : int.parse(s[1]!),
      as_: s == null ? null : int.parse(s[2]!),
    );
  }
}

final _namesFr = {
  'England': 'Angleterre', 'Germany': 'Allemagne', 'Italy': 'Italie', 'Spain': 'Espagne',
  'Netherlands': 'Pays-Bas', 'Belgium': 'Belgique', 'Scotland': 'Écosse', 'Switzerland': 'Suisse',
  'Turkey': 'Turquie', 'Greece': 'Grèce', 'Austria': 'Autriche', 'Denmark': 'Danemark',
  'Sweden': 'Suède', 'Norway': 'Norvège', 'Poland': 'Pologne', 'Russia': 'Russie',
  'Croatia': 'Croatie', 'Brazil': 'Brésil', 'Argentina': 'Argentine', 'Mexico': 'Mexique',
  'USA': 'États-Unis', 'Japan': 'Japon', 'China': 'Chine', 'South Korea': 'Corée du Sud',
  'Saudi Arabia': 'Arabie saoudite', 'Egypt': 'Égypte', 'Morocco': 'Maroc', 'Algeria': 'Algérie',
  'Tunisia': 'Tunisie', 'Ivory Coast': "Côte d'Ivoire", 'Cameroon': 'Cameroun',
  'South Africa': 'Afrique du Sud', 'Senegal': 'Sénégal', 'Wales': 'Pays de Galles',
  'Northern Ireland': 'Irlande du Nord', 'Ireland': 'Irlande', 'Czech Republic': 'Tchéquie',
  'Hungary': 'Hongrie', 'Romania': 'Roumanie', 'Bulgaria': 'Bulgarie', 'Serbia': 'Serbie',
  'Slovakia': 'Slovaquie', 'Slovenia': 'Slovénie', 'Finland': 'Finlande', 'Iceland': 'Islande',
  'Colombia': 'Colombie', 'Chile': 'Chili', 'Peru': 'Pérou', 'Australia': 'Australie',
  'Champions League': 'Ligue des champions', 'Europa League': 'Ligue Europa',
  'UEFA Conference League': 'Ligue Conférence', 'World Championship': 'Coupe du monde',
  'World Championship Qualification': 'Qualif. Coupe du monde',
  'Club World Championship': 'Coupe du monde des clubs',
  'European Championship Qualification': 'Qualif. Euro', 'UEFA Nations League': 'Ligue des nations',
};

String frName(String s) {
  final t = s.trim();
  if (appLang != 'fr') return t == 'Bosnia&Herz.' ? 'Bosnia-Herzegovina' : t; // noms d'origine (anglais)
  if (t == "Cote d'Ivoire") return "Côte d'Ivoire";
  if (t == 'Bosnia&Herz.') return 'Bosnie-Herzégovine';
  return _namesFr[t] ?? flFrName(t) ?? t;
}

String frLeague(String l) {
  final i = l.indexOf(' - ');
  return i < 0 ? l : frName(l.substring(0, i)) + ' - ' + l.substring(i + 3);
}

String _frSection(String t) {
  final s = t.toLowerCase();
  if (s.contains('major')) return 'Grands championnats';
  if (s.contains('international')) return 'Compétitions internationales';
  if (s.contains('africa')) return 'Afrique';
  if (s.contains('europe')) return 'Europe';
  if (s.contains('asia')) return 'Asie';
  if (s.contains('south america')) return 'Amérique du Sud';
  if (s.contains('america') || s.contains('concacaf')) return 'Amérique du Nord et centrale';
  if (s.contains('oceania')) return 'Océanie';
  return t;
}

String _sub(String s, String re, String tpl) => s.replaceAllMapped(RegExp(re, caseSensitive: false), (m) {
      var t = tpl;
      for (var i = 1; i <= m.groupCount; i++) {
        t = t.replaceAll('{$i}', m[i] ?? '');
      }
      return t;
    });

final _factRules = <(String, String)>[
  (r' as home team ', ' à domicile : '),
  (r' as away team ', " à l'extérieur : "),
  (r'no loss(?:es)? (?:from|in) (\d+) matches', 'aucune défaite en {1} matchs'),
  (r'no wins? (?:from|in) (\d+) matches', 'aucune victoire en {1} matchs'),
  (r'no draws? (?:from|in) (\d+) matches', 'aucun nul en {1} matchs'),
  (r'(\d+) wins? (?:from|in) (\d+) matches', '{1} victoire(s) en {2} matchs'),
  (r'(\d+) draws? (?:from|in) (\d+) matches', '{1} nul(s) en {2} matchs'),
  (r'(\d+) loss(?:es)? (?:from|in) (\d+) matches', '{1} défaite(s) en {2} matchs'),
  (r'only (\d+) scored goals? in (\d+) matches', 'seulement {1} but(s) marqué(s) en {2} matchs'),
  (r'only (\d+) conceded goals? in (\d+) matches', 'seulement {1} but(s) encaissé(s) en {2} matchs'),
  (r'(\d+) scored goals? in (\d+) matches', '{1} buts marqués en {2} matchs'),
  (r'(\d+) conceded goals? in (\d+) matches', '{1} buts encaissés en {2} matchs'),
  (r'both teams (?:to )?scored?', 'les deux équipes marquent'),
  (r'over (\d+)\.5', 'plus de {1},5'),
  (r'under (\d+)\.5', 'moins de {1},5'),
  (r' - (\d+)\.(\d+) per match', ' · {1},{2} par match'),
  (r' per match', ' par match'),
  (r'in a row', "d'affilée"),
  (r'\bmatches\b', 'matchs'),
  (r'\bgoals\b', 'buts'),
];

String frFact(String s) {
  var t = s.trim();
  for (final r in _factRules) {
    t = _sub(t, r.$1, r.$2);
  }
  return t;
}

class PrimaTipsService {
  static final base = 'https://primatips.com';
  static final _ua = {'User-Agent': 'KOUNADIA-App/1.0'};
  static final Map<String, (DateTime, String)> _cache = {};

  static String txt(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&#39;', "'")
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String abs(String u) => u.startsWith('http') ? u : '$base$u';

  static Future<String> _get(String path) async {
    final c = _cache[path];
    if (c != null && DateTime.now().difference(c.$1) < Duration(minutes: 10)) return c.$2;
    try {
      final r = await http.get(Uri.parse(ptUrl('$base$path')), headers: _ua).timeout(Duration(seconds: 20));
      if (r.statusCode != 200) {
        throw FriendlyError('Cette rubrique est momentanément indisponible. Réessayez dans un instant.');
      }
      final h = utf8.decode(r.bodyBytes).replaceAll(RegExp(r'\s+'), ' ');
      _cache[path] = (DateTime.now(), h);
      return h;
    } on FriendlyError {
      rethrow;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        throw FriendlyError('Vous êtes hors connexion. Vérifiez votre connexion internet puis réessayez.');
      }
      throw FriendlyError('Cette rubrique est momentanément indisponible. Réessayez dans un instant.');
    }
  }

  /// Nom comparable : sans accents, espaces ni ponctuation.
  static String _key(String s) {
    var t = s.toLowerCase();
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüÿ';
    const to = 'aaaaaaceeeeiiiinooooouuuuy';
    for (var i = 0; i < from.length; i++) {
      t = t.replaceAll(from[i], to[i]);
    }
    t = t.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (t == 'ivorycoast') return 'cotedivoire';
    if (t == 'drcongo' || t == 'congodr') return 'congokinshasa';
    return t;
  }

  static Future<List<PtSection>> countries() async {
    final h = await _get('/tables');
    final secs = <PtSection>[];
    for (final p in h.split('<div class="standing-header">').skip(1)) {
      final end = p.indexOf('</div>');
      if (end < 0) continue;
      final items = RegExp(r'<a href="(/tables/[^"]+)"><img class="[^"]*" src="([^"]+)"[^>]*>([^<]+)</a>')
          .allMatches(p)
          .map((m) => PtLink(txt(m[3]!), m[1]!, abs(m[2]!)))
          .toList();
      if (items.isNotEmpty) secs.add(PtSection(_frSection(txt(p.substring(0, end))), items));
    }
    // Pays footlive absents de PrimaTips : ajoutés dans leur continent.
    final known = {for (final s in secs) for (final l in s.items) _key(l.name)};
    List<FlCountry> extra = const [];
    try {
      extra = await FlCatalog.extraCountries();
    } catch (_) {}
    for (final c in [...kFlCountries, ...extra, ...kFlMore]) {
      final k = _key(c.en);
      // Déjà présent sous un autre nom (ex. « Ivory Coast » / « Côte d'Ivoire ») ?
      final kc = countryByIso(c.flag.length == 2 ? c.flag.toUpperCase() : null);
      final names = {k, _key(c.fr), if (kc != null) ...[_key(kc.name), ...kc.aliases.map(_key)]};
      if (names.any(known.contains)) continue;
      known.addAll(names);
      PtSection? sec;
      for (final s in secs) {
        if (s.title == c.section) sec = s;
      }
      if (sec == null) {
        sec = PtSection(c.section, []);
        secs.add(sec);
      }
      sec.items.add(PtLink(c.en, 'fl:${c.slug}', c.img));
    }
    int rank(PtSection s) => s.title == 'Grands championnats'
        ? 0
        : s.title == 'Afrique'
            ? 1
            : s.title == 'Compétitions internationales'
                ? 2
                : 3;
    final idx = {for (var i = 0; i < secs.length; i++) secs[i]: i};
    secs.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : idx[a]!.compareTo(idx[b]!);
    });
    return secs;
  }

  /// Classements d'un pays : PrimaTips + compétitions footlive en plus.
  /// [titlesOnly] : noms des compétitions seulement (Mes championnats), sans charger les classements footlive.
  static Future<List<PtTable>> countryTables(PtLink link, {bool titlesOnly = false}) async {
    FlCountry? fl;
    if (link.path.startsWith('fl:')) {
      final slug = link.path.substring(3);
      for (final c in kFlCountries) {
        if (c.slug == slug) fl = c;
      }
      if (fl == null) {
        for (final c in await FlCatalog.extraCountries()) {
          if (c.slug == slug) fl = c;
        }
      }
      if (fl == null) {
        for (final c in kFlMore) {
          if (c.slug == slug) fl = c;
        }
        // Pays sans compétition connue : liste vide, pas de message d'erreur.
        if (fl != null) {
          try {
            return await _flTables(fl, <PtTable>[], titlesOnly);
          } catch (_) {
            return <PtTable>[];
          }
        }
      }
      fl ??= FlCountry(slug, '', link.name, link.name, '');
    } else {
      fl = flCountryOf(link.name);
      if (fl == null) {
        final k = link.name.trim().toLowerCase();
        for (final c in await FlCatalog.extraCountries()) {
          if (c.en.toLowerCase() == k) fl = c;
        }
      }
    }
    final out = link.path.startsWith('fl:') ? <PtTable>[] : await tables(link.path);
    if (fl == null) return out;
    return _flTables(fl, out, titlesOnly);
  }

  static Future<List<PtTable>> _flTables(FlCountry fl, List<PtTable> out, bool titlesOnly) async {
    try {
      String n(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final have = out.map((t) => n(t.title)).toSet();
      for (final c in await FootliveService.competitions(fl)) {
        final k = n(c.title);
        if (have.any((h) => h.isNotEmpty && (h == k || h.contains(k) || k.contains(h)))) continue;
        if (!titlesOnly && c.standings == null) continue;
        out.add(PtTable(c.title, const [], c.standings));
      }
    } catch (e) {
      if (out.isEmpty) rethrow;
    }
    return out;
  }

  static Future<List<PtTable>> tables(String path) async {
    final h = await _get(path);
    final out = <PtTable>[];
    for (final m in RegExp(r'<table class="standing">([\s\S]*?)</table>').allMatches(h)) {
      final heads = RegExp(r'<h[1-3][^>]*>([\s\S]*?)</h[1-3]>').allMatches(h.substring(0, m.start));
      final title = heads.isEmpty ? '' : txt(heads.last[1]!).replaceFirst(RegExp(r'^Table\s+'), '');
      final rows = MatchDetailService.standing(m[1]!);
      if (rows.isNotEmpty) out.add(PtTable(title, rows));
    }
    return out;
  }

  static Future<List<PtFact>> facts(String day, {bool today = false}) async {
    final h = await _get(today ? '/facts' : '/facts/date-$day');
    final out = <PtFact>[];
    final re = RegExp(
        r'<a id="g_(\d+)" class="gma" href="([^"]+)">([\s\S]*?)</a>\s*<div class="fact">([\s\S]*?)</div>');
    for (final m in re.allMatches(h)) {
      final a = m[3]!;
      String sp(String c) =>
          txt(RegExp('<span class="$c(?: [^"]*)?"[^>]*>([\\s\\S]*?)</span\\s*>').firstMatch(a)?[1] ?? '');
      final img = RegExp(r'<img src="([^"]+)"[^>]*title="([^"]*)"').firstMatch(a);
      final title = img?[2] ?? '';
      final i = title.indexOf(' - ');
      final status = sp('status');
      final score = sp('res');
      final hasScore = RegExp(r'\d+\s*-\s*\d+').hasMatch(score);
      final fin = RegExp(r'^(FT|AET|Pen|AP)', caseSensitive: false).hasMatch(status);
      final facts = RegExp(r'<p>([\s\S]*?)</p>')
          .allMatches(m[4]!)
          .map((p) => frFact(txt(p[1]!.replaceAll('&#187;', ''))))
          .where((s) => s.isNotEmpty)
          .toList();
      out.add(PtFact(
        id: int.parse(m[1]!),
        url: abs(m[2]!),
        day: day,
        hour: sp('hour'),
        flag: img == null ? '' : abs(img[1]!),
        country: i < 0 ? title : title.substring(0, i),
        league: i < 0 ? '' : title.substring(i + 3),
        home: sp('ht1'),
        away: sp('at1'),
        score: score,
        status: status,
        live: hasScore && a.contains('class="res lv"') && status.isNotEmpty && !fin,
        homeWin: a.contains('class="ht1 win"'),
        awayWin: a.contains('class="at1 win"'),
        odds: [sp('ho1'), sp('do'), sp('ao1')].map(double.tryParse).whereType<double>().toList(),
        facts: facts,
      ));
    }
    return out;
  }

  static String _league(String t) {
    final p = t.split(' - ');
    return p.length == 2 ? '${p[0]} · ${frName(p[1])}' : t;
  }

  static Future<List<PtFormTable>> form(String key) async {
    final h = await _get('/form/$key');
    final out = <PtFormTable>[];
    for (final t in RegExp(r'<h2>([\s\S]*?)</h2>\s*<table class="form">([\s\S]*?)</table>').allMatches(h)) {
      final rows = <PtFormRow>[];
      for (final r in RegExp(r'<tr>([\s\S]*?)</tr>').allMatches(t[2]!)) {
        final row = r[1]!;
        final ps = RegExp(r'<td class="ps"[^>]*>\s*(\d+)\s*</td>').firstMatch(row);
        final tm = RegExp(r'<a class="tl" href="[^"]*" title="([^"]*)">([^<]*)</a>').firstMatch(row);
        if (ps == null || tm == null) continue;
        String cell(String c) => txt(RegExp('<td class="$c"[^>]*>([^<]*)</td>').firstMatch(row)?[1] ?? '');
        rows.add(PtFormRow(int.parse(ps[1]!), txt(tm[2]!), _league(tm[1]!), cell('sc'), cell('gm'), cell('pr')));
      }
      if (rows.isNotEmpty) out.add(PtFormTable(txt(t[1]!), rows));
    }
    return out;
  }
}

DateTime _lastSunday(int y, int m) {
  final d = DateTime.utc(y, m + 1, 0);
  return d.subtract(Duration(days: d.weekday % 7));
}

/// Heure de Londres (GMT l'hiver, GMT+1 l'été) -> heure du téléphone.
DateTime londonToLocal(int y, int mo, int d, int h, int mi) {
  final t = DateTime.utc(y, mo, d, h, mi);
  final start = _lastSunday(y, 3).add(Duration(hours: 1));
  final end = _lastSunday(y, 10).add(Duration(hours: 2));
  final summer = !t.isBefore(start) && t.isBefore(end);
  return (summer ? t.subtract(Duration(hours: 1)) : t).toLocal();
}
