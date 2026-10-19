import '../models/forecast.dart';

String _n(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _sameTeam(String a, String b) {
  final x = _n(a), y = _n(b);
  if (x.isEmpty || y.isEmpty) return false;
  return x == y || (x.length >= 4 && y.length >= 4 && (x.contains(y) || y.contains(x)));
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
    final team = t.substring(0, t.length - 7);
    if (_sameTeam(team, home)) return h >= a;
    if (_sameTeam(team, away)) return a >= h;
    return null;
  }
  if (l.startsWith('victoire ')) {
    final team = t.substring(9);
    if (_sameTeam(team, home)) return h > a;
    if (_sameTeam(team, away)) return a > h;
    return null;
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
