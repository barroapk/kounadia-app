import '../models/forecast.dart';

// Reconnaître une même équipe malgré les écritures différentes selon les sites
// (« Man Utd » / « Manchester United », « Atlético » / « Atletico de Madrid »).
// Même règles que le moteur (kounadia-engine/scripts/settle.mjs).
const _fold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ă': 'a', 'ą': 'a', 'æ': 'ae', 'ç': 'c', 'ć': 'c', 'č': 'c',
  'ď': 'd', 'đ': 'd', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ě': 'e', 'ę': 'e', 'ğ': 'g', 'ì': 'i', 'í': 'i', 'î': 'i',
  'ï': 'i', 'ı': 'i', 'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
  'ő': 'o', 'œ': 'oe', 'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', 'ș': 's', 'ß': 'ss', 'ť': 't', 'ţ': 't', 'ț': 't', 'ù': 'u',
  'ú': 'u', 'û': 'u', 'ü': 'u', 'ů': 'u', 'ű': 'u', 'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
};
const _stop = {
  'fc', 'cf', 'sc', 'afc', 'ac', 'as', 'cd', 'ud', 'sd', 'club', 'de', 'del', 'la', 'le', 'the', 'and', 'of', 'sk', 'fk', 'if',
  'bk', 'calcio', 'sv', 'vfl', 'vfb', 'tsv', 'us', 'ss', 'cs', 'ca', 'cr', 'ec', 'se', 'fbc', 'cfc', 'nk', 'hc', 'kv',
};
const _syn = {'utd': 'united', 'man': 'manchester', 'st': 'saint', 'intl': 'international'};
// Mots très fréquents dans les noms de clubs : ils comptent peu (Real Madrid ≠ Real Betis).
const _weak = {
  'real', 'united', 'city', 'sporting', 'athletic', 'atletico', 'inter', 'dynamo', 'dinamo', 'olympique', 'racing',
  'deportivo', 'union', 'nacional', 'saint', 'town', 'county', 'rovers', 'wanderers', 'albion', 'sport', 'club', 'esporte',
  'clube', 'football', 'university', 'universidad', 'cd', 'sv', 'young', 'boys', 'stade', 'stadium', 'association', 'fc',
};

List<String> teamTokens(String s) {
  final f = s.toLowerCase().split('').map((c) => _fold[c] ?? c).join();
  return f
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .split(' ')
      .where((t) => t.isNotEmpty)
      .map((t) => _syn[t] ?? t)
      .where((t) => t.length > 1 && !_stop.contains(t))
      .toList();
}

double _tok(String a, String b) {
  if (a == b) return 1.0;
  final n = a.length < b.length ? a.length : b.length;
  return n >= 4 && (a.startsWith(b) || b.startsWith(a)) ? 0.9 : 0.0;
}

double _wt(String t) => _weak.contains(t) ? 0.3 : 1.0;

double teamSim(String x, String y) {
  final a = teamTokens(x), b = teamTokens(y);
  if (a.isEmpty || b.isEmpty) return 0.0;
  if (a.join() == b.join()) return 1.0;
  double best(String t, List<String> other) => other.map((o) => _tok(t, o)).fold(0.0, (m, v) => v > m ? v : m);
  final sa = a.fold<double>(0.0, (s, t) => s + _wt(t) * best(t, b));
  final sb = b.fold<double>(0.0, (s, t) => s + _wt(t) * best(t, a));
  final w = a.fold<double>(0.0, (s, t) => s + _wt(t)) + b.fold<double>(0.0, (s, t) => s + _wt(t));
  return (sa + sb) / w;
}

/// Même match si les deux équipes se ressemblent assez (0 = non).
double matchSim(String h1, String a1, String h2, String a2) {
  final h = teamSim(h1, h2), a = teamSim(a1, a2);
  final lo = h < a ? h : a;
  return lo >= 0.34 && (h + a) / 2 >= 0.6 ? (h + a) / 2 : 0.0;
}

/// 'h', 'a' ou null : à quelle équipe du match correspond ce nom ?
String? _side(String team, String home, String away) {
  final sh = teamSim(team, home), sa = teamSim(team, away);
  if (sh >= 0.5 && sh > sa) return 'h';
  if (sa >= 0.5 && sa > sh) return 'a';
  return null;
}

/// Pari codé (1, X, 2, 1X, X2, 12, BTS, OTS, O25, U35…) : gagné ?
bool? evalCode(String pick, int h, int a) {
  switch (pick.toUpperCase()) {
    case '1':
      return h > a;
    case 'X':
      return h == a;
    case '2':
      return a > h;
    case '1X':
      return h >= a;
    case 'X2':
      return a >= h;
    case '12':
      return h != a;
    case 'BTS':
      return h > 0 && a > 0;
    case 'OTS':
      return h == 0 || a == 0;
  }
  final g = RegExp(r'^([OU])(\d)(\d)$').firstMatch(pick.toUpperCase());
  if (g != null) {
    final line = int.parse(g[2]!) + int.parse(g[3]!) / 10;
    return g[1] == 'O' ? h + a > line : h + a < line;
  }
  return null;
}

/// Pari écrit en français (« Victoire X », « Plus de 2,5 buts »…) : gagné ?
bool? evalTip(String tip, String home, String away, int h, int a) {
  final t = tip.trim();
  final l = t.toLowerCase();
  if (l == 'match nul') return h == a;
  if (l == 'pas de match nul') return h != a;
  if (l.startsWith('les 2 équipes marquent') || l.startsWith('les deux équipes marquent')) {
    if (l.endsWith('oui')) return h > 0 && a > 0;
    if (l.endsWith('non')) return h == 0 || a == 0;
    return null;
  }
  final g = RegExp(r'^(plus|moins) de (\d+(?:[.,]\d+)?) buts?').firstMatch(l);
  if (g != null) {
    final line = double.parse(g[2]!.replaceAll(',', '.'));
    return g[1] == 'plus' ? h + a > line : h + a < line;
  }
  if (l.endsWith(' ou nul')) {
    final s = _side(t.substring(0, t.length - 7), home, away);
    return s == 'h' ? h >= a : s == 'a' ? a >= h : null;
  }
  if (l.startsWith('victoire ')) {
    final s = _side(t.substring(9), home, away);
    return s == 'h' ? h > a : s == 'a' ? a > h : null;
  }
  return null;
}

/// Match terminé sans statut : calcule gagné / perdu à partir du score final.
Forecast settle(Forecast f, {String? code}) {
  if (f.won != null || f.minute != 'Fin') return f;
  final m = RegExp(r'(\d+)\s*[-:]\s*(\d+)').firstMatch(f.score ?? '');
  if (m == null) return f;
  final h = int.parse(m[1]!), a = int.parse(m[2]!);
  var w = (code != null && code.isNotEmpty) ? evalCode(code, h, a) : null;
  w ??= evalTip(f.tipFr, f.home, f.away, h, a);
  if (w == null && f.predicted != null) {
    final p = RegExp(r'(\d+)\s*[-:]\s*(\d+)').firstMatch(f.predicted!);
    if (p != null) {
      final ph = int.parse(p[1]!), pa = int.parse(p[2]!);
      w = (ph - pa).sign == (h - a).sign;
    }
  }
  return w == null ? f : f.copyWith(won: w);
}
