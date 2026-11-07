import '../services/facts_service.dart';
import 'tr.dart';

/// Phrases des « Faits du jour » dans chaque langue de l'application.
/// {t} équipe, {o} adversaire, {n} {m} nombres, {p} noms des absents.
const Map<String, Map<String, String>> _tpl = {
  'fr': {
    'ws': '{t} a gagné ses {n} derniers matchs',
    'us': '{t} est invaincu lors de ses {n} derniers matchs',
    'hw': '{t} a gagné ses {n} derniers matchs à domicile',
    'hu': '{t} est invaincu lors de ses {n} derniers matchs à domicile',
    'aw': "{t} a gagné ses {n} derniers matchs à l'extérieur",
    'ls': '{t} a perdu ses {n} derniers matchs',
    'nw': "{t} n'a gagné aucun de ses {n} derniers matchs",
    'hl': '{t} a perdu ses {n} derniers matchs à domicile',
    'anw': "{t} n'a gagné aucun de ses {n} derniers matchs à l'extérieur",
    'cs': "{t} n'a encaissé aucun but lors de ses {n} derniers matchs",
    'cs1': "{t} n'a pas encaissé de but lors de son dernier match",
    'c6': "{t} n'a encaissé que {n} buts lors de ses 6 derniers matchs",
    'c61': "{t} n'a encaissé qu'un seul but lors de ses 6 derniers matchs",
    'g6': '{t} a marqué {n} buts lors de ses 6 derniers matchs',
    'bl': "{t} n'a marqué aucun but lors de ses {n} derniers matchs",
    'sc': '{t} a marqué lors de chacun de ses {n} derniers matchs',
    'g5': '{t} a marqué {n} buts lors de ses 5 derniers matchs',
    'o25': 'Les {n} derniers matchs de {t} ont tous eu au moins 3 buts',
    'bt': 'Les deux équipes ont marqué lors des {n} derniers matchs de {t}',
    'h2hw': '{t} a gagné ses {n} derniers face-à-face contre {o}',
    'h2hu': "{t} n'a perdu aucun de ses {n} derniers face-à-face contre {o}",
    'top': 'Choc du haut de tableau : {t} ({n}) contre {o} ({m})',
    'lead': 'Le leader {t} affronte {o}',
    'ab': '{t} privé de {n} joueurs (blessés ou suspendus)',
    'abp': '{t} privé de {n} joueurs, dont {p}',
  },
  'en': {
    'ws': '{t} have won their last {n} matches',
    'us': '{t} are unbeaten in their last {n} matches',
    'hw': '{t} have won their last {n} home matches',
    'hu': '{t} are unbeaten in their last {n} home matches',
    'aw': '{t} have won their last {n} away matches',
    'ls': '{t} have lost their last {n} matches',
    'nw': '{t} have not won any of their last {n} matches',
    'hl': '{t} have lost their last {n} home matches',
    'anw': '{t} have not won any of their last {n} away matches',
    'cs': '{t} have not conceded in their last {n} matches',
    'cs1': '{t} kept a clean sheet in their last match',
    'c6': '{t} have conceded only {n} goals in their last 6 matches',
    'c61': '{t} have conceded just one goal in their last 6 matches',
    'g6': '{t} have scored {n} goals in their last 6 matches',
    'bl': '{t} have failed to score in their last {n} matches',
    'sc': '{t} have scored in each of their last {n} matches',
    'g5': '{t} have scored {n} goals in their last 5 matches',
    'o25': "Each of {t}'s last {n} matches had at least 3 goals",
    'bt': "Both teams scored in each of {t}'s last {n} matches",
    'h2hw': '{t} have won their last {n} meetings with {o}',
    'h2hu': '{t} are unbeaten in their last {n} meetings with {o}',
    'top': 'Top-of-the-table clash: {t} ({n}) vs {o} ({m})',
    'lead': 'Leaders {t} take on {o}',
    'ab': '{t} without {n} players (injured or suspended)',
    'abp': '{t} without {n} players, including {p}',
  },
  'es': {
    'ws': '{t} ganó sus últimos {n} partidos',
    'us': '{t} está invicto en sus últimos {n} partidos',
    'hw': '{t} ganó sus últimos {n} partidos en casa',
    'hu': '{t} está invicto en sus últimos {n} partidos en casa',
    'aw': '{t} ganó sus últimos {n} partidos fuera de casa',
    'ls': '{t} perdió sus últimos {n} partidos',
    'nw': '{t} no ganó ninguno de sus últimos {n} partidos',
    'hl': '{t} perdió sus últimos {n} partidos en casa',
    'anw': '{t} no ganó ninguno de sus últimos {n} partidos fuera de casa',
    'cs': '{t} no encajó goles en sus últimos {n} partidos',
    'cs1': '{t} no encajó goles en su último partido',
    'c6': '{t} solo encajó {n} goles en sus últimos 6 partidos',
    'c61': '{t} solo encajó un gol en sus últimos 6 partidos',
    'g6': '{t} marcó {n} goles en sus últimos 6 partidos',
    'bl': '{t} no marcó en sus últimos {n} partidos',
    'sc': '{t} marcó en cada uno de sus últimos {n} partidos',
    'g5': '{t} marcó {n} goles en sus últimos 5 partidos',
    'o25': 'Los últimos {n} partidos de {t} tuvieron al menos 3 goles',
    'bt': 'Ambos equipos marcaron en los últimos {n} partidos de {t}',
    'h2hw': '{t} ganó sus últimos {n} enfrentamientos contra {o}',
    'h2hu': '{t} no perdió ninguno de sus últimos {n} enfrentamientos contra {o}',
    'top': 'Duelo en lo más alto: {t} ({n}) contra {o} ({m})',
    'lead': 'El líder {t} se enfrenta a {o}',
    'ab': '{t} sin {n} jugadores (lesionados o sancionados)',
    'abp': '{t} sin {n} jugadores, entre ellos {p}',
  },
  'pt': {
    'ws': '{t} venceu os últimos {n} jogos',
    'us': '{t} está invicto nos últimos {n} jogos',
    'hw': '{t} venceu os últimos {n} jogos em casa',
    'hu': '{t} está invicto nos últimos {n} jogos em casa',
    'aw': '{t} venceu os últimos {n} jogos fora de casa',
    'ls': '{t} perdeu os últimos {n} jogos',
    'nw': '{t} não venceu nenhum dos últimos {n} jogos',
    'hl': '{t} perdeu os últimos {n} jogos em casa',
    'anw': '{t} não venceu nenhum dos últimos {n} jogos fora de casa',
    'cs': '{t} não sofreu gols nos últimos {n} jogos',
    'cs1': '{t} não sofreu gols no último jogo',
    'c6': '{t} sofreu apenas {n} gols nos últimos 6 jogos',
    'c61': '{t} sofreu apenas um gol nos últimos 6 jogos',
    'g6': '{t} marcou {n} gols nos últimos 6 jogos',
    'bl': '{t} não marcou nos últimos {n} jogos',
    'sc': '{t} marcou em cada um dos últimos {n} jogos',
    'g5': '{t} marcou {n} gols nos últimos 5 jogos',
    'o25': 'Os últimos {n} jogos de {t} tiveram pelo menos 3 gols',
    'bt': 'As duas equipes marcaram nos últimos {n} jogos de {t}',
    'h2hw': '{t} venceu os últimos {n} confrontos contra {o}',
    'h2hu': '{t} está invicto nos últimos {n} confrontos contra {o}',
    'top': 'Duelo do topo: {t} ({n}) contra {o} ({m})',
    'lead': 'O líder {t} enfrenta {o}',
    'ab': '{t} sem {n} jogadores (lesionados ou suspensos)',
    'abp': '{t} sem {n} jogadores, incluindo {p}',
  },
  'ar': {
    'ws': 'فاز {t} في آخر {n} مباريات',
    'us': 'لم يخسر {t} في آخر {n} مباريات',
    'hw': 'فاز {t} في آخر {n} مباريات على أرضه',
    'hu': 'لم يخسر {t} في آخر {n} مباريات على أرضه',
    'aw': 'فاز {t} في آخر {n} مباريات خارج أرضه',
    'ls': 'خسر {t} آخر {n} مباريات',
    'nw': 'لم يفز {t} في أي من آخر {n} مباريات',
    'hl': 'خسر {t} آخر {n} مباريات على أرضه',
    'anw': 'لم يفز {t} في أي من آخر {n} مباريات خارج أرضه',
    'cs': 'لم تهتز شباك {t} في آخر {n} مباريات',
    'cs1': 'لم تهتز شباك {t} في مباراته الأخيرة',
    'c6': 'لم تستقبل شباك {t} سوى هدفين في آخر 6 مباريات',
    'c61': 'لم تستقبل شباك {t} سوى هدف واحد في آخر 6 مباريات',
    'g6': 'سجل {t} {n} هدفًا في آخر 6 مباريات',
    'bl': 'لم يسجل {t} في آخر {n} مباريات',
    'sc': 'سجل {t} في كل مباراة من آخر {n} مباريات',
    'g5': 'سجل {t} {n} أهداف في آخر 5 مباريات',
    'o25': 'شهدت آخر {n} مباريات لـ {t} ثلاثة أهداف على الأقل',
    'bt': 'سجل الفريقان في آخر {n} مباريات لـ {t}',
    'h2hw': 'فاز {t} في آخر {n} مواجهات أمام {o}',
    'h2hu': 'لم يخسر {t} في آخر {n} مواجهات أمام {o}',
    'top': 'قمة الترتيب: {t} ({n}) ضد {o} ({m})',
    'lead': 'المتصدر {t} يواجه {o}',
    'ab': 'يغيب عن {t} {n} لاعبين (إصابة أو إيقاف)',
    'abp': 'يغيب عن {t} {n} لاعبين، منهم {p}',
  },
};

/// Rang dans le classement : « 1er », « 3e » en français ; nombre simple ailleurs.
String _rank(int n, String l) {
  if (l == 'fr') return n == 1 ? '1er' : '${n}e';
  if (l == 'en') return n == 1 ? '1st' : n == 2 ? '2nd' : n == 3 ? '3rd' : '${n}th';
  if (l == 'es' || l == 'pt') return '${n}º';
  return '$n';
}

/// Phrase d'un fait du jour dans la langue de l'application.
String factText(DayFact f) {
  final l = _tpl.containsKey(appLang) ? appLang : 'en';
  final key = f.k == 'ab' && f.players.isNotEmpty ? 'abp' : f.k;
  final t = _tpl[l]![key] ?? _tpl['en']![key];
  if (t == null) return '';
  final top = f.k == 'top';
  return t
      .replaceAll('{t}', f.team)
      .replaceAll('{o}', f.opp)
      .replaceAll('{p}', f.players)
      .replaceAll('{n}', top ? _rank(f.n, l) : '${f.n}')
      .replaceAll('{m}', top ? _rank(f.m ?? 0, l) : '${f.m ?? ''}');
}
