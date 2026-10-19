import 'package:flutter/material.dart';
import '../services/user_prefs.dart';
import 'ar.dart';
import 'en.dart';
import 'es.dart';
import 'pt.dart';

const _dicts = <String, Map<String, String>>{'en': kEn, 'pt': kPt, 'es': kEs, 'ar': kAr};

/// Langue affichée (les langues sans traduction utilisent l'anglais).
String get appLang {
  final l = UserPrefs.lang;
  return l == 'fr' || _dicts.containsKey(l) ? l : 'en';
}

bool get isRtl => appLang == 'ar';

final _num = RegExp(r'\d+');

/// Phrases contenant un nom (équipe, utilisateur…) : {1} = partie variable.
final _rules = <(RegExp, Map<String, String>)>[
  (RegExp(r'^Victoire (.+)$'), {'en': 'Win {1}', 'pt': 'Vitória {1}', 'es': 'Victoria {1}', 'ar': 'فوز {1}'}),
  (RegExp(r'^(.+) ou nul$'), {'en': '{1} or draw', 'pt': '{1} ou empate', 'es': '{1} o empate', 'ar': '{1} أو تعادل'}),
  (RegExp(r'^Prédit (.+)$'), {'en': 'Predicted {1}', 'pt': 'Previsto {1}', 'es': 'Previsto {1}', 'ar': 'المتوقع {1}'}),
  (RegExp(r'^Bonjour (.+)$'), {'en': 'Hello {1}', 'pt': 'Olá {1}', 'es': 'Hola {1}', 'ar': 'مرحبًا {1}'}),
  (RegExp(r'^Aucun match trouvé pour « (.+) »\.$'), {'en': 'No match found for “{1}”.', 'pt': 'Nenhum jogo encontrado para “{1}”.', 'es': 'Ningún partido encontrado para “{1}”.', 'ar': 'لم يتم العثور على مباراة لـ «{1}».'}),
  (RegExp(r'^Championnat · (.+)$'), {'en': 'League · {1}', 'pt': 'Campeonato · {1}', 'es': 'Liga · {1}', 'ar': 'البطولة · {1}'}),
];

/// Traduit un texte français de l'application dans la langue choisie.
/// Les nombres sont conservés : « 12 pronostics » utilise la clé « # pronostics ».
String tr(String s) {
  final l = appLang;
  if (l == 'fr' || s.isEmpty) return s;
  final d = _dicts[l]!;
  // Texte absent dans la langue choisie : anglais, sinon français.
  String? get(String k) => d[k] ?? kEn[k];
  final exact = get(s);
  if (exact != null) return exact;
  final t = s.trim();
  if (t != s) {
    final x = get(t);
    if (x != null) return s.replaceFirst(t, x);
  }
  if (_num.hasMatch(s)) {
    final key = s.replaceAll(_num, '#');
    final v = get(key);
    if (v != null) {
      final nums = _num.allMatches(s).map((m) => m[0]!).toList();
      var i = 0;
      return v.replaceAllMapped(RegExp('#'), (_) => i < nums.length ? nums[i++] : '');
    }
  }
  for (final (re, m) in _rules) {
    final g = re.firstMatch(t);
    if (g != null && m[l] != null) return m[l]!.replaceAll('{1}', tr(g[1]!));
  }
  return s;
}

/// Texte traduit automatiquement (remplace Text dans l'application).
class T extends Text {
  T(
    String data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.softWrap,
    super.overflow,
    super.maxLines,
    super.semanticsLabel,
    super.textWidthBasis,
  }) : super(tr(data));
}

const _days = {
  'fr': ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'],
  'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  'pt': ['seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.', 'dom.'],
  'es': ['lun.', 'mar.', 'mié.', 'jue.', 'vie.', 'sáb.', 'dom.'],
  'ar': ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'],
};
const _months = {
  'fr': ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'],
  'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  'pt': ['jan.', 'fev.', 'mar.', 'abr.', 'mai.', 'jun.', 'jul.', 'ago.', 'set.', 'out.', 'nov.', 'dez.'],
  'es': ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'],
  'ar': ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
};

/// Jour court dans la langue de l'utilisateur, ex. « lun. 19 oct. » / « Mon 19 Oct ».
String dayName(int weekday) => _days[appLang]![weekday - 1];
String monthName(int month) => _months[appLang]![month - 1];
